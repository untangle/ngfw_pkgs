"""nftables_util provides nftable utility functions"""
import re
import copy

# long functions (case statements etc)
# pylint: disable=too-many-branches
# pylint: disable=too-many-return-statements
# pylint: disable=too-many-statements
# long argument lists
# pylint: disable=too-many-arguments

class NonsensicalException(Exception):
    """
    This exception is thrown when creating a rule command of a non-sensical rule

    This is used in cases like a user wants to create a rule to block when
    dns_prediction == netflix.com and source_address == 192.168.1.100
    In this case we'll add this rule to both the ip and ip6 tables, but in the ip6 table
    this makes no sense and we just want this rule silently ignored without an error.
    """
    pass

def sanitize_condition(condition):
    """
    Sanitize a condition by correcting the types
    """
    condtype = condition.get('type')
    op = condition.get('op')
    value = condition.get('value')
    unit = condition.get('rate_unit')

    if condtype is None:
        raise Exception("Condition missing type: " + str(condition.get('ruleId')))
    if value is None:
        raise Exception("Condition missing value: " + str(condition.get('ruleId')))
    if op is None:
        raise Exception("Condition missing op: " + str(condition.get('ruleId')))

    condition['type'] = str(condtype) # change all types to string
    condition['op'] = str(op) # change all types to string
    condition['value'] = str(value) # change all types to string
    condition['unit'] = str(unit) # change all types to string

    if '"' in condition.get('value'):
        raise Exception("Invalid character in condition value: " + str(condition.get('value')))

    return condition

def check_operation(op, array):
    """Utility function to check that op is in array"""
    if op not in array:
        raise Exception("Unsupported operation " + str(op))

def op_str(op):
    """
    Returns a command-line safe version of the operation
    Appends spaces to the beginning and end
    """
    if op == "==":
        return " "
    elif op == "!=":
        return " != "
    elif op == "<":
        return " < "
    elif op == ">":
        return " > "
    elif op == "<=":
        return " <= "
    elif op == ">=":
        return " >= "

def ip_protocol_number_to_str(ip_protocol):
    """
    Changes 6,"6","tcp" to "tcp"
    Changes 17,"17","udp" to "udp"
    All other values unchanged
    """
    if ip_protocol == "6" or ip_protocol == 6:
        return "tcp"
    if ip_protocol == "17" or ip_protocol == 17:
        return "udp"
    return ip_protocol

def value_str(value):
    """
    Returns a nft formatted value
    If the string contains a comma, it separates into nft list
    """
    if len(value.split(",")) < 2:
        return "\"" + value + "\""
    else:
        return "\"{" + value + "}\""

def numerical_val(value):
    """
    numerical_val returns an NFT formatted value representing an IP address
    or port value.  If the value contains a comma, the results are split
    into an NFT list
    """
    if len(value.split(",")) < 2:
        return value
    else:
        return "{" + value + "}"

def selector_expression(typ, family, ip_protocol=None):
    """generic helper function to build a basic nftables selector expression"""
    if typ == "IP_PROTOCOL":
        return "meta l4proto"
    elif typ == "SOURCE_ADDRESS":
        if family not in ['ip', 'inet']:
            raise NonsensicalException("Ignore IPv4 family: %s" % family)
        return "ip saddr"
    elif typ == "DESTINATION_ADDRESS":
        if family not in ['ip', 'inet']:
            raise NonsensicalException("Ignore IPv4 family: %s" % family)
        return "ip daddr"
    elif typ == "SOURCE_ADDRESS_V6":
        if family not in ['ip6', 'inet']:
            raise NonsensicalException("Ignore IPv6 family: %s" % family)
        return "ip6 saddr"
    elif typ == "DESTINATION_ADDRESS_V6":
        if family not in ['ip6', 'inet']:
            raise NonsensicalException("Ignore IPv6 family: %s" % family)
        return "ip6 daddr"
    elif typ == "SOURCE_PORT":
        if ip_protocol is None:
            raise Exception("Undefined protocol with port condition")
        return ip_protocol_number_to_str(ip_protocol) + " sport"
    elif typ == "DESTINATION_PORT":
        if ip_protocol is None:
            raise Exception("Undefined protocol with port condition")
        return ip_protocol_number_to_str(ip_protocol) + " dport"

    raise Exception("Unsupported selector type " + typ)

