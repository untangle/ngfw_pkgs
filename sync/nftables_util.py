import os
import sys
import subprocess
import datetime
import traceback
import string
import re
import copy

from sync.network_util import NetworkUtil

# This exception is thrown when creating a rule command of a non-sensical rule
# Unlike, other exceptions this exception will just mean the rule gets dropped
# but no error is throw
# This is used in cases like a user wants to create a rule to block when
# dns_prediction == netflix.com and source_address == 192.168.1.100
# In this case we'll add this rule to both the ip and ip6 tables, but in the ip6 table
# this makes no sense and we just want this rule silently ignored without an error.
class NonsensicalRuleException(Exception):
    pass

# Utility function to check that op is in array
def check_operation(op, array):
    if op not in array:
        raise Exception("Unsupported operation " + str(op))

# Returns a command-line safe version of the operation
# Appends spaces to the beginning and end
def op_str(op):
    if op == "==":
        return " "
    elif op == "!=":
        return " != "
    elif op == "<":
        return " \"<\" "
    elif op == ">":
        return " \">\" "
    elif op == "<=":
        return " \"<=\" "
    elif op == ">=":
        return " \">=\" "

# Returns a nft formatted value
# If the string contains a comma, it separates into nft list
def value_str(value):
    if len(value.split(",")) < 2:
        return "'" + value + "'"
    else:
        return "'{" + value + "}'"

# A generic helper funciton to build a basic nftables dict expression
def condition_dict_expression(table, key, field, type, op, value):
    if table == None:
        raise Exception("Invalid table: " + str(table))
    if key == None:
        raise Exception("Invalid key: " + str(key))
    if field == None:
        raise Exception("Invalid field: " + str(field))
    if type in ["long_string","bool"] and op != "==" and op != "!=":
        raise Exception("Unsupported operation " + str(op) + " for type " + type)

    return "dict " + table.strip() + " " + key.strip() + " " + field.strip() + " " + type.strip() + op_str(op) + value_str(value)

# A generic helper for generating zone expressions
def condition_interface_zone_expression(mark_exp, wan_mark, intf_mark, value, op):
    if op != "==" and op != "!=":
        raise Exception("Unsupported operation " + str(op))
    intfs = value.split(",")
    if "wan" in intfs and len(intfs) != 1:
        # Because wan isn't a specific interface we can't use sets
        # We have no ability to check that mark and logical OR that with checking another mark
        raise Exception("\"wan\" interface condition value can not be used with other values")
    if "non_wan" in intfs and len(intfs) != 1:
        # Because non_wan isn't a specific interface we can't use sets
        # We have no ability to check that mark and logical OR that with checking another mark
        raise Exception("\"non_wan\" interface condition value can not be used with other values")

    if "wan" in intfs:
        if op == "==":
            return mark_exp + " and " + wan_mark + " != '0'"
        else:
            return mark_exp + "  and " + wan_mark + " == '0'"
    elif "non_wan" in intfs:
        if op == "==":
            return mark_exp + " and " + wan_mark + " == '0'"
        else:
            return mark_exp + " and " + wan_mark + " != '0'"
    else:
        try:
            intf_indexs = [ int(x) for x in intfs ]
            if op == "==":
                return mark_exp + " and " + intf_mark + " " + value_str(value)
            else:
                return mark_exp + " and " + intf_mark + " != " + value_str(value)
        except ValueError as e:
            raise Exception("Invalid interface condition value: " + str(value))

# Generic helper for making address expressions
def condition_v4address_expression(addr_str, value, op, family):
    if family not in ['ip','inet']:
        raise NonsensicalRuleException("Invalid IPv4 family: %s" % family) 
    if ":" in value:
        raise Exception("Invalid IPv4 value: " + str(value))
    exp = "ip " + addr_str

    return exp + op_str(op) + value_str(value)

# Generic helper for making address expressions
def condition_v6address_expression(addr_str, value, op, family):
    if family not in ['ip6','inet']:
        raise NonsensicalRuleException("Invalid IPv6 family: %s" % family) 
    if "." in value:
        raise Exception("Invalid IPv6 value: " + str(value))
    exp = "ip6 " + addr_str

    return exp + op_str(op) + value_str(value)

