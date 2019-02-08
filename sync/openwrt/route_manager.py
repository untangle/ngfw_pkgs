"""route_manager manages wan based routing decisions"""
# pylint: disable=unused-argument
# pylint: disable=no-self-use
# pylint: disable=too-many-statements
# pylint: disable=line-too-long
import os
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

    def initialize(self):
        """initialize this module"""
        registrar.register_file(self.ifup_routes_filename, "restart-default-route", self)
        registrar.register_file(self.ifdown_routes_filename, "restart-default-route", self)
        registrar.register_file(self.rt_tables_filename, "restart-networking", self)
        registrar.register_file(self.wan_routing_filename, "restart-nftables-rules", self)

    def sanitize_settings(self, settings):
        """sanitizes settings"""
        pass

    def validate_settings(self, settings):
        """validates settings"""
        pass

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
                        "id": default_wan
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

        # the first go at wan routing support created these files, but
        # we don't need them anymore.  Eventually this can be removed
        delete_list.append("/etc/config/ifup.d/20-wan-balancer")
        delete_list.append("/etc/config/ifdown.d/20-wan-balancer")

    def write_wan_routing_file(self, settings, prefix=""):
        """write_wan_routing_file writes /etc/config/nftables-rules.d/102-wan-routing"""
        filename = prefix + self.wan_routing_filename
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        self.wan_routing_file = open(filename, "w+")
        file = self.wan_routing_file

        file.write("#!/bin/sh")
        file.write("\n\n")

        file.write("## Auto Generated\n")
        file.write("## DO NOT EDIT. Changes will be overwritten.\n")
        file.write("\n\n")

        file.write("nft delete table inet wan-routing 2>/dev/null || true\n")
        file.write("nft add table inet wan-routing\n")
        file.write("\n")
        file.write("nft add chain inet wan-routing wan-routing-exit\n")
        file.write("nft add rule inet wan-routing wan-routing-exit counter\n")
        file.write("nft add rule inet wan-routing wan-routing-exit mark and 0x0000ff00 == 0x0000 counter\n")

        interfaces = settings.get('network').get('interfaces')
        for intf in interfaces:
            if enabled_wan(intf):
                file.write("nft add chain inet wan-routing mark-for-wan-%d\n" % intf.get('interfaceId'))
                file.write("nft add rule inet wan-routing mark-for-wan-%d mark set mark and 0xffff00ff or 0x%x\n" % (intf.get('interfaceId'), ((intf.get('interfaceId') << 8) & 0xff00)))
                file.write("nft add rule inet wan-routing mark-for-wan-%d goto wan-routing-exit\n" % intf.get('interfaceId'))
                file.write("\n")

        default_wan = 0
        for intf in interfaces:
            if enabled_wan(intf):
                default_wan = intf.get('interfaceId')
                break

        file.write("nft add chain inet wan-routing route-to-default-wan\n")
        file.write("nft add rule inet wan-routing route-to-default-wan jump mark-for-wan-%d\n" % default_wan)
        file.write("\n")
        file.write("nft add chain inet wan-routing wan-policy-routing\n")
        file.write("\n")

        wan = settings['wan']
        policies = wan.get('policies')
        for policy in policies:
            if policy.get('enabled'):
                policyId = policy.get('policyId')
                interfaces = policy.get('interfaces')

                valid_wan_list = []
                for interface in interfaces:
                    interfaceId = interface.get('id')
                    if interface_meets_policy_criteria(settings, policy, interfaceId):
                        valid_wan_list.append(interface)

                file.write("nft add chain inet wan-routing route-to-policy-%d\n" % policyId)
                file.write("nft add rule inet wan-routing wan-policy-routing dict session ct id wan_policy long_string policy-%d jump route-to-policy-%d comment \\\"%s\\\"\n" % (policyId, policyId, policy.get('description')))

                if len(valid_wan_list) == 0:
                    file.write("nft add rule inet wan-routing route-to-policy-%d return comment \\\"policy disabled\\\"\n" % policyId)

                elif policy.get('type') == "SPECIFIC_WAN" or policy.get('type') == "BEST_OF":
                    interfaceId = valid_wan_list[0].get('id')
                    file.write("nft add rule inet wan-routing route-to-policy-%d jump mark-for-wan-%d\n" % (policyId, interfaceId))

                elif policy.get('type') == "BALANCE":
                    total_weight = 0
                    range_end = 0
                    balance_string = ""
                    algorithm = policy.get('balance_algorithm')

                    for interface in valid_wan_list:
                        interfaceId = interface.get('id')
                        if algorithm == "WEIGHTED":
                            weight = interface.get('weight')
                        else:
                            weight = 1

                        if total_weight > 0:
                            balance_string = balance_string + ", "

                        range_end = weight + total_weight - 1
                        if total_weight == range_end:
                            balance_string = balance_string + "%d : jump mark-for-wan-%d" % (total_weight, interfaceId)
                        else:
                            balance_string = balance_string + "%d-%d : jump mark-for-wan-%d" % (total_weight, range_end, interfaceId)

                        total_weight += weight

                    file.write("nft add inet wan-routing route-to-policy-%d numgen random mod %d vmap { %s }\n" % (policyId, total_weight, balance_string))

                file.write("\n")

        policy_chains = wan.get('policy_chains')
        for chain in policy_chains:
            file.write(nftables_util.chain_create_cmd(chain, "inet", "wan-routing") + "\n")
            file.write(nftables_util.chain_rules_cmds(chain, "inet", "wan-routing") + "\n")
            file.write("\n")

        file.write("nft add chain inet wan-routing wan-routing-entry\n")
        file.write("nft add rule inet wan-routing wan-routing-entry ip saddr 127.0.0.1 goto wan-routing-exit\n")
        file.write("nft add rule inet wan-routing wan-routing-entry ip daddr 127.0.0.1 goto wan-routing-exit\n")
        file.write("nft add rule inet wan-routing wan-routing-entry ip6 saddr ::1 goto wan-routing-exit\n")
        file.write("nft add rule inet wan-routing wan-routing-entry ip6 daddr ::1 goto wan-routing-exit\n")
        file.write("nft add rule inet wan-routing wan-routing-entry mark and 0x0000ff00 != 0 goto wan-routing-exit\n")
        file.write("nft add rule inet wan-routing wan-routing-entry jump user-wan-rules\n")
        file.write("nft add rule inet wan-routing wan-routing-entry jump wan-policy-routing\n")
        file.write("nft add rule inet wan-routing wan-routing-entry mark and 0x0000ff00 != 0 goto wan-routing-exit\n")
        file.write("nft add rule inet wan-routing wan-routing-entry jump route-to-default-wan\n")
        file.write("nft add rule inet wan-routing wan-routing-entry goto wan-routing-exit\n")

        file.write("\n")
        file.write("nft add chain inet wan-routing wan-routing-prerouting \"{ type filter hook prerouting priority -25 ; }\"\n")
        file.write("nft add rule inet wan-routing wan-routing-prerouting jump wan-routing-entry\n")

        file.write("\n")
        file.write("nft add chain inet wan-routing wan-routing-output \"{ type filter hook output priority -135 ; }\"\n")
        file.write("nft add rule inet wan-routing wan-routing-output jump wan-routing-entry\n")

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
    if intf.get('configType') != 'DISABLED' and intf.get('wan'):
        return True
    return False

def get_interface_by_id(settings, interfaceId):
    """ returns interface with the given interfaceId """
    interfaces = settings.get('network').get('interfaces')
    for intf in interfaces:
        if intf.get('interfaceId') == interfaceId:
            return intf
    return None

def interface_meets_policy_criteria(settings, policy, interface):
    """
    returns true if the interface meets all criteria that can
    be verified at creation time that are specified by the
    wan policy
    """
    intf = get_interface_by_id(settings, interface)
    if not enabled_wan(intf):
        return False

    criteria = policy.get('criteria')
    if criteria == None:
        return True

    for criterion in criteria:
        if criterion.get('type') == 'ATTRIBUTE':
            if criterion.get('attribute') == 'VPN':
                if intf.get('type') != 'OPENVPN' and intf.get('type') != 'WIREGUARD':
                    return False
    return True

registrar.register_manager(RouteManager())