def condition_dict_expression(table, key, field, typ, op, value):
    """A generic helper funciton to build a basic nftables dict expression"""
    if table is None:
        raise Exception("Invalid table: " + str(table))
    if key is None:
        raise Exception("Invalid key: " + str(key))
    if field is None:
        raise Exception("Invalid field: " + str(field))
    if typ in ["long_string", "bool"] and op != "==" and op != "!=":
        raise Exception("Unsupported operation " + str(op) + " for type " + typ)
    if typ in ["ipv4_addr", "ipv6_addr", "int"]:
        val = numerical_val(value)
    else:
        val = value_str(value)

    return "dict " + table.strip() + " " + key.strip() + " " + field.strip() + " " + typ.strip() + op_str(op) + val

def condition_interface_type_expression(mark_exp, intf_type_mask, intf_type_shift, value, op):
    """A generic helper for generating zone expressions"""
    if op != "==" and op != "!=":
        raise Exception("Unsupported operation " + str(op))

    if value in ["1", "wan"]:
        if op == "==":
            return mark_exp + " and " + intf_type_mask + " " + format((1<<intf_type_shift), '#010x')
        else:
            return mark_exp + " and " + intf_type_mask + " != " + format((1<<intf_type_shift), '#010x')
    elif value in ["2", "lan"]:
        if op == "==":
            return mark_exp + " and " + intf_type_mask + " " + format((2<<intf_type_shift), '#010x')
        else:
            return mark_exp + " and " + intf_type_mask + " != " + format((2<<intf_type_shift), '#010x')
    elif value in ["0", "unset"]:
        if op == "==":
            return mark_exp + " and " + intf_type_mask + " " + format(0, '#010x')
        else:
            return mark_exp + " and " + intf_type_mask + " != " + format(0, '#010x')
    else:
        raise Exception("Invalid interface type expression: " + value)

def condition_interface_zone_expression(mark_exp, intf_mask, val_shift, value, op):
    """A generic helper for generating zone expressions"""
    if op != "==" and op != "!=":
        raise Exception("Unsupported operation " + str(op))

    try:
        if op == "==":
            return mark_exp + " and " + intf_mask + " " + format(int(value)<<val_shift, '#010x')
        else:
            return mark_exp + " and " + intf_mask + " != " + format(int(value)<<val_shift, '#010x')
    except ValueError:
        raise Exception("Invalid interface condition value: " + str(value))

def condition_v4address_expression(addr_str, value, op, family):
    """Generic helper for making address expressions"""
    if family not in ['ip', 'inet']:
        raise NonsensicalException("Ignore IPv4 family: %s" % family)
    if ":" in value:
        raise Exception("Invalid IPv4 value: " + str(value))
    return "ip " + addr_str + op_str(op) + numerical_val(value)

def condition_address_type_expression(addr_str, value, op, family):
    """Generic helper for making destination_type expressions"""
    if family not in ['ip', 'ip6', 'inet']:
        raise NonsensicalException("Ignore family: %s" % family)
    if value not in ['unspec', 'unicast', 'local', 'broadcast', 'anycast', 'multicast', 'blackhole', 'unreachable', 'prohibit']:
        raise Exception("Invalid address type value: " + str(value))
    return "fib " + addr_str + " type" + op_str(op) + value_str(value)

def condition_v6address_expression(addr_str, value, op, family):
    """Generic helper for making address expressions"""
    if family not in ['ip6', 'inet']:
        raise NonsensicalException("Ignore IPv6 family: %s" % family)
    if "." in value:
        raise Exception("Invalid IPv6 value: " + str(value))
    return "ip6 " + addr_str + op_str(op) + numerical_val(value)

def condition_port_expression(port_str, ip_protocol, value, op):
    """Generic helper for making port expressions"""
    if ip_protocol is None:
        raise Exception("Undefined protocol with port condition")
    return ip_protocol_number_to_str(ip_protocol) + " " + port_str + op_str(op) + numerical_val(value)

def condition_ct_state_expression(value, op):
    """Generic helper for making port expressions"""
    if "," in value:
        for val in value.split(","):
            if val not in ["established", "related", "new", "invalid"]:
                raise Exception("Invalid ct state value: %s" % val)
    else:
        if value not in ["established", "related", "new", "invalid"]:
            raise Exception("Invalid ct state value: %s" % val)
    return "ct state " + op_str(op) + " " + value

def condition_limit_rate_expression(value, op, rate_unit):
    """Generic helper for limit rate expressions"""
    if rate_unit is None:
        raise Exception("Limit rate expressions require rate_unit")
    rate_int = int(value)
    if op == "<":
        return "limit rate %d%s" % (rate_int, get_limit_rate_unit_string(rate_unit))
    else:
        return "limit rate over %d%s" % (rate_int, get_limit_rate_unit_string(rate_unit))

