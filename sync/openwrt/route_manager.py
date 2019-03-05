"""route_manager manages wan based routing decisions"""
# pylint: disable=unused-argument
# pylint: disable=no-self-use
# pylint: disable=too-many-statements
# pylint: disable=line-too-long
import copy
import os
import json
import stat
from sync import registrar
from sync import nftables_util
from sync import network_util

# This class is responsible for writing /etc/iproute2/rt_tables and /etc/hotplug.d/iface/*
# based on the settings object passed from sync-settings


class RouteManager:
    """Manages files responsible for wan routing"""
    rt_tables_filename = "/etc/iproute2/rt_tables"
    rt_tables_file = None
    ifup_routes_filename = "/etc/config/ifup.d/10-default-route"
    ifup_route_file = None
    ifdown_routes_filename = "/etc/config/ifdown.d/10-default-route"
    ifdown_route_file = None
    wan_routing_filename = "/etc/config/nftables-rules.d/102-wan-routing"
    wan_routing_file = None
    wan_policy_filename = "/etc/config/wan_policy.json"
    wan_policy_file = None

    def initialize(self):
        """initialize this module"""
        registrar.register_file(self.ifup_routes_filename, "restart-default-route", self)
        registrar.register_file(self.ifdown_routes_filename, "restart-default-route", self)
        registrar.register_file(self.rt_tables_filename, "restart-networking", self)
        registrar.register_file(self.wan_routing_filename, "restart-wan-routing", self)
        registrar.register_file(self.wan_policy_filename, "restart-wan-manager", self)

    def sanitize_settings(self, settings):
        """sanitizes settings"""
        wan = settings['wan']
        policies = wan.get('policies')
        highest_policy_id = 0
        for policy in policies:
            policy_id = policy.get('policyId')
            if policy_id is not None and policy_id > highest_policy_id:
                highest_policy_id = policy_id

        highest_policy_id += 1

        for policy in policies:
            policy_id = policy.get('policyId')
            if policy_id is None:
                policy['policyId'] = highest_policy_id
                highest_policy_id += 1

        policy_chains = wan.get('policy_chains')
        for chain in policy_chains:
            rule_id = 1
            for rule in chain.get('rules'):
                rule['ruleId'] = rule_id
                rule_id += 1

    def validate_settings(self, settings):
        """validates settings"""
        wan = settings['wan']
        policies = wan.get('policies')
        policy_ids = []
        for policy in policies:
            interfaces = policy.get('interfaces')
            policy_id = policy.get('policyId')
            if policy_id is None:
                raise Exception("Policy missing policyId")
            policy_ids.append(policy_id)
            if interfaces is None:
                raise Exception("No interfaces specified: policy " + str(policy_id))

            for interface in interfaces:
                if interface.get('interfaceId') is None:
                    raise Exception("No interface id specified: policy " + str(policy_id))

                weight = interface.get('weight')
                if weight is not None and (weight > 10000 or weight < 1):
                    raise Exception("Invalid interface weight specified: policy " + str(policy_id) + " " + str(weight))
        policy_chains = wan.get("policy_chains")
        if policy_chains is None:
            raise Exception("Missing policy_chains in WAN settings")
        for policy_chain in policy_chains:
            if policy_chain.get("rules") is None:
                raise Exception("Missing rules in wan settings policy chain.")
            for rule in policy_chain.get("rules"):
                action = rule.get("action")
                rule_id = rule.get("ruleId")
                if rule_id is None:
                    raise Exception("Missing ruleId in WAN rule")
                if action is None:
                    raise Exception("Missing action in WAN rule" + str(rule.get("ruleId")))
                if rule.get("enabled") is None:
                    raise Exception("Missing enabled in WAN rule" + str(rule.get("ruleId")))
                if action.get("type") is None:
                    raise Exception("Missing action type in WAN rule" + str(rule.get("ruleId")))
                if action.get("type") == "WAN_POLICY":
                    if action.get("policy") not in policy_ids:
                        raise Exception("WAN rule " + str(rule.get("ruleId")) + " uses missing WAN policy " + str(action.get("policy")))

    def create_settings(self, settings, prefix, delete_list, filename):
        """creates settings"""
        print("%s: Initializing settings" % self.__class__.__name__)

        default_wan = 0
        interfaces = settings.get('network').get('interfaces')
        for intf in interfaces:
            if enabled_wan(intf):
                default_wan = intf.get('interfaceId')
                break

        settings['wan'] = {}
        settings['wan']['policy_chains'] = [
            {
                "default": True,
                "description": "User defined wan routing rules",
                "name": "user-wan-rules",
                "rules": [
                    {
                        "action": {
                            "policy": 1,
                            "type": "WAN_POLICY"
                        },
                        "conditions": [],
                        "description": "Send all traffic to wan policy 1",
                        "enabled": True,
                        "ruleId": 1
                    }
                ]
            }
        ]
        settings['wan']['policies'] = [
            {
                "policyId": 1,
                "description": "Send traffic to external",
                "enabled": True,
                "type": "SPECIFIC_WAN",
                "interfaces": [
                    {
                        "interfaceId": default_wan
                    }
                ],
                "criteria": []
            }
        ]

    def sync_settings(self, settings, prefix, delete_list):
        """syncs settings"""
        print("%s: Syncing settings" % self.__class__.__name__)
        self.write_rt_tables_file(settings, prefix)
        self.write_ifup_routes_file(settings, prefix)
        self.write_ifdown_routes_file(settings, prefix)
        self.write_wan_routing_file(settings, prefix)
        self.write_wan_policy_file(settings, prefix)

        # the first go at wan routing support created these files, but
        # we don't need them anymore.  Eventually this can be removed
        delete_list.append("/etc/config/ifup.d/20-wan-balancer")
        delete_list.append("/etc/config/ifdown.d/20-wan-balancer")

    def write_wan_policy_file(self, settings, prefix=""):
        """write_wan_policy_file writes /etc/config/wan_policy.json"""
        filename = prefix + self.wan_policy_filename
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        policy_settings = {}
        policy_settings['wan'] = settings.get('wan')
        policy_settings['network'] = {}
        policy_interfaces = []
        interfaces = settings.get('network').get('interfaces')
        for intf in interfaces:
            if intf.get('wan'):
                policy_interfaces.append(intf)
        policy_settings['network']['interfaces'] = policy_interfaces

        try:
            self.wan_policy_file = open(filename, "w+")
            json.dump(policy_settings, self.wan_policy_file, indent=4, separators=(',', ': '))
            self.wan_policy_file.flush()
            self.wan_policy_file.close()
        except IOError as exc:
            traceback.print_exc()

        print("%s: Wrote %s" % (self.__class__.__name__, filename))

    def write_wan_routing_file(self, settings, prefix=""):
        """write_wan_routing_file writes /etc/config/nftables-rules.d/102-wan-routing"""
        filename = prefix + self.wan_routing_filename
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        self.wan_routing_file = open(filename, "w+")
        file = self.wan_routing_file

        file.write("#!/usr/sbin/nft -f")
        file.write("\n\n")

        file.write("## Auto Generated\n")
        file.write("## DO NOT EDIT. Changes will be overwritten.\n")
        file.write("\n\n")

        file.write("add table inet wan-routing\n")
        file.write("flush table inet wan-routing\n")
        file.write("add table inet wan-routing\n")
        file.write("\n")

        interfaces = settings.get('network').get('interfaces')
        for intf in interfaces:
            if enabled_wan(intf):
                file.write("add set inet wan-routing wan-%d-table { type ipv4_addr . ipv4_addr; flags timeout; }\n" % intf.get('interfaceId'))
                file.write("add chain inet wan-routing mark-for-wan-%d\n" % intf.get('interfaceId'))
                file.write("add rule inet wan-routing mark-for-wan-%d mark set mark and 0xffff00ff or 0x%x\n" % (intf.get('interfaceId'), ((intf.get('interfaceId') << 8) & 0xff00)))
                file.write("add rule inet wan-routing mark-for-wan-%d set update ip saddr . ip daddr timeout 1m @wan-%d-table\n" % (intf.get('interfaceId'), intf.get('interfaceId')))
                file.write("add rule inet wan-routing mark-for-wan-%d set update ip daddr . ip saddr timeout 1m @wan-%d-table\n" % (intf.get('interfaceId'), intf.get('interfaceId')))
                file.write("add rule inet wan-routing mark-for-wan-%d accept\n" % intf.get('interfaceId'))
                file.write("\n")

        default_wan = 0
        for intf in interfaces:
            if enabled_wan(intf):
                default_wan = intf.get('interfaceId')
                break

        file.write("add chain inet wan-routing route-to-default-wan\n")
        file.write("add rule inet wan-routing route-to-default-wan dict sessions ct id wan_policy long_string set system-default\n")
        file.write("add rule inet wan-routing route-to-default-wan jump mark-for-wan-%d\n" % default_wan)
        file.write("\n")
        file.write("add chain inet wan-routing route-via-cache\n")
        file.write("\n")

        wan = settings['wan']
        policies = wan.get('policies')
        for policy in policies:
            policyId = policy.get('policyId')

            file.write("add set inet wan-routing policy-%d-table { type ipv4_addr . ipv4_addr; flags timeout; }\n" % policyId)
            file.write("add chain inet wan-routing route-to-policy-%d\n" % policyId)
            file.write("add rule inet wan-routing route-to-policy-%d return comment \"policy disabled\"\n" % policyId)
            file.write("add rule inet wan-routing route-via-cache ip saddr . ip daddr @policy-%d-table dict sessions ct id wan_policy long_string set policy-%d-cache\n" % (policyId, policyId))
            file.write("\n")

        policy_chains = wan.get('policy_chains')
        for chain in policy_chains:
            file.write(nftables_util.chain_create_cmd(chain, "inet", None, "wan-routing").replace("nft add", "add").replace("'","") + "\n")
            file.write(nftables_util.chain_rules_cmds(chain, "inet", None, "wan-routing").replace("nft add", "add").replace("'","") + "\n")
            file.write("\n")

        for intf in interfaces:
            if enabled_wan(intf):
                file.write("add rule inet wan-routing route-via-cache ip saddr . ip daddr @wan-%d-table jump mark-for-wan-%d\n" % (intf.get('interfaceId'), intf.get('interfaceId')))

        file.write("add chain inet wan-routing wan-routing-entry\n")
        file.write("add rule inet wan-routing wan-routing-entry ip saddr 127.0.0.1 return\n")
        file.write("add rule inet wan-routing wan-routing-entry ip daddr 127.0.0.1 return\n")
        file.write("add rule inet wan-routing wan-routing-entry ip6 saddr ::1 return\n")
        file.write("add rule inet wan-routing wan-routing-entry ip6 daddr ::1 return\n")
        file.write("add rule inet wan-routing wan-routing-entry mark and 0x0000ff00 != 0 return\n")
        file.write("add rule inet wan-routing wan-routing-entry jump route-via-cache\n")
        file.write("add rule inet wan-routing wan-routing-entry jump user-wan-rules\n")
        file.write("add rule inet wan-routing wan-routing-entry counter\n")
        file.write("add rule inet wan-routing wan-routing-entry jump route-to-default-wan\n")
        file.write("add rule inet wan-routing wan-routing-entry counter\n")

        file.write("\n")
        file.write("add chain inet wan-routing wan-routing-prerouting { type filter hook prerouting priority -25 ; }\n")
        file.write("add rule inet wan-routing wan-routing-prerouting jump wan-routing-entry\n")

        file.write("\n")
        file.write("add chain inet wan-routing wan-routing-output { type filter hook output priority -135 ; }\n")
        file.write("add rule inet wan-routing wan-routing-output jump wan-routing-entry\n")

        file.flush()
        file.close()

        print("%s: Wrote %s" % (self.__class__.__name__, filename))
        os.chmod(filename, os.stat(filename).st_mode | stat.S_IEXEC)

    def write_rt_tables_file(self, settings, prefix=""):
        """write_rt_tables_file writes /etc/iproute2/rt_tables"""
        filename = prefix + self.rt_tables_filename
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        self.rt_tables_file = open(filename, "w+")
        file = self.rt_tables_file

        file.write("## Auto Generated\n")
        file.write("## DO NOT EDIT. Changes will be overwritten.\n")
        file.write("\n\n")

        file.write("#\n")
        file.write("# reserved values\n")
        file.write("#\n")
        file.write("128\tprelocal\n")
        file.write("255\tlocal\n")
        file.write("254\tmain\n")
        file.write("253\tdefault\n")
        file.write("0\tunspec\n")
        file.write("#\n")
        file.write("# local\n")
        file.write("#\n")
        file.write("#1\tinr.ruhep\n")
        file.write("\n\n")
        file.write("#\n")
        file.write("# WAN tables\n")
        file.write("#\n")

        interfaces = settings.get('network').get('interfaces')
        for intf in interfaces:
            if enabled_wan(intf):
                interface_id = intf.get('interfaceId')
                file.write("%d\twan.%d\n" % (interface_id, interface_id))

        file.write("\n\n")

        file.flush()
        file.close()

        print("%s: Wrote %s" % (self.__class__.__name__, filename))

    def write_ifup_routes_file(self, settings, prefix=""):
        """write_ifup_routes_file writes /etc/config/ifup.d/10-default-route"""
        filename = prefix + self.ifup_routes_filename
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        self.ifup_route_file = open(filename, "w+")
        file = self.ifup_route_file
        file.write("#!/bin/sh")
        file.write("\n\n")
        file.write("## Auto Generated\n")
        file.write("## DO NOT EDIT. Changes will be overwritten.\n")
        file.write("\n")
        file.write(". /lib/functions/network.sh\n")
        file.write("\n")
        file.write("INTERFACE=$1\n")
        file.write("DEVICE=$2\n")
        file.write("\n")

        if get_number_of_wans(settings) == 1:
            file.write("\n# Only one wan, do nothing\n\n")
        else:
            interfaces = settings.get('network').get('interfaces')
            for intf in interfaces:
                if enabled_wan(intf):
                    file.write("[ %s = \"$INTERFACE\" ] && {\n" % network_util.get_interface_name(settings, intf))
                    file.write("\tnft list chain inet wan-routing route-to-default-wan | grep -q mark-for-wan- || {\n")
                    file.write("\t\tnft flush chain inet wan-routing route-to-default-wan\n")
                    file.write("\t\tnft add rule inet wan-routing route-to-default-wan dict sessions ct id wan_policy long_string set system-default\n")
                    file.write("\t\tnft add rule inet wan-routing route-to-default-wan jump mark-for-wan-%d\n" % intf.get('interfaceId'))
                    file.write("\t}\n")
                    file.write("\texit 0\n")
                    file.write("}\n\n")

        file.flush()
        file.close()
        os.chmod(filename, os.stat(filename).st_mode | stat.S_IEXEC)

        print("%s: Wrote %s" % (self.__class__.__name__, filename))

    def write_ifdown_routes_file(self, settings, prefix=""):
        """write_ifdown_routes_file writes /etc/config/ifdown.d/10-default-route"""
        filename = prefix + self.ifdown_routes_filename
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        self.ifdown_route_file = open(filename, "w+")
        file = self.ifdown_route_file
        file.write("#!/bin/sh")
        file.write("\n\n")
        file.write("## Auto Generated\n")
        file.write("## DO NOT EDIT. Changes will be overwritten.\n")
        file.write("\n")
        file.write(". /lib/functions/network.sh\n")
        file.write("\n")
        file.write("INTERFACE=$1\n")

        if get_number_of_wans(settings) == 1:
            file.write("\n# Only one wan, do nothing\n\n")
        else:
            file.write("TMPFILE=`mktemp -t default-route.XXXXXX`\n")
            file.write("\n")
            file.write("write_rules()\n")
            file.write("{\n")
            file.write("\tnft -f $TMPFILE\n")
            file.write("\trm $TMPFILE\n")
            file.write("\texit 0\n")
            file.write("}\n\n")
            file.write("update_default_route()\n")
            file.write("{\n")
            file.write("\n")
            file.write("\techo flush chain inet wan-routing route-to-default-wan >> $TMPFILE\n")

            interfaces = settings.get('network').get('interfaces')
            for intf in interfaces:
                if enabled_wan(intf):
                    file.write("\tnetwork_is_up %s && {\n" % network_util.get_interface_name(settings, intf))
                    file.write("\t\techo add rule inet wan-routing route-to-default-wan dict sessions ct id wan_policy long_string set system-default >> $TMPFILE\n")
                    file.write("\t\techo add rule inet wan-routing route-to-default-wan jump mark-for-wan-%d >> $TMPFILE\n" % intf.get('interfaceId'))
                    file.write("\t\twrite_rules\n")
                    file.write("\t}\n\n")

            file.write("}\n\n")

            for intf in interfaces:
                if enabled_wan(intf):
                    file.write("[ %s = \"$INTERFACE\" ] && {\n" % network_util.get_interface_name(settings, intf))
                    file.write("\tnft list chain inet wan-routing route-to-default-wan | grep -q mark-for-wan-%d && {\n" % intf.get('interfaceId'))
                    file.write("\t\tupdate_default_route\n")
                    file.write("\t}\n")
                    file.write("}\n\n")

            file.write("[ -z \"$INTERFACE\" ] && {\n")
            file.write("\tupdate_default_route\n")
            file.write("}\n\n")

        file.flush()
        file.close()
        os.chmod(filename, os.stat(filename).st_mode | stat.S_IEXEC)

        print("%s: Wrote %s" % (self.__class__.__name__, filename))

def get_number_of_wans(settings):
    """returns number of enabled wan interfaces"""
    wans = 0
    interfaces = settings.get('network').get('interfaces')
    for intf in interfaces:
        if enabled_wan(intf):
            wans += 1

    return wans

def enabled_wan(intf):
    """returns true if the interface is an enabled wan"""
    if intf is None:
        return False

    if intf.get('configType') != 'DISABLED' and intf.get('wan'):
        return True
    return False

registrar.register_manager(RouteManager())
