import os
import sys
import subprocess
import datetime
import traceback
import string
import re
from sync.network_util import NetworkUtil, get_is_wireguard, get_virtual_interface_by_id

# This class is a utility class with utility functions providing
# useful tools for dealing with iptables rules
class IptablesUtil:
    iptables_wireguard_table_format_map = {
        'src_mark': '0xf9/0xff',
        'dst_mark': '0xf900/0xff00',
        'wireguard_ip_address': '',
        # wan_mark is a special case that needs to duplicate the rule
        # for as many wan interfaces are available.
        'wan_mark': '{wan_mark}'
    }

    @staticmethod
    def interface_condition_string_to_interface_list( value ):
        """
        Real, actual interface ids (integers) from settings
        """
        intfs = []
        
        for substr in value.split(","):
            if substr == "wan":
                intf_values  = NetworkUtil.wan_list()
                for intfId in intf_values:
                    if intfId not in intfs:
                        intfs.append(intfId)
            elif substr == "non_wan":
                intf_values  = NetworkUtil.non_wan_list()
                for intfId in intf_values:
                    if intfId not in intfs:
                        intfs.append(intfId)
            elif substr.isnumeric():
                intfs.append(int(substr))

        return intfs

    @staticmethod
    def interface_condition_string_to_virtual_interface_list( value ):
        """
        Not actual interfaces but should "behave" like interfaces, namely
        IPSec traffic.
        """
        virtual_intfs = []

        for substr in value.split(","):
            if substr == "non_wan" or \
               substr == "ipsec":
                ## Ipsec
                virtual_intfs.append("-m policy --pol ipsec --dir in")

        return virtual_intfs

    # This method takes a list of conditions from a rule and translates them into a commands that must run prior to inserting the rules
    # It returns a list of strings
    # This is necessary because some conditions require some prep work
    # Example input: ['conditionType':'CLIENT_TAGGED', 'value':'tag'] -> ["ipset create set iphash"]
    # Example input: ['conditionType':'SRC_INTF', 'value':'1'] -> []
    @staticmethod
    def conditions_to_prep_commands( conditions, comment=None, verbosity=0 ):
        current_strings = [];
        if conditions is None:
            return current_strings;
        
        for condition in conditions:
            if 'conditionType' not in condition:
                print("ERROR: Ignoring invalid condition: %s" % str(condition))
                continue

            conditionStr = ""
            conditionType = condition['conditionType']
            invert = False
            value = None
            if 'value' in condition:
                value = condition['value']
            if 'invert' in condition and condition['invert']:
                invert = True

            if conditionType == "CLIENT_TAGGED" or conditionType == "SERVER_TAGGED":
                tags = value.split(",")
                for i in range(0 , len(tags) ):
                    setname = "tag-"+re.sub(r'[^a-zA-Z0-9]',r'',tags[i])
                    current_strings = current_strings + [ "ipset create %s iphash >/dev/null 2>&1"%setname ]

        return current_strings;
            
            
    # This method takes a list of conditions from a rule and translates them into a string containing the iptables conditions
    # It returns a list of strings, because some set of conditions require multiple iptables rules
    # Example input: ['conditionType':'SRC_INTF', 'value':'1'] -> ["-m connmark --mark 0x01/0xff"]
    # Example input: ['conditionType':'DST_PORT', 'value':'123'] -> ["-p udp --dport 123", "-p tcp --dport 123"]
    @staticmethod
    def conditions_to_iptables_string( conditions, comment=None, verbosity=0 ):
        current_strings = [ "" ];
        if conditions is None:
            return current_strings;

        if comment != None:
                current_strings = [ current + (" -m comment --comment \"%s\" " % comment)  for current in current_strings ]

        hasProtocolCondition = False
        for condition in conditions:
            if 'conditionType' not in condition:
                print("ERROR: Ignoring invalid condition: %s" % str(condition))
                continue
            if condition['conditionType'] == 'PROTOCOL':
                hasProtocolCondition = True

        for condition in conditions:
            if 'conditionType' not in condition:
                print("ERROR: Ignoring invalid condition: %s" % str(condition))
                continue

            conditionStr = ""
            conditionType = condition['conditionType']
            invert = False
            value = None
            if 'value' in condition:
                value = condition['value']
            if 'invert' in condition and condition['invert']:
                invert = True

            if conditionType == "PROTOCOL":
                if "any" in value:
                    continue

                protos = value.split(",")
                if invert and len(protos)>1:
                    print("ERROR: invert not supported on multiple protocol condition")
                    continue
                if len(protos) == 0:
                    print("ERROR: interface condition with no interfaces")
                    continue
                orig_current_strings = current_strings
                current_strings = []
                # split current rules for each protocol specified
                for i in range(0 , len(protos) ):
                    conditionStr = ""
                    if invert:
                        conditionStr = conditionStr + " ! "
                    conditionStr = conditionStr + (" --protocol %s " % str(protos[i])).lower()
                    current_strings = current_strings + [ conditionStr + current for current in orig_current_strings ]

            if conditionType == "SRC_INTF" or \
               conditionType == "DST_INTF":
                if "any" in value:
                    continue # no need to do anything

                interfaces = IptablesUtil.interface_condition_string_to_interface_list( value ) + \
                             IptablesUtil.interface_condition_string_to_virtual_interface_list( value )

                if invert and len(interfaces) > 1:
                    print("ERROR: invert not supported on multiple interface condition")
                    continue
                if len(interfaces) == 0:
                    print("ERROR: interface condition with no interfaces")
                    continue
                orig_current_strings = current_strings
                current_strings = []
                # split current rules for each intf specified
                for interface in interfaces:
                    conditionStr = ""
                    if invert:
                        conditionStr += " ! "
                    if isinstance(interface, (int)):
                        if conditionType == "DST_INTF":
                            conditionStr += (" -m connmark --mark 0x%04X/0xFF00 " % (int(interface) << 8))  
                        else:
                            conditionStr += (" -m connmark --mark 0x%04X/0x00FF " % int(interface))
                    else:
                        conditionStr += interface
                    current_strings = current_strings + [ current + conditionStr for current in orig_current_strings ]

            if conditionType == "SRC_MAC":
                if "any" in value:
                    continue

                macs = value.split(",")
                if invert and len(macs)>1:
                    print("ERROR: invert not supported on multiple protocol condition")
                    continue
                if len(macs) == 0:
                    print("ERROR: interface condition with no interfaces")
                    continue
                orig_current_strings = current_strings
                current_strings = []
                # split current rules for each mac specified
                for i in range(0 , len(macs) ):
                    conditionStr = ""
                    if invert:
                        conditionStr = conditionStr + " ! "
                    conditionStr = conditionStr + (" -m mac --mac-source %s " % str(macs[i]).lower())
                    current_strings = current_strings + [ conditionStr + current for current in orig_current_strings ]

            if conditionType == "SRC_ADDR":
                if "any" in value:
                    continue # no need to do anything

                srcs = value.split(",")
                if invert and len(srcs) > 1:
                    print("ERROR: invert not supported on multiple addr condition")
                    continue
                if len(srcs) == 0:
                    print("ERROR: address condition with no interfaces")
                    continue

                orig_current_strings = current_strings
                current_strings = []
                for i in srcs:
                    conditionStr = ""
                    if invert:
                        conditionStr = conditionStr + " ! "
                    if "-" in i:
                        conditionStr = conditionStr + " -m iprange --src-range %s " % i
                    else:
                        conditionStr = conditionStr + " --source %s " % i
                    current_strings = current_strings + [ current + conditionStr for current in orig_current_strings ]

            if conditionType == "DST_ADDR":
                if "any" in value:
                    continue # no need to do anything

                dsts = value.split(",")
                if invert and len(dsts) > 1:
                    print("ERROR: invert not supported on multiple addr condition")
                    continue
                if len(dsts) == 0:
                    print("ERROR: address condition with no interfaces")
                    continue

                orig_current_strings = current_strings
                current_strings = []
                for i in dsts:
                    conditionStr = ""
                    if invert:
                        conditionStr = conditionStr + " ! "
                    if "-" in i:
                        conditionStr = conditionStr + " -m iprange --dst-range %s " % i
                    else:
                        conditionStr = conditionStr + " --destination %s " % i
                    current_strings = current_strings + [ current + conditionStr for current in orig_current_strings ]

            if conditionType == "SRC_PORT":
                if "any" in value:
                    continue # no need to do anything

                value = value.replace("-",":").replace(" ","") # iptables uses colon to represent range not dash
                conditionStr = conditionStr + " -m multiport"
                if invert:
                    conditionStr = conditionStr + " ! "
                conditionStr = conditionStr + " --source-ports %s " % value
                if not hasProtocolCondition:
                    # port explicitly means either TCP or UDP, since no protocol condition has been specified, use "TCP,UDP" as the protocol condition
                    current_strings = [ " --protocol udp " + current for current in current_strings ] + [ " --protocol tcp " + current for current in current_strings ]
                current_strings = [ current + conditionStr for current in current_strings ]

            if conditionType == "DST_PORT":
                if "any" in value:
                    continue # no need to do anything

                value = value.replace("-",":").replace(" ","") # iptables uses colon to represent range not dash
                conditionStr = conditionStr + " -m multiport " 
                if invert:
                    conditionStr = conditionStr + " ! "
                conditionStr = conditionStr + " --destination-ports %s " % value
                if not hasProtocolCondition:
                    # port explicitly means either TCP or UDP, since no protocol condition has been specified, use "TCP,UDP" as the protocol condition
                    current_strings = [ " --protocol udp " + current for current in current_strings ] + [ " --protocol tcp " + current for current in current_strings ]
                current_strings = [ current + conditionStr for current in current_strings ]

            if conditionType == "DST_LOCAL":
                if invert:
                    conditionStr = conditionStr + " ! "
                conditionStr = conditionStr + " -m addrtype --dst-type local "
                current_strings = [ current + conditionStr for current in current_strings ]

            if conditionType == "CLIENT_TAGGED":
                if "any" in value:
                    continue

                tags = value.split(",")
                if invert and len(tags)>1:
                    print("ERROR: invert not supported on multiple protocol condition")
                    continue
                if len(tags) == 0:
                    print("ERROR: interface condition with no interfaces")
                    continue
                orig_current_strings = current_strings
                current_strings = []
                # split current rules for each protocol specified
                for i in range(0 , len(tags) ):
                    setname = "tag-" + re.sub(r'[^a-zA-Z0-9]',r'',tags[i])
                    conditionStr = " -m set "
                    if invert:
                        conditionStr = conditionStr + " ! "
                    conditionStr = conditionStr + (" --match-set %s src " % setname)
                    current_strings = current_strings + [ conditionStr + current for current in orig_current_strings ]

            if conditionType == "SERVER_TAGGED":
                if "any" in value:
                    continue

                tags = value.split(",")
                if invert and len(tags)>1:
                    print("ERROR: invert not supported on multiple protocol condition")
                    continue
                if len(tags) == 0:
                    print("ERROR: interface condition with no interfaces")
                    continue
                orig_current_strings = current_strings
                current_strings = []
                # split current rules for each protocol specified
                for i in range(0 , len(tags) ):
                    conditionStr = " -m set "
                    setname = re.sub(r'[^a-zA-Z0-9]',r'',tags[i])
                    if invert:
                        conditionStr = conditionStr + " ! "
                    conditionStr = conditionStr + (" --match-set tag-%s dst " % setname)
                    current_strings = current_strings + [ conditionStr + current for current in orig_current_strings ]

        return current_strings;
        
    @staticmethod
    def commands_for_wireguard(conditions, comment=None):
        commands = []
        if conditions is None:
            return commands;
        begin_comment = ''
        if comment is not None:
            begin_comment += comment
            begin_comment += ': '

        for condition in conditions:
            if 'conditionType' not in condition:
                print("ERROR: Ignoring invalid condition: %s" % str(condition))
                continue
            if condition['conditionType'] == "DST_INTF" or condition['conditionType'] == "SRC_INTF":
                conditionType = condition['conditionType']
                if 'value' not in condition:
                    continue
                value = condition['value']
                if "any" in value:
                    continue
                interfaces = IptablesUtil.interface_condition_string_to_interface_list( value ) + \
                             IptablesUtil.interface_condition_string_to_virtual_interface_list( value )
                if interfaces is None:
                    continue
                network_settings = {'network': NetworkUtil.settings}
                wireguard_ip_address = None
                wireguard_intf = subprocess.Popen("ip address show dev {0}".format("wg0"), shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT).communicate()[0].decode("ascii").split()
                if 'inet' in wireguard_intf:
                    wireguard_ip_address = wireguard_intf[wireguard_intf.index('inet') + 1].split('/')[0]
                for interface in interfaces:
                    if isinstance(interface, (int)):
                        isWireguard = get_is_wireguard(network_settings, interface)
                        if isWireguard:
                            if conditionType == "DST_INTF":
                                
                                iptables_table_chain_rules = {
                                    "nat": {
                                        "nat-rules": [{
                                            'new': 'insert',
                                            'rule': '-m mark --mark {wan_mark}/0xffff -j MASQUERADE -m comment --comment "' + begin_comment + 'NAT WAN-bound wireguard vpn traffic"'
                                        }]
                                    },
                                    "filter": {
                                        "nat-reverse-filter": [{
                                            'new': 'insert',
                                            'rule': '-m mark --mark {src_mark} -j RETURN -m comment --comment "' + begin_comment + 'Allow wireguard vpn"'
                                        }]
                                    }
                                }
                                if wireguard_ip_address is not None:
                                    iptables_table_chain_rules["nat"]["port-forward-rules"] = [
                                        {
                                            'new': 'insert',
                                            'rule': '-p tcp -d {wireguard_ip_address} --destination-port 443 -j REDIRECT --to-ports 443 -m comment --comment "' + begin_comment + 'Send wireguard VPN to apache http"'
                                        },{
                                            'new': 'insert',
                                            'rule': '-p tcp -d {wireguard_ip_address} --destination-port 80 -j REDIRECT --to-ports 80 -m comment --comment "' + begin_comment + 'Send wireguard to apache https"'
                                        }
                                    ]
                                delete_rules, new_rules = IptablesUtil.write_wireguard_iptables_rules(iptables_table_chain_rules, wireguard_ip_address_arg=wireguard_ip_address)
                                commands += delete_rules
                                commands += new_rules

        return commands

    @staticmethod
    def write_wireguard_iptables_rules(iptables_table_chain_rules, wireguard_ip_address_arg=None):
        """ Write iptables specific rules for wireguard """
        delete_rule_template = "$IPTABLES -t {table} -D {chain} {rule} >/dev/null 2>&1"
        wan_marks = []
        for interface_id in NetworkUtil.wan_list():
            wan_marks.append(hex((interface_id << 8) + 0x00fa))
        delete_rules = []
        new_rules = []

        iptables_table_format_map = IptablesUtil.iptables_wireguard_table_format_map
        wireguard_ip_address = None
        if wireguard_ip_address_arg is not None:
            iptables_table_format_map['wireguard_ip_address'] = wireguard_ip_address_arg

        for table in sorted(iptables_table_chain_rules.keys()):
            for chain in sorted(iptables_table_chain_rules[table].keys()):
                format_map = {'table': table, 'chain': chain}
                for rule in iptables_table_chain_rules[table][chain]:
                    updated_rule = rule['rule'].format_map(iptables_table_format_map)

                    format_map['comment'] = None
                    if 'comment' in rule:
                        format_map['comment'] = rule['comment']
                    else:
                        iptables_rule_comment_re = re.compile(r'--comment "([^"]+)"')
                        match = re.search(iptables_rule_comment_re, rule['rule'])
                        if match:
                            format_map['comment'] = match.group(1)

                    if format_map['comment'] is not None:
                        delete_rules.append('## {comment}'.format_map(format_map)) 
                        new_rules.append('## {comment}'.format_map(format_map))

                    if '{wan_mark}' in updated_rule:
                        for wan_mark in wan_marks:
                            format_map['rule'] = updated_rule.format(wan_mark=wan_mark)
                            delete_rules.append(delete_rule_template.format_map(format_map))
                            new_rules.append(IptablesUtil.create_new_rule(rule, format_map))
                    else:
                        format_map['rule'] = updated_rule
                        delete_rules.append(delete_rule_template.format_map(format_map))
                        new_rules.append(IptablesUtil.create_new_rule(rule, format_map))

                    delete_rules.append("")
                    new_rules.append("")
        return delete_rules, new_rules

    @staticmethod
    def create_new_rule(rule, format_map):
        """
        Create a new (add or insert) iptables rule
        """
        add_rule_template = "$IPTABLES -t {table} -A {chain} {rule}"
        insert_rule_template = "$IPTABLES -t {table} -I {chain} {index} {rule}"
        template = add_rule_template
        if 'new' in rule and rule['new'] == 'insert':
            template = insert_rule_template
            if 'index' in rule:
                format_map['index'] = rule['index']
            else:
                format_map['index'] = ''

        new_rule = template.format_map(format_map)
        if 'index' in rule:
            del rule['index']
        return new_rule
        