def condition_expression(condition, family, ip_protocol=None):
    """Build nft expressions from the JSON condition object"""
    condition = sanitize_condition(condition)
    condtype = condition.get('type')
    op = condition.get('op')
    value = condition.get('value')
    unit = condition.get('rate_unit')

    if condtype == "IP_PROTOCOL":
        check_operation(op, ["==", "!="])
        return "meta l4proto" + op_str(op) + value_str(value.lower())
    elif condtype == "SOURCE_INTERFACE_ZONE":
        return condition_interface_zone_expression("mark", "0x000000ff", 0, value, op)
    elif condtype == "DESTINATION_INTERFACE_ZONE":
        return condition_interface_zone_expression("mark", "0x0000ff00", 8, value, op)
    elif condtype == "SOURCE_INTERFACE_TYPE":
        return condition_interface_type_expression("mark", "0x03000000", 24, value, op)
    elif condtype == "DESTINATION_INTERFACE_TYPE":
        return condition_interface_type_expression("mark", "0x0c000000", 26, value, op)
    elif condtype == "SOURCE_INTERFACE_NAME":
        check_operation(op, ["==", "!="])
        return "iifname" + op_str(op) + value_str(value)
    elif condtype == "DESTINATION_INTERFACE_NAME":
        check_operation(op, ["==", "!="])
        return "oifname" + op_str(op) + value_str(value)
    elif condtype == "SOURCE_ADDRESS":
        return condition_v4address_expression("saddr", value, op, family)
    elif condtype == "SOURCE_ADDRESS_TYPE":
        return condition_address_type_expression("saddr", value, op, family)
    elif condtype == "DESTINATION_ADDRESS":
        return condition_v4address_expression("daddr", value, op, family)
    elif condtype == "DESTINATION_ADDRESS_TYPE":
        return condition_address_type_expression("daddr", value, op, family)
    elif condtype == "DESTINED_LOCAL":
        return condition_address_type_expression("daddr", "local", op, family)
    elif condtype == "SOURCE_ADDRESS_V6":
        return condition_v6address_expression("saddr", value, op, family)
    elif condtype == "DESTINATION_ADDRESS_V6":
        return condition_v6address_expression("daddr", value, op, family)
    elif condtype == "SOURCE_PORT":
        return condition_port_expression("sport", ip_protocol, value, op)
    elif condtype == "DESTINATION_PORT":
        return condition_port_expression("dport", ip_protocol, value, op)
    elif condtype == "CLIENT_INTERFACE_ZONE":
        return condition_interface_zone_expression("ct mark", "0x000000ff", 0, value, op)
    elif condtype == "SERVER_INTERFACE_ZONE":
        return condition_interface_zone_expression("ct mark", "0x0000ff00", 8, value, op)
    elif condtype == "CLIENT_INTERFACE_TYPE":
        return condition_interface_type_expression("ct mark", "0x03000000", 24, value, op)
    elif condtype == "SERVER_INTERFACE_TYPE":
        return condition_interface_type_expression("ct mark", "0x0c000000", 26, value, op)
    elif condtype == "CLIENT_ADDRESS":
        return condition_dict_expression("sessions", "ct id", "client_address", "ipv4_addr", op, value)
    elif condtype == "SERVER_ADDRESS":
        return condition_dict_expression("sessions", "ct id", "server_address", "ipv4_addr", op, value)
    elif condtype == "LOCAL_ADDRESS":
        return condition_dict_expression("sessions", "ct id", "local_address", "ipv4_addr", op, value)
    elif condtype == "REMOTE_ADDRESS":
        return condition_dict_expression("sessions", "ct id", "remote_address", "ipv4_addr", op, value)
    elif condtype == "CLIENT_ADDRESS_V6":
        return condition_dict_expression("sessions", "ct id", "client_address", "ipv6_addr", op, value)
    elif condtype == "SERVER_ADDRESS_V6":
        return condition_dict_expression("sessions", "ct id", "server_address", "ipv6_addr", op, value)
    elif condtype == "LOCAL_ADDRESS_V6":
        return condition_dict_expression("sessions", "ct id", "local_address", "ipv6_addr", op, value)
    elif condtype == "REMOTE_ADDRESS_V6":
        return condition_dict_expression("sessions", "ct id", "remote_address", "ipv6_addr", op, value)
    elif condtype == "CLIENT_PORT":
        return condition_dict_expression("sessions", "ct id", "client_port", "int", op, value)
    elif condtype == "SERVER_PORT":
        return condition_dict_expression("sessions", "ct id", "server_port", "int", op, value)
    elif condtype == "LOCAL_PORT":
        return condition_dict_expression("sessions", "ct id", "local_port", "int", op, value)
    elif condtype == "REMOTE_PORT":
        return condition_dict_expression("sessions", "ct id", "remote_port", "int", op, value)
    elif condtype == "CLIENT_HOSTNAME":
        return condition_dict_expression("sessions", "ct id", "client_hostname", "long_string", op, value)
    elif condtype == "SERVER_HOSTNAME":
        return condition_dict_expression("sessions", "ct id", "server_hostname", "long_string", op, value)
    elif condtype == "LOCAL_HOSTNAME":
        return condition_dict_expression("sessions", "ct id", "local_hostname", "long_string", op, value)
    elif condtype == "REMOTE_HOSTNAME":
        return condition_dict_expression("sessions", "ct id", "remote_hostname", "long_string", op, value)
    elif condtype == "CLIENT_USERNAME":
        return condition_dict_expression("sessions", "ct id", "client_username", "long_string", op, value)
    elif condtype == "CLIENT_REVERSE_DNS":
        return condition_dict_expression("sessions", "ct id", "client_reverse_dns", "long_string", op, value)
    elif condtype == "CLIENT_DNS_HINT":
        return condition_dict_expression("sessions", "ct id", "client_dns_hint", "long_string", op, value)
    elif condtype == "SERVER_USERNAME":
        return condition_dict_expression("sessions", "ct id", "server_username", "long_string", op, value)
    elif condtype == "SERVER_REVERSE_DNS":
        return condition_dict_expression("sessions", "ct id", "server_reverse_dns", "long_string", op, value)
    elif condtype == "SERVER_DNS_HINT":
        return condition_dict_expression("sessions", "ct id", "server_dns_hint", "long_string", op, value)
    elif condtype == "LOCAL_USERNAME":
        return condition_dict_expression("sessions", "ct id", "local_username", "long_string", op, value)
    elif condtype == "REMOTE_USERNAME":
        return condition_dict_expression("sessions", "ct id", "remote_username", "long_string", op, value)
    elif condtype == "APPLICATION_ID":
        return condition_dict_expression("sessions", "ct id", "application_id", "long_string", op, value)
    elif condtype == "APPLICATION_NAME":
        return condition_dict_expression("sessions", "ct id", "application_name", "long_string", op, value)
    elif condtype == "APPLICATION_CONFIDENCE":
        return condition_dict_expression("sessions", "ct id", "application_confidence", "int", op, value)
    elif condtype == "APPLICATION_PROTOCHAIN":
        return condition_dict_expression("sessions", "ct id", "application_protochain", "long_string", op, value)
    elif condtype == "APPLICATION_DETAIL":
        return condition_dict_expression("sessions", "ct id", "application_detail", "long_string", op, value)
    elif condtype == "APPLICATION_PRODUCTIVITY":
        return condition_dict_expression("sessions", "ct id", "application_productivity", "int", op, value)
    elif condtype == "APPLICATION_RISK":
        return condition_dict_expression("sessions", "ct id", "application_risk", "int", op, value)
    elif condtype == "APPLICATION_CATEGORY":
        return condition_dict_expression("sessions", "ct id", "application_category", "long_string", op, value)
    elif condtype == "APPLICATION_ID_INFERRED":
        return condition_dict_expression("sessions", "ct id", "application_id_inferred", "long_string", op, value)
    elif condtype == "APPLICATION_NAME_INFERRED":
        return condition_dict_expression("sessions", "ct id", "application_name_inferred", "long_string", op, value)
    elif condtype == "APPLICATION_CONFIDENCE_INFERRED":
        return condition_dict_expression("sessions", "ct id", "application_confidence_inferred", "int", op, value)
    elif condtype == "APPLICATION_PROTOCHAIN_INFERRED":
        return condition_dict_expression("sessions", "ct id", "application_protochain_inferred", "long_string", op, value)
    elif condtype == "APPLICATION_PRODUCTIVITY_INFERRED":
        return condition_dict_expression("sessions", "ct id", "application_productivity_inferred", "int", op, value)
    elif condtype == "APPLICATION_RISK_INFERRED":
        return condition_dict_expression("sessions", "ct id", "application_risk_inferred", "int", op, value)
    elif condtype == "APPLICATION_CATEGORY_INFERRED":
        return condition_dict_expression("sessions", "ct id", "application_category_inferred", "long_string", op, value)
    elif condtype == "CERT_SUBJECT_CN":
        return condition_dict_expression("sessions", "ct id", "certificate_subject_cn", "long_string", op, value)
    elif condtype == "CERT_SUBJECT_SN":
        return condition_dict_expression("sessions", "ct id", "certificate_subject_sn", "long_string", op, value)
    elif condtype == "CERT_SUBJECT_C":
        return condition_dict_expression("sessions", "ct id", "certificate_subject_c", "long_string", op, value)
    elif condtype == "CERT_SUBJECT_O":
        return condition_dict_expression("sessions", "ct id", "certificate_subject_o", "long_string", op, value)
    elif condtype == "CERT_SUBJECT_OU":
        return condition_dict_expression("sessions", "ct id", "certificate_subject_ou", "long_string", op, value)
    elif condtype == "CERT_SUBJECT_L":
        return condition_dict_expression("sessions", "ct id", "certificate_subject_l", "long_string", op, value)
    elif condtype == "CERT_SUBJECT_P":
        return condition_dict_expression("sessions", "ct id", "certificate_subject_p", "long_string", op, value)
    elif condtype == "CERT_SUBJECT_SA":
        return condition_dict_expression("sessions", "ct id", "certificate_subject_sa", "long_string", op, value)
    elif condtype == "CERT_SUBJECT_PC":
        return condition_dict_expression("sessions", "ct id", "certificate_subject_pc", "long_string", op, value)
    elif condtype == "CERT_SUBJECT_SAN":
        return condition_dict_expression("sessions", "ct id", "certificate_subject_san", "long_string", op, value)
    elif condtype == "CERT_SUBJECT_DNS":
        return condition_dict_expression("sessions", "ct id", "cert_dns_names", "long_string", op, value)
    elif condtype == "CERT_ISSUER_CN":
        return condition_dict_expression("sessions", "ct id", "certificate_issuer_cn", "long_string", op, value)
    elif condtype == "CERT_ISSUER_SN":
        return condition_dict_expression("sessions", "ct id", "certificate_issuer_sn", "long_string", op, value)
    elif condtype == "CERT_ISSUER_C":
        return condition_dict_expression("sessions", "ct id", "certificate_issuer_c", "long_string", op, value)
    elif condtype == "CERT_ISSUER_O":
        return condition_dict_expression("sessions", "ct id", "certificate_issuer_o", "long_string", op, value)
    elif condtype == "CERT_ISSUER_OU":
        return condition_dict_expression("sessions", "ct id", "certificate_issuer_ou", "long_string", op, value)
    elif condtype == "CERT_ISSUER_L":
        return condition_dict_expression("sessions", "ct id", "certificate_issuer_l", "long_string", op, value)
    elif condtype == "CERT_ISSUER_P":
        return condition_dict_expression("sessions", "ct id", "certificate_issuer_p", "long_string", op, value)
    elif condtype == "CERT_ISSUER_SA":
        return condition_dict_expression("sessions", "ct id", "certificate_issuer_sa", "long_string", op, value)
    elif condtype == "CERT_ISSUER_PC":
        return condition_dict_expression("sessions", "ct id", "certificate_issuer_pc", "long_string", op, value)
    elif condtype == "CT_STATE":
        return condition_ct_state_expression(value, op)
    elif condtype == "LIMIT_RATE":
        check_operation(op, [">", "<"])
        return condition_limit_rate_expression(value, op, unit)
    raise Exception("Unsupported condition type " + condtype + " " + str(condition.get('ruleId')))