# Generic helper for making port expressions
def condition_port_expression(port_str, ip_protocol, value, op):
    if ip_protocol == None:
        raise Exception("Undefined protocol with port condition")
    exp = ip_protocol + " " + port_str

    return exp + op_str(op) + value_str(value)


# Build nft expressions from the JSON condition object
def condition_expression(condition, family, ip_protocol=None):
    type = condition.get('type')
    op = condition.get('op')
    value = condition.get('value')

    if type == None:
        raise Exception("Condition missing type: " + str(condition.get('ruleId')))
    if value == None:
        raise Exception("Condition missing value: " + str(condition.get('ruleId')))
    if op == None:
        raise Exception("Condition missing op: " + str(condition.get('ruleId')))
        
    if type == "IP_PROTOCOL":
        check_operation(op,["==","!="])
        return "ip protocol" + op_str(op) + value_str(value.lower())
    elif type == "SOURCE_INTERFACE_ZONE":
        return condition_interface_zone_expression("mark", "0x01000000", "0x000000ff", value, op)
    elif type == "DESTINATION_INTERFACE_ZONE":
        return condition_interface_zone_expression("mark", "0x02000000", "0x0000ff00", value, op)
    elif type == "SOURCE_INTERFACE_NAME":
        check_operation(op,["==","!="])
        return "iifname" + op_str(op) + value_str(value)
    elif type == "DESTINATION_INTERFACE_NAME":
        check_operation(op,["==","!="])
        return "oifname" + op_str(op) + value_str(value)
    elif type == "SOURCE_ADDRESS":
        return condition_v4address_expression("saddr", value, op, family)
    elif type == "DESTINATION_ADDRESS":
        return condition_v4address_expression("daddr", value, op, family)
    elif type == "SOURCE_ADDRESS_V6":
        return condition_v6address_expression("saddr", value, op, family)
    elif type == "DESTINATION_ADDRESS_V6":
        return condition_v6address_expression("daddr", value, op, family)
    elif type == "SOURCE_PORT":
        return condition_port_expression("sport", ip_protocol, value, op)
    elif type == "DESTINATION_PORT":
        return condition_port_expression("dport", ip_protocol, value, op)
    elif type == "CLIENT_INTERFACE_ZONE":
        return condition_interface_zone_expression("ct mark", "0x01000000", "0x000000ff", value, op)
    elif type == "SERVER_INTERFACE_ZONE":
        return condition_interface_zone_expression("ct mark", "0x02000000", "0x0000ff00", value, op)
    elif type == "CLIENT_ADDRESS":
        return condition_dict_expression("session", "ct id", "client_address", "ipv4_addr", op, value)
    elif type == "SERVER_ADDRESS":
        return condition_dict_expression("session", "ct id", "server_address", "ipv4_addr", op, value)
    elif type == "LOCAL_ADDRESS":
        return condition_dict_expression("session", "ct id", "local_address", "ipv4_addr", op, value)
    elif type == "REMOTE_ADDRESS":
        return condition_dict_expression("session", "ct id", "remote_address", "ipv4_addr", op, value)
    elif type == "CLIENT_ADDRESS_V6":
        return condition_dict_expression("session", "ct id", "client_address", "ipv6_addr", op, value)
    elif type == "SERVER_ADDRESS_V6":
        return condition_dict_expression("session", "ct id", "server_address", "ipv6_addr", op, value)
    elif type == "LOCAL_ADDRESS_V6":
        return condition_dict_expression("session", "ct id", "local_address", "ipv6_addr", op, value)
    elif type == "REMOTE_ADDRESS_V6":
        return condition_dict_expression("session", "ct id", "remote_address", "ipv6_addr", op, value)
    elif type == "CLIENT_PORT":
        return condition_dict_expression("session","ct id","client_port","integer",op,value)
    elif type == "SERVER_PORT":
        return condition_dict_expression("session","ct id","server_port","integer",op,value)
    elif type == "LOCAL_PORT":
        return condition_dict_expression("session","ct id","local_port","integer",op,value)
    elif type == "REMOTE_PORT":
        return condition_dict_expression("session","ct id","remote_port","integer",op,value)
    elif type == "CLIENT_HOSTNAME":
        return condition_dict_expression("session","ct id","client_hostname","long_string",op,value)
    elif type == "SERVER_HOSTNAME":
        return condition_dict_expression("session","ct id","server_hostname","long_string",op,value)
    elif type == "LOCAL_HOSTNAME":
        return condition_dict_expression("session","ct id","local_hostname","long_string",op,value)
    elif type == "REMOTE_HOSTNAME":
        return condition_dict_expression("session","ct id","remote_hostname","long_string",op,value)
    elif type == "CLIENT_USERNAME":
        return condition_dict_expression("session","ct id","client_username","long_string",op,value)
    elif type == "SERVER_USERNAME":
        return condition_dict_expression("session","ct id","server_username","long_string",op,value)
    elif type == "LOCAL_USERNAME":
        return condition_dict_expression("session","ct id","local_username","long_string",op,value)
    elif type == "REMOTE_USERNAME":
        return condition_dict_expression("session","ct id","remote_username","long_string",op,value)
    
    raise Exception("Unsupported condition type " + type + " " + str(condition.get('ruleId')))


