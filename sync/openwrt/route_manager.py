"""route_manager manages wan based routing decisions"""
# pylint: disable=unused-argument
# pylint: disable=no-self-use
# pylint: disable=too-many-statements
# pylint: disable=line-too-long
import os
import stat
from sync import registrar
from sync import nftables_util

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
    ifup_wan_balancer_filename = "/etc/config/ifup.d/20-wan-balancer"
    ifdown_wan_balancer_filename = "/etc/config/ifdown.d/20-wan-balancer"
    wan_balancer_file = None
    wan_routing_filename = "/etc/config/nftables-rules.d/102-wan-routing"
    wan_routing_file = None

    def initialize(self):
        """initialize this module"""
        registrar.register_file(self.ifup_routes_filename, "restart-default-route", self)
        registrar.register_file(self.ifdown_routes_filename, "restart-default-route", self)
        registrar.register_file(self.ifup_wan_balancer_filename, "restart-wan-balancer", self)
        registrar.register_file(self.ifdown_wan_balancer_filename, "restart-wan-balancer", self)
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
        user_chain = {}
        user_chain['name'] = "user-wan-rules"
        user_chain['description'] = "User defined wan routing rules"
        user_chain['default'] = True
        user_chain['rules'] = [{
            "enabled": True,
            "description": "Send traffic to default wan",
            "ruleId": 1,
            "conditions": [],
            "action": {
                "type": "WAN_POLICY",
                "policy": "DEFAULT"
            }
        }]
        settings['wan'] = {}
        settings['wan']['user_chain'] = user_chain

    def sync_settings(self, settings, prefix, delete_list):
        """syncs settings"""
        print("%s: Syncing settings" % self.__class__.__name__)
        self.write_rt_tables_file(settings, prefix)
        self.write_ifup_routes_file(settings, prefix)
        self.write_ifdown_routes_file(settings, prefix)
        self.write_wan_balancer_file(self.ifup_wan_balancer_filename, settings, prefix)
        self.write_wan_balancer_file(self.ifdown_wan_balancer_filename, settings, prefix)
        self.write_wan_routing_file(settings, prefix)

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
        file.write("nft add chain inet wan-routing wan-routing-exit\n")
        file.write("nft add rule inet wan-routing wan-routing-exit counter\n")
        file.write("nft add rule inet wan-routing wan-routing-exit mark and 0x0000ff00 == 0x0000 counter\n")

        if get_number_of_wans(settings) == 1:
            interfaces = settings.get('network').get('interfaces')
            for intf in interfaces:
                if enabled_wan(intf):
                    file.write("nft add chain inet wan-routing wan-routing-entry\n")

                    file.write("nft add rule inet wan-routing wan-routing-entry ip saddr 127.0.0.1 goto wan-routing-exit\n")
                    file.write("nft add rule inet wan-routing wan-routing-entry ip daddr 127.0.0.1 goto wan-routing-exit\n")
                    file.write("nft add rule inet wan-routing wan-routing-entry ip6 saddr ::1 goto wan-routing-exit\n")
                    file.write("nft add rule inet wan-routing wan-routing-entry ip6 daddr ::1 goto wan-routing-exit\n")
                    file.write("nft add rule inet wan-routing wan-routing-entry mark and 0x0000ff00 != 0 goto wan-routing-exit\n")
                    file.write("nft add rule inet wan-routing wan-routing-entry mark set mark and 0xffff00ff or 0x%x\n" % ((intf.get('interfaceId') << 8) & 0xff00))
                    file.write("nft add rule inet wan-routing wan-routing-entry goto wan-routing-exit\n")
        else:
            interfaces = settings.get('network').get('interfaces')
            for intf in interfaces:
                if enabled_wan(intf):
                    file.write("nft add set inet wan-routing wan-%d-table \"{ type ipv4_addr . ipv4_addr; flags timeout; }\"\n" % intf.get('interfaceId'))
                    file.write("nft add chain inet wan-routing mark-for-wan-%d\n" % intf.get('interfaceId'))
                    file.write("nft add rule inet wan-routing mark-for-wan-%d mark set mark and 0xffff00ff or 0x%x\n" % (intf.get('interfaceId'), ((intf.get('interfaceId') << 8) & 0xff00)))

                    file.write("nft add chain inet wan-routing route-to-wan-%d\n" % intf.get('interfaceId'))
                    file.write("nft add rule inet wan-routing route-to-wan-%d jump mark-for-wan-%d\n" % (intf.get('interfaceId'), intf.get('interfaceId')))
                    file.write("nft add rule inet wan-routing route-to-wan-%d mark and 0x0000ff00 == 0 return\n" % intf.get('interfaceId'))
                    file.write("nft add rule inet wan-routing route-to-wan-%d set update ip saddr . ip daddr timeout 1m @wan-%d-table\n" % (intf.get('interfaceId'), intf.get('interfaceId')))
                    file.write("nft add rule inet wan-routing route-to-wan-%d set update ip daddr . ip saddr timeout 1m @wan-%d-table\n" % (intf.get('interfaceId'), intf.get('interfaceId')))
                    file.write("nft add rule inet wan-routing route-to-wan-%d goto wan-routing-exit\n" % intf.get('interfaceId'))
                    file.write("\n")

            file.write("nft add chain inet wan-routing route-to-wan-balancer\n")


            total_weight = 0
            balance_string = ""
            for intf in interfaces:
                if enabled_wan(intf):
                    # FIXME - we should remove wanWeight from interface settings
                    # it should depend on the wan policy, which could have different weights for different purposes
                    weight = intf.get('wanWeight')
                    if weight is None:
                        weight = 50
                    file.write("nft add rule inet wan-routing route-to-wan-balancer ip saddr . ip daddr @wan-%d-table jump route-to-wan-%d\n" % (intf.get('interfaceId'), intf.get('interfaceId')))

                    if total_weight > 0:
                        balance_string = balance_string + ", "
                    balance_string = balance_string + "%d-%d : jump route-to-wan-%d" % (total_weight, weight + total_weight - 1, intf.get('interfaceId'))
                    total_weight += weight

            file.write("nft add inet wan-routing route-to-wan-balancer numgen random mod %d vmap { %s }\n" % (total_weight, balance_string))

            for intf in interfaces:
                if enabled_wan(intf):
                    file.write("nft add chain inet wan-routing route-to-default-wan\n")
                    file.write("nft add rule inet wan-routing route-to-default-wan jump mark-for-wan-%d\n" % intf.get('interfaceId'))

                    file.write("nft add chain inet wan-routing route-to-low-jitter\n")
                    file.write("nft add rule inet wan-routing route-to-low-jitter jump mark-for-wan-%d\n" % intf.get('interfaceId'))
                    file.write("nft add rule inet wan-routing route-to-low-jitter mark and 0x0000ff00 == 0 return\n")
                    file.write("nft add rule inet wan-routing route-to-low-jitter goto wan-routing-exit\n")

                    file.write("nft add chain inet wan-routing route-to-low-latency\n")
                    file.write("nft add rule inet wan-routing route-to-low-latency jump mark-for-wan-%d\n" % intf.get('interfaceId'))
                    file.write("nft add rule inet wan-routing route-to-low-latency mark and 0x0000ff00 == 0 return\n")
                    file.write("nft add rule inet wan-routing route-to-low-latency goto wan-routing-exit\n")

                    file.write("nft add chain inet wan-routing route-to-high-bandwidth\n")
                    file.write("nft add rule inet wan-routing route-to-high-bandwidth jump mark-for-wan-%d\n" % intf.get('interfaceId'))
                    file.write("nft add rule inet wan-routing route-to-high-bandwidth mark and 0x0000ff00 == 0 return\n")
                    file.write("nft add rule inet wan-routing route-to-high-bandwidth goto wan-routing-exit\n")
                    break

            file.write("nft add chain inet wan-routing wan-policy-routing\n")
            file.write("nft add rule inet wan-routing wan-policy-routing dict session ct id wan_policy long_string low_jitter jump route-to-low-jitter\n")
            file.write("nft add rule inet wan-routing wan-policy-routing dict session ct id wan_policy long_string low_latency jump route-to-low-latency\n")
            file.write("nft add rule inet wan-routing wan-policy-routing dict session ct id wan_policy long_string high_bandwidth jump route-to-high-bandwidth\n")
            file.write("nft add rule inet wan-routing wan-policy-routing dict session ct id wan_policy long_string balance jump route-to-wan-balancer\n")
            file.write("nft add rule inet wan-routing wan-policy-routing dict session ct id wan_policy long_string default jump route-to-default-wan\n")

            file.write("nft add chain inet wan-routing wan-policy-routing-enabled\n")
            file.write("nft add rule inet wan-routing wan-policy-routing-enabled jump wan-policy-routing comment \\\"wan policy routing enabled\\\"\n")

            wan = settings['wan']
            file.write(nftables_util.chain_create_cmd(wan.get('user_chain'), "inet", "wan-routing") + "\n")
            file.write(nftables_util.chain_rules_cmds(wan.get('user_chain'), "inet", "wan-routing") + "\n")

            file.write("nft add chain inet wan-routing wan-routing-entry\n")
            file.write("nft add rule inet wan-routing wan-routing-entry ip saddr 127.0.0.1 goto wan-routing-exit\n")
            file.write("nft add rule inet wan-routing wan-routing-entry ip daddr 127.0.0.1 goto wan-routing-exit\n")
            file.write("nft add rule inet wan-routing wan-routing-entry ip6 saddr ::1 goto wan-routing-exit\n")
            file.write("nft add rule inet wan-routing wan-routing-entry ip6 daddr ::1 goto wan-routing-exit\n")
            file.write("nft add rule inet wan-routing wan-routing-entry mark and 0x0000ff00 != 0 goto wan-routing-exit\n")
            file.write("nft add rule inet wan-routing wan-routing-entry jump user-wan-rules\n")
            file.write("nft add rule inet wan-routing wan-routing-entry mark and 0x0000ff00 != 0 goto wan-routing-exit\n")
            file.write("nft add rule inet wan-routing wan-routing-entry jump wan-policy-routing-enabled\n")
            file.write("nft add rule inet wan-routing wan-routing-entry jump route-to-default-wan\n")
            file.write("nft add rule inet wan-routing wan-routing-entry goto wan-routing-exit\n")

        file.write("nft add chain inet wan-routing wan-routing-prerouting \"{ type filter hook prerouting priority -25 ; }\"\n")
        file.write("nft add rule inet wan-routing wan-routing-prerouting jump wan-routing-entry\n")

        file.write("nft add chain inet wan-routing wan-routing-output \"{ type filter hook output priority -135 ; }\"\n")
        file.write("nft add rule inet wan-routing wan-routing-output jump wan-routing-entry\n")
        file.write("\n")

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
        file.write("#\n")
        file.write("# special tables\n")
        file.write("#\n")
        file.write("500\tbalance\n")

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
                    file.write("[ %s4 = \"$INTERFACE\" ] && {\n" % intf.get('name'))
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
                    file.write("\tnetwork_is_up %s4 && {\n" % intf.get('name'))
                    file.write("\t\techo add rule inet wan-routing route-to-default-wan jump mark-for-wan-%d >> $TMPFILE\n" % intf.get('interfaceId'))
                    file.write("\t\twrite_rules\n")
                    file.write("\t}\n\n")

            file.write("}\n\n")

            for intf in interfaces:
                if enabled_wan(intf):
                    file.write("[ %s4 = \"$INTERFACE\" ] && {\n" % intf.get('name'))
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

    def write_wan_balancer_file(self, fname, settings, prefix=""):
        """write_wan_balancer_file writes /etc/config/if[up|down].d/20-wan-balancer"""
        filename = prefix + fname
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        self.wan_balancer_file = open(filename, "w+")
        file = self.wan_balancer_file
        file.write("#!/bin/sh")
        file.write("\n\n")
        file.write("## Auto Generated\n")
        file.write("## DO NOT EDIT. Changes will be overwritten.\n")
        file.write("\n")
        file.write(". /lib/functions/network.sh\n")
        file.write("\n")
        file.write("INTERFACE=$1\n")
        file.write("\n")

        if get_number_of_wans(settings) == 1:
            file.write("\n# Only one wan, do nothing\n\n")
        else:
            file.write("build_balance_table()\n")
            file.write("{\n")
            file.write("\tBALANCE_STRING=\"\"\n")
            file.write("\tTOTAL_WEIGHT=0\n")
            file.write("\tTMPFILE=`mktemp -t wan-balancer.XXXXXX`\n")
            file.write("\n")
            file.write("\techo flush chain inet wan-routing route-to-wan-balancer >> $TMPFILE\n")
            file.write("\n")

            interfaces = settings.get('network').get('interfaces')
            for intf in interfaces:
                if enabled_wan(intf):
                    # FIXME - we should remove wanWeight from interface settings
                    # it should depend on the wan policy, which could have different weights for different purposes
                    weight = intf.get('wanWeight')
                    if weight is None:
                        weight = 50
                    file.write("\techo flush chain inet wan-routing mark-for-wan-%d >> $TMPFILE\n" % intf.get('interfaceId'))
                    file.write("\techo flush set inet wan-routing wan-%d-table >> $TMPFILE\n" % intf.get('interfaceId'))
                    file.write("\tif network_is_up \"%s4\" ; then\n" % intf.get('name'))
                    file.write("\t\techo add rule inet wan-routing mark-for-wan-%d mark set mark and 0xffff00ff or 0x%x >> $TMPFILE\n" % (intf.get('interfaceId'), (intf.get('interfaceId') << 8) & 0xff00))
                    file.write("\t\techo add rule inet wan-routing route-to-wan-balancer ip saddr . ip daddr @wan-%d-table jump route-to-wan-%d >> $TMPFILE\n" % (intf.get('interfaceId'), intf.get('interfaceId')))
                    file.write("\t\tif [ $TOTAL_WEIGHT -ne 0 ] ; then\n")
                    file.write("\t\t\tBALANCE_STRING=\"$BALANCE_STRING,\"\n")
                    file.write("\t\tfi\n")
                    file.write("\t\tBALANCE_STRING=\"$BALANCE_STRING $TOTAL_WEIGHT-$((TOTAL_WEIGHT+%d-1)) : jump route-to-wan-%d\"\n" % (weight, intf.get('interfaceId')))
                    file.write("\t\tTOTAL_WEIGHT=$((TOTAL_WEIGHT+%d))\n" % weight)
                    file.write("\telse\n")
                    file.write("\t\techo add rule inet wan-routing mark-for-wan-%d return comment \\\"wan %d is down\\\" >> $TMPFILE\n" % (intf.get('interfaceId'), intf.get('interfaceId')))
                    file.write("\tfi\n")
                    file.write("\n")

            file.write("\techo add rule inet wan-routing route-to-wan-balancer numgen random mod $TOTAL_WEIGHT vmap { $BALANCE_STRING } >> $TMPFILE\n")

            file.write("\tnft -f $TMPFILE\n")
            file.write("\trm $TMPFILE\n")
            file.write("}\n\n")

            for intf in interfaces:
                if intf.get('wan'):
                    file.write("[ %s4 = \"$INTERFACE\" ] && {\n" % intf.get('name'))
                    file.write("\tbuild_balance_table\n")
                    file.write("}\n")
                    file.write("\n")

            file.write("[ -z \"$INTERFACE\" ] && {\n")
            file.write("\tbuild_balance_table\n")
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

registrar.register_manager(RouteManager())