def conditions_expression(conditions, family):
    """
    This method takes a list of conditions from a rule and translates them into a string containing the nftables conditions
    It returns a list of strings, because some set of conditions require multiple nftables rules
    Example input: ['type':'SOURCE_INTERFACE', 'value':'1'] -> "ct mark and 0xff == 0x01"
    Example input: ['type':'DESTINATION_PORT', 'value':'123'] -> "tcp dport 123"
    """
    if conditions is None:
        return ""

    # set has_protocol_condition to True if this rule as an "IP_PROTOCOL" condition
    ip_protocol = None
    for condition in conditions:
        condition = sanitize_condition(condition)
        if condition.get('type') == 'IP_PROTOCOL' and condition.get('op') == '==' and condition.get('value') != None and "," not in condition.get('value'):
            ip_protocol = condition.get('value')

    strcat = ""
    for condition in conditions:

        group_selector = condition.get('group_selector')
        if group_selector != None:
            conditions_expression.meter_id = getattr(conditions_expression, 'meter_id', 0) + 1
            strcat = strcat + " meter meter-%d { %s" % (conditions_expression.meter_id, selector_expression(group_selector, family, ip_protocol=ip_protocol))

        add_str = condition_expression(condition, family, ip_protocol=ip_protocol)
        if add_str != "":
            strcat = strcat + " " + add_str

        if group_selector != None:
            strcat = strcat + " }"

    return strcat.strip()