# This method takes a list of conditions from a rule and translates them into a string containing the nftables conditions
# It returns a list of strings, because some set of conditions require multiple nftables rules
# Example input: ['type':'SOURCE_INTERFACE', 'value':'1'] -> "ct mark and 0xff == 0x01"
# Example input: ['type':'DESTINATION_PORT', 'value':'123'] -> "tcp dport 123"
def conditions_expression(conditions, family):
    if conditions is None:
        return "";

    # set has_protocol_condition to True if this rule as an "IP_PROTOCOL" condition        
    has_protocol_condition = False
    ip_protocol = None
    for condition in conditions:
        if condition.get('type') == 'IP_PROTOCOL' and condition.get('op') == '==' and condition.get('value') != None and "," not in condition.get('value'):
            has_protocol_condition = True
            ip_protocol=condition.get('value')

    str = ""
    for condition in conditions:
        add_str = condition_expression(condition, family, ip_protocol=ip_protocol)
        if add_str != "":
            str = str + " " + add_str

    return str.strip()

# This method takes an method json object and provides the nft expression as a string
def action_expression(json_action, family):
    if json_action == None:
        raise Exception("Invalid action: null")
    type = json_action.get('type')

    if type == "REJECT":
        return "reject"
    elif type == "DROP":
        return "drop"
    elif type == "ACCEPT":
        return "accept"
    elif type == "DNAT":
        addr = json_action.get('dnat_address')
        if addr == None:
            raise Exception("Invalid action: Missing required parameter for action type " + str(type))
        if family == "ip" and ":" in addr:
            raise NonsensicalRuleException("Invalid IPv4 for ip DNAT: %s" % family) 
        if family == "ip6" and "." in addr:
            raise NonsensicalRuleException("Invalid IPv4 for ip DNAT: %s" % family) 
        return "dnat to " + addr
    elif type == "JUMP":
        chain = json_action.get('chain')
        if chain == None:
            raise Exception("Invalid action: Missing required parameter for action type " + str(type))
        return "jump " + chain
    elif type == "GOTO":
        chain = json_action.get('chain')
        if chain == None:
            raise Exception("Invalid action: Missing required parameter for action type " + str(type))
        return "goto " + chain
    else:
        raise Exception("Unknown action type: " + str(json_action))
    
# Builds an nft rule from the JSON rule object
def rule_expression(json_rule, family):
    if json_rule is None:
        raise Exception("Invalid rule: null")
    rule_id = json_rule.get('ruleId')
    action = json_rule.get('action')
    if rule_id == None:
        raise Exception("Missing ruleId: " + str(json_rule))
    if action is None:
        raise Exception("Invalid action (null) in rule " + str(rule_id))

    rule_exp = ""

    conditions = json_rule.get('conditions')
    if conditions != None:
        rule_exp = rule_exp + " " + conditions_expression(conditions, family)

    action_exp = action_expression(action, family)
    rule_exp = rule_exp + " " + action_exp

    return rule_exp[1:]

