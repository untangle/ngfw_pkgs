import os
import stat
import sys
import subprocess
import datetime
import traceback
import re
import ipaddress
from sync import registrar

# This class is responsible for writing /etc/iproute2/rt_tables and /etc/hotplug.d/iface/*
# based on the settings object passed from sync-settings
class RouteManager:
    rt_tables_filename = "/etc/iproute2/rt_tables"
    ifup_routes_filename = "/etc/config/ifup.d/10-default-route"
    ifdown_routes_filename = "/etc/config/ifdown.d/10-default-route"
    ifup_wan_balancer_filename = "/etc/config/ifup.d/20-wan-balancer"
    ifdown_wan_balancer_filename = "/etc/config/ifdown.d/20-wan-balancer"
    IP_RULE_DEFAULT_RULE_PRIORITY="1000000"
    IP_RULE_BALANCE_RULE_PRIORITY="900000"
    def initialize( self ):
        registrar.register_file(self.ifup_routes_filename, "restart-default-route", self)
        registrar.register_file(self.ifdown_routes_filename, "restart-default-route", self)
        registrar.register_file(self.ifup_wan_balancer_filename, "restart-wan-balancer", self)
        registrar.register_file(self.ifdown_wan_balancer_filename, "restart-wan-balancer", self)
        registrar.register_file(self.rt_tables_filename, "restart-networking", self)

    def create_settings( self, settings, prefix, delete_list, filename, verbosity=0 ):
        print("%s: Initializing settings" % self.__class__.__name__)

    def sync_settings( self, settings, prefix, delete_list, verbosity=0 ):
        print("%s: Syncing settings" % self.__class__.__name__)
        self.write_rt_tables_file(settings, prefix, verbosity)
        self.write_ifup_routes_file(settings, prefix, verbosity)
        self.write_ifdown_routes_file(settings, prefix, verbosity)
        self.write_wan_balancer_file(self.ifup_wan_balancer_filename, settings, prefix, verbosity)
        self.write_wan_balancer_file(self.ifdown_wan_balancer_filename, settings, prefix, verbosity)

    def write_rt_tables_file(self, settings, prefix="", verbosity=0):
        filename = prefix + self.rt_tables_filename
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        self.rt_tables_file = open(filename, "w+")
        file = self.rt_tables_file

        file.write("## Auto Generated\n");
        file.write("## DO NOT EDIT. Changes will be overwritten.\n");
        file.write("\n\n");

        file.write("#\n");
        file.write("# reserved values\n");
        file.write("#\n");
        file.write("128\tprelocal\n");
        file.write("255\tlocal\n");
        file.write("254\tmain\n");
        file.write("253\tdefault\n");
        file.write("0\tunspec\n");
        file.write("#\n");
        file.write("# local\n");
        file.write("#\n");
        file.write("#1\tinr.ruhep\n");
        file.write("\n\n");
        file.write("#\n");
        file.write("# WAN tables\n");
        file.write("#\n");

        interfaces = settings.get('network').get('interfaces')
        for intf in interfaces:
            if intf.get('configType') == 'DISABLED':
                continue
            if intf.get('wan'):
                interface_id = intf.get('interfaceId')
                file.write("%d\twan.%d\n" % (interface_id, interface_id));

        file.write("\n\n");
        file.write("#\n");
        file.write("# special tables\n");
        file.write("#\n");
        file.write("500\tbalance\n");

        file.flush()
        file.close()

        if verbosity > 0:
            print("%s: Wrote %s" % (self.__class__.__name__,filename))

    def write_ifup_routes_file(self, settings, prefix="", verbosity=0):
        filename = prefix + self.ifup_routes_filename
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        self.ifup_route_file = open(filename, "w+")
        file = self.ifup_route_file
        file.write("#!/bin/sh");
        file.write("\n\n");
        file.write("## Auto Generated\n")
        file.write("## DO NOT EDIT. Changes will be overwritten.\n")
        file.write("\n")
        file.write(". /lib/functions/network.sh\n")
        file.write("\n")
        file.write("INTERFACE=$1\n")
        file.write("DEVICE=$2\n")
        file.write("\n")

        interfaces = settings.get('network').get('interfaces')
        for intf in interfaces:
            if intf.get('configType') == 'DISABLED':
                continue
            if intf.get('wan'):
                file.write("[ %s4 = \"$INTERFACE\" ] && {\n" % intf.get('name'))
                file.write("\tip rule show | grep -q %s || {\n" % self.IP_RULE_DEFAULT_RULE_PRIORITY)
                file.write("\t\tip rule add priority %s lookup wan.%d\n" % (self.IP_RULE_DEFAULT_RULE_PRIORITY, intf.get('interfaceId')))
                file.write("\t}\n")
                file.write("\texit 0\n")
                file.write("}\n")
                file.write("\n")

        file.flush()
        file.close()
        os.chmod(filename, os.stat(filename).st_mode | stat.S_IEXEC)

        if verbosity > 0:
            print("%s: Wrote %s" % (self.__class__.__name__,filename))

    def write_ifdown_routes_file(self, settings, prefix="", verbosity=0):
        filename = prefix + self.ifdown_routes_filename
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        self.ifdown_route_file = open(filename, "w+")
        file = self.ifdown_route_file
        file.write("#!/bin/sh");
        file.write("\n\n");
        file.write("## Auto Generated\n")
        file.write("## DO NOT EDIT. Changes will be overwritten.\n")
        file.write("\n")
        file.write(". /lib/functions/network.sh\n")
        file.write("\n")
        file.write("INTERFACE=$1\n")
        file.write("\n")

        interfaces = settings.get('network').get('interfaces')
        for intf in interfaces:
            if intf.get('configType') == 'DISABLED':
                continue
            if intf.get('wan'):
                file.write("[ %s4 = \"$INTERFACE\" ] && {\n" % intf.get('name'))
                file.write("\tip rule show | grep -q %s | grep -q wan.%d || {\n" % (self.IP_RULE_DEFAULT_RULE_PRIORITY, intf.get('interfaceId')))
                file.write("\t\tip rule del priority %s\n" % self.IP_RULE_DEFAULT_RULE_PRIORITY)
                file.write("\t}\n")
                file.write("}\n")
                file.write("\n")

        file.write("[ -z \"$INTERFACE\" ] && {\n")
        file.write("\tip rule del priority %s\n" % self.IP_RULE_DEFAULT_RULE_PRIORITY)
        file.write("}\n")
        file.write("\n")

        file.write("ip rule show | grep -q %s || {\n" % self.IP_RULE_DEFAULT_RULE_PRIORITY)
        for intf in interfaces:
            if intf.get('configType') == 'DISABLED':
                continue
            if intf.get('wan'):
                file.write("\tnetwork_is_up %s4 && {\n" % intf.get('name'))
                file.write("\t\tip rule add priority %s lookup wan.%d\n" % (self.IP_RULE_DEFAULT_RULE_PRIORITY, intf.get('interfaceId')))
                file.write("\t\texit 0\n")
                file.write("\t}\n")
                file.write("\n")

        file.write("}\n")

        file.flush()
        file.close()
        os.chmod(filename, os.stat(filename).st_mode | stat.S_IEXEC)

        if verbosity > 0:
            print("%s: Wrote %s" % (self.__class__.__name__,filename))

    def write_wan_balancer_file(self, fname, settings, prefix="", verbosity=0):
        filename = prefix + fname
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        self.wan_balancer_file = open(filename, "w+")
        file = self.wan_balancer_file
        file.write("#!/bin/sh");
        file.write("\n\n");
        file.write("## Auto Generated\n")
        file.write("## DO NOT EDIT. Changes will be overwritten.\n")
        file.write("\n")
        file.write(". /lib/functions/network.sh\n")
        file.write("\n")
        file.write("build_balance_table()\n")
        file.write("{\n")
        file.write("\tROUTE_STR=\"\"\n")
        file.write("\n")

        interfaces = settings.get('network').get('interfaces')
        for intf in interfaces:
            if intf.get('configType') == 'DISABLED':
                continue
            if intf.get('wan'):
                file.write("\tnetwork_is_up %s4 && {\n" % intf.get('name'))
                file.write("\t\tROUTE_STR=\"$ROUTE_STR `ip route show table wan.%d | cut -f 1-5 -d ' ' | grep default | sed -e 's/default/nexthop/'` weight %d\"\n" % (intf.get('interfaceId'), intf.get('wanWeight')))
                file.write("\t}\n")
                file.write("\n")

        file.write("\t[ -z \"$ROUTE_STR\" ] && {\n")
        file.write("\t\tip rule del priority %s\n" % self.IP_RULE_BALANCE_RULE_PRIORITY)
        file.write("\t\texit 0\n")
        file.write("\t}\n")
        file.write("\n")

        file.write("\tip route replace table balance default scope global $ROUTE_STR\n")
        file.write("\tip rule del priority %s\n" % self.IP_RULE_BALANCE_RULE_PRIORITY)
        file.write("\tip rule add priority %s lookup balance\n" % self.IP_RULE_BALANCE_RULE_PRIORITY)
        file.write("}\n")
        file.write("\n")

        for intf in interfaces:
            if intf.get('wan'):
                file.write("[ %s4 = \"$INTERFACE\" ] && {\n" % intf.get('name'))
                file.write("\tbuild_balance_table\n")
                file.write("}\n")
                file.write("\n")


        file.write("[ -z \"$INTERFACE\" ] && {\n")
        file.write("\tbuild_balance_table\n")
        file.write("}\n")
        file.write("\n")

        file.flush()
        file.close()
        os.chmod(filename, os.stat(filename).st_mode | stat.S_IEXEC)

        if verbosity > 0:
            print("%s: Wrote %s" % (self.__class__.__name__,filename))

registrar.register_manager(RouteManager())