def action_expression(json_action, family):
    """This method takes an method json object and provides the nft expression as a string"""
    check_action(json_action)
    typ = json_action.get('type')

    if typ == "REJECT":
        return "reject"
    elif typ == "DROP":
        return "drop"
    elif typ == "ACCEPT":
        return "accept"
    elif typ == "RETURN":
        return "return"
    elif typ == "DNAT":
        addr = json_action.get('dnat_address')
        port = json_action.get('dnat_port')
        if addr is None:
            raise Exception("Invalid action: Missing required address parameter for action type " + str(typ))
        if family == "ip" and ":" in addr:
            raise NonsensicalException("Ignore IPv6 for IPv4 DNAT: %s" % family)
        if family == "ip6" and "." in addr:
            raise NonsensicalException("Ignore IPv4 for IPv6 DNAT: %s" % family)
        port_int = None
        if port != None:
            port_int = int(port)
        if port_int != None:
            return "dnat to %s:%i" % (addr, port_int)
        else:
            return "dnat to %s" % (addr)
    elif typ == "SNAT":
        addr = json_action.get('snat_address')
        if addr is None:
            raise Exception("Invalid action: Missing required parameter for action type " + str(typ))
        if family == "ip" and ":" in addr:
            raise NonsensicalException("Ignore IPv6 for IPv4 SNAT: %s" % family)
        if family == "ip6" and "." in addr:
            raise NonsensicalException("Ignore IPv4 for IPv6 SNAT: %s" % family)
        return "snat to %s" % (addr)
    elif typ == "MASQUERADE":
        return "masquerade"
    elif typ == "JUMP":
        chain = json_action.get('chain')
        if chain is None:
            raise Exception("Invalid action: Missing required parameter for action type " + str(typ))
        return "jump " + chain
    elif typ == "GOTO":
        chain = json_action.get('chain')
        if chain is None:
            raise Exception("Invalid action: Missing required parameter for action type " + str(typ))
        return "goto " + chain
    elif typ == "SET_PRIORITY":
        priority = json_action.get('priority')
        if priority is None:
            raise Exception("Invalid action: Missing required parameter for action type " + str(typ))
        priority_int = int(priority) & 0xff
        if priority_int < 1 or priority_int > 4:
            raise Exception("Priority out of range (1-4): %d" % priority_int)
        return "meta mark set mark and 0xff00ffff or 0x00%s0000" % ('{:02x}'.format(priority_int))
    elif typ == "WAN_POLICY":
        policy = json_action.get('policy')
        if policy is None:
            raise Exception("Invalid action: Missing required parameter for action type " + str(typ))
        return "jump route-to-policy-%s" % str(policy)
    else:
        raise Exception("Unknown action type: " + str(json_action))