# This method takes a rule json object and provides the nft command
def rule_cmd(json_rule, family, table, chain):
    if json_rule is None:
        raise Exception("Invalid rule: null")
    rule_id = json_rule.get('ruleId')
    if rule_id == None:
        raise Exception("Missing ruleId: " + str(json_rule))
    if family is None:
        raise Exception("Invalid family (null) in rule " + str(rule_id))
    if table is None:
        raise Exception("Invalid table (null) in rule " + str(rule_id))
    if chain is None:
        raise Exception("Invalid chain (null) in rule " + str(rule_id))
    if family not in ['ip','ip6','inet','arp','bridge','netdev']:
        raise Exception("Invalid family (" + family + ") in rule " + str(rule_id))
    if not json_rule.get('enabled'):
        return None

    try:
        rule_cmd = "nft add rule " + family + " " + table + " " + chain + " " + rule_expression(json_rule, family)
        return rule_cmd
    except NonsensicalRuleException as e:
        return None
    except:
        raise

def chain_create_cmd(json_chain, family, table):
    if json_chain is None:
        raise Exception("Invalid chain: null")
    name = json_chain.get('name')
    rules = json_chain.get('rules')
    if name is None or not legal_nft_name(name):
        raise Exception("Invalid name (%s) for chain" % name)
    if rules is None:
        raise Exception("Invalid rules (null) in chain %s" % name)
    if family is None or family not in ['ip','ip6','inet','arp','bridge','netdev']:
        raise Exception("Invalid family (%s) for chain %s" % (family,name))
    if table is None or not legal_nft_name(table):
        raise Exception("Invalid table (%s) in chain %s" % (table,name))

    if json_chain.get('base'):
        type = json_chain.get('type')
        hook = json_chain.get('hook')
        priority = json_chain.get('priority')
        if type == None or type not in ["filter","route","nat"]:
            raise Exception("Invalid type (%s) for chain %s" % (type, name))
        if hook == None or hook not in ["prerouting","input","forward","output","postrouting","ingress"]:
            raise Exception("Invalid hook (%s) for chain %s" % (hook, name))
        if priority == None or priority < -500 or priority > 500:
            raise Exception("Invalid priority (%d) for chain %s" % (priority, name))
        return "nft add chain %s %s %s \"{ type %s hook %s priority %d ; }\"" % (family, table, name, type, hook, priority)
    else:
        return "nft add chain %s %s %s" % (family, table, name)

def table_create_cmd(json_table):
    if json_table is None:
        raise Exception("Invalid table: null")
    name = json_table.get('name')
    family = json_table.get('family')
    chains = json_table.get('chains')
    if name is None or not legal_nft_name(name):
        raise Exception("Invalid name (%s) in table" % name)
    if family is None or family not in ['ip','ip6','inet','arp','bridge','netdev']:
        raise Exception("Invalid family (%s) for table %s" % (family,name))
    if chains is None:
        raise Exception("Invalid chains (null) for table %s" % name)
    return "nft add table %s %s" % (family, name)

def table_flush_cmd(json_table):
    cmd = table_create_cmd(json_table)
    return cmd.replace(" add "," flush ")

def table_delete_cmd(json_table):
    cmd = table_create_cmd(json_table)
    return cmd.replace(" add "," delete ") + " 2>/dev/null || true"

def table_all_cmds(json_table):
    cmds = []
    name = json_table.get('name')
    family = json_table.get('family')
    if family == "ip,ip6":
        # make shallow copies and create two separate tables
        json_table_ip = copy.copy(json_table)
        json_table_ip['family'] = 'ip'
        json_table_ip6 = copy.copy(json_table)
        json_table_ip6['family'] = 'ip6'
        return table_all_cmds(json_table_ip) + "\n\n" + table_all_cmds(json_table_ip6)
    cmds.append(table_delete_cmd(json_table))
    cmds.append(table_create_cmd(json_table))
    for chain in json_table.get('chains'):
        cmds.append(chain_create_cmd(chain,family,name))
        for rule in chain['rules']:
            rule_cmd_str = rule_cmd(rule, family, name, chain['name'])
            if rule_cmd_str != None:
                cmds.append(rule_cmd_str)
    return '\n'.join(cmds)

def legal_nft_name(name):
    if name is None:
        return False
    match = re.match("[a-z-]+", name)
    return match is not None