def logs_expression(logs):
    """This method takes an method json object and provides the nft log action(s)"""

    strcat = ""
    for log in logs:
        check_log(log)
        typ = log.get('type')

        if typ == "COUNTER":
            strcat = strcat + " counter"
        elif typ == "NFLOG":
            prefix = log.get('prefix')
            strcat = strcat + " log prefix \"%s \" group 0" % prefix
        elif typ == "DICT":
            field = log.get('field')
            value = log.get('value')
            field_type = log.get('field_type')
            if field_type == None or field_type == "LONG_STRING":
                strcat = strcat + " dict sessions ct id %s long_string set %s" % (field, value)
            elif field_type == "INT":
                strcat = strcat + " dict sessions ct id %s int set %s" % (field, value)
        else:
            raise Exception("Unknown log type: " + str(log))

    return strcat.strip()

def rule_expression(json_rule, family):
    """Builds an nft rule from the JSON rule object"""
    check_rule(json_rule)

    rule_exp = ""
    conditions = json_rule.get('conditions')
    if conditions != None:
        rule_exp = rule_exp + " " + conditions_expression(conditions, family)

    logs = json_rule.get('logs')
    if logs != None:
        rule_exp = rule_exp + " " + logs_expression(logs)

    action_exp = action_expression(json_rule.get('action'), family)
    rule_exp = rule_exp + " " + action_exp

    return rule_exp[1:]

def rule_cmd(json_rule, family, table, chain):
    """This method takes a rule json object and provides the nft command"""
    check_rule(json_rule)

    if not json_rule.get('enabled'):
        return None

    try:
        cmd = "add rule " + family + " " + table + " " + chain + " " + rule_expression(json_rule, family)
        return cmd
    except NonsensicalException:
        return None
    except:
        raise

def chain_create_cmd(json_chain, family, chain_type, table):
    """Return the nft command to create this chain"""
    check_chain(json_chain)
    check_family(family)

    name = json_chain.get('name')

    # type used to be stored in the chain JSON definition
    # keep this for backwards compatibility
    if chain_type is None:
        chain_type = json_chain.get('type')

    # vote is only valid in the ip, ip6 familyt, but the vote table is ip,ip6,inet just ignore inet
    if json_chain.get('base') and json_chain.get('type') == "route" and family == "inet":
        raise NonsensicalException("Ignore inet/route chains")

    if json_chain.get('base'):
        hook = json_chain.get('hook')
        priority = json_chain.get('priority')
        if chain_type is None or chain_type not in ["filter", "route", "nat"]:
            raise Exception("Invalid type (%s) for chain %s" % (chain_type, name))
        if hook is None or hook not in ["prerouting", "input", "forward", "output", "postrouting", "ingress"]:
            raise Exception("Invalid hook (%s) for chain %s" % (hook, name))
        if priority is None or priority < -500 or priority > 500:
            raise Exception("Invalid priority (%d) for chain %s" % (priority, name))
        return "add chain %s %s %s { type %s hook %s priority %d ; }" % (family, table, name, chain_type, hook, priority)
    else:
        return "add chain %s %s %s" % (family, table, name)

def chain_rules_cmds(json_chain, family, chain_type, table):
    """Return all the commands to create and populate this chain"""
    check_chain(json_chain)

    # type used to be stored in the chain JSON definition
    # keep this for backwards compatibility
    if chain_type is None:
        chain_type = json_chain.get('type')

    # route is only valid in the ip, ip6 families
    if json_chain.get('base') and chain_type == "route" and family not in ["ip","ip6"]:
        raise NonsensicalException("Ignore inet/route chains")

    cmds = []
    for rule in json_chain['rules']:
        rule_cmd_str = rule_cmd(rule, family, table, json_chain['name'])
        if rule_cmd_str != None:
            cmds.append(rule_cmd_str)
    return '\n'.join(cmds)

def table_create_cmd(json_table):
    """Return the nft command to create this table"""
    check_table(json_table)
    return "add table %s %s" % (json_table.get('family'), json_table.get('name'))

def table_flush_cmd(json_table):
    """Return the nft command to flush this table"""
    cmd = table_create_cmd(json_table)
    return cmd.replace("add ", "flush ")

def table_delete_cmd(json_table):
    """Return the nft command to delete this table"""
    cmd = table_create_cmd(json_table)
    return cmd.replace("add ", "delete ")

def table_all_cmds(json_table):
    """Return all the commands to create, flush, and populate this table"""
    check_table(json_table, allow_multiple_families=True)
    cmds = []
    name = json_table.get('name')
    family = json_table.get('family')
    chain_type = json_table.get('chain_type')
    if "," in family:
        families = family.split(",")
        strcat = ""
        for fam in families:
            # make shallow copies and create separate tables
            json_table_fam = copy.copy(json_table)
            json_table_fam['family'] = fam
            strcat += table_all_cmds(json_table_fam) + "\n"
        return strcat

    cmds.append(table_create_cmd(json_table))
    cmds.append(table_flush_cmd(json_table))
    for json_chain in json_table.get('chains'):
        try:
            cmds.append(chain_create_cmd(json_chain, family, chain_type, name))
        except NonsensicalException:
            pass
    for json_chain in json_table.get('chains'):
        try:
            cmds.append(chain_rules_cmds(json_chain, family, chain_type, name))
        except NonsensicalException:
            pass
    return '\n'.join(cmds)

def check_chain(json_chain):
    """Check the provided chain has the required attributes, throw exception if not"""
    if json_chain is None:
        raise Exception("Invalid chain: null")
    name = json_chain.get('name')
    rules = json_chain.get('rules')
    if name is None or not legal_nft_name(name):
        raise Exception("Invalid name (%s) for chain" % name)
    if rules is None:
        raise Exception("Invalid rules (null) in chain %s" % name)
    return

def check_rule(json_rule):
    """Check the provided rule has the required attributes, throw exception if not"""
    if json_rule is None:
        raise Exception("Invalid rule: null")
    rule_id = json_rule.get('ruleId')
    if rule_id is None:
        raise Exception("Missing ruleId: " + str(json_rule))

def check_table(json_table, allow_multiple_families=False):
    """Check the provided table has the required attributes, throw exception if not"""
    if json_table is None:
        raise Exception("Invalid table: null")
    name = json_table.get('name')
    family = json_table.get('family')
    chains = json_table.get('chains')
    if name is None or not legal_nft_name(name):
        raise Exception("Invalid name (%s) in table" % name)
    if allow_multiple_families:
        for fam in family.split(","):
            if fam is None or fam not in ['ip', 'ip6', 'inet', 'arp', 'bridge', 'netdev']:
                raise Exception("Invalid family (%s) for table %s" % (fam, name))
    else:
        if family is None or family not in ['ip', 'ip6', 'inet', 'arp', 'bridge', 'netdev']:
            raise Exception("Invalid family (%s) for table %s" % (family, name))
    if chains is None:
        raise Exception("Invalid chains (null) for table %s" % name)

def check_log(json_log):
    """Check the provided log has the required attributes, throw exception if not"""
    if json_log is None:
        raise Exception("Invalid log: null")
    if json_log.get('type') is None:
        raise Exception("Invalid log type: null")
    if json_log.get('type') == 'NFLOG' and json_log.get('prefix') is None:
        raise Exception("Invalid log NFLOG prefix: null")
    if json_log.get('type') == 'DICT' and json_log.get('field') is None:
        raise Exception("Invalid log DICT field: null")
    if json_log.get('type') == 'DICT' and json_log.get('value') is None:
        raise Exception("Invalid log DICT value: null")

def check_action(json_action):
    """Check the provided action has the required attributes, throw exception if not"""
    if json_action is None:
        raise Exception("Invalid action: null")
    if json_action.get('type') is None:
        raise Exception("Invalid action type: null")

def check_family(family):
    """Check the provided string is a valid family - throw exception if not"""
    if family is None:
        raise Exception("Invalid family: null")
    if family not in ['ip', 'ip6', 'inet', 'arp', 'bridge', 'netdev']:
        raise Exception("Invalid family (" + family + ")")

def legal_nft_name(name):
    """Return true if a legal nft name, Fales otherwise"""
    if name is None:
        return False
    match = re.match("[a-z-]+", name)
    return match is not None

def get_limit_rate_unit_string(unit):
    """Get the nftable syntax for a rate limit constant"""
    return {
        "PACKETS_PER_SECOND": "/second",
        "PACKETS_PER_MINUTE": "/minute",
        "PACKETS_PER_HOUR": "/hour",
        "PACKETS_PER_DAY": "/day",
        "PACKETS_PER_WEEK": "/week",
        "BYTES_PER_SECOND": " bytes/second",
        "KBYTES_PER_SECOND": " kbytes/second",
        "MBYTES_PER_SECOND": " mbytes/second",
    }.get(unit, "/second")

def create_id_seq(parent, array, idSeqName, idName):
    """ create_id_seq is used to assign unique ids to items in an array within the settings, the sequence is held in an attribute on the array's parent node
        :param parent: (container) the parent container of the array that should hold the idSeqName attribute and value
        :param array: (array) an array of items that require unique ids
        :param idseqname: (string) the id sequence name to store in the parent container """
    if array:
        seq = parent.get(idSeqName) or max(item.get(idName) for item in array if item.get(idName) is not None)

        for item in array:
            # No ID and no Rank so this is probably a new item: use max(existing id) + 1
            if (item.get(idName) is None or item.get(idName) == 0):
                seq += 1
                item[idName] = seq

        parent[idSeqName] = seq

def clean_rule_actions(parent, array, tableName=None):
    """ clean_rule_actions is used to massage WAN_POLICY and DROP action rule types, as well as INTERFACE_TYPE conditions
        :param parent: (container) the parent container of the array that should hold the idSeqName attribute and value
        :param array: (array) an array of items that require unique ids
        :param (optional) tableName: (string) currently used for passing the tableName in for DROP action types """
    if array:
        for item in array:
            #If action exists on this item, we need to run some special checks for WAN_POLICY and DROP types :
            action = item.get("action")
            if action:
                if action.get("type") == "WAN_POLICY":
                    item['logs'] = [
                        {
                            "type": "NFLOG",
                            "prefix": "{\'type\':\'rule\',\'table\':\'wan-routing\',\'chain\':\'%s\',\'ruleId\':%d,\'action\':\'WAN_POLICY\',\'policy\':%d} " % (parent.get('name'), item.get('ruleId'), action.get('policy')),
                        },
                        {
                            "type": "DICT",
                            "field": "wan_rule_id",
                            "field_type": "INT",
                            "value": "%d" % item.get('ruleId'),
                        }
                    ]

            #_INTERFACE_TYPE conditions historically might be "wan", "lan", "unset"
            conditions = item.get("conditions")
            if conditions:
                for condition in conditions:
                    condition_type = condition.get("type")
                    if condition_type == "SOURCE_INTERFACE_TYPE":
                        value = condition.get("value")
                        if value == "unset":
                            condition["value"] = 0
                        elif value == "wan":
                            condition["value"] = 1
                        elif value == "lan":
                            condition["value"] = 2
