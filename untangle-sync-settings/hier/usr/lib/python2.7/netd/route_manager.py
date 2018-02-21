import os
import sys
import subprocess
import datetime
import traceback
import re
from netd.network_util import NetworkUtil

# This class is responsible for writing /etc/untangle-netd/post-network-hook.d/030-routes
# and others based on the settings object passed from sync-settings.py
class RouteManager:
    rtTableFilename = "/etc/iproute2/rt_tables"
    routesFilename = "/etc/untangle-netd/post-network-hook.d/030-routes"
    preRoutesFilename = "/etc/untangle-netd/pre-network-hook.d/030-routes"

    IP_RULE_PRIORITY="70"
    IP_RULE_DEFAULT_RULE_PRIORITY="1000000"
    DST_INTERFACE_SHIFT=8
    DST_INTERFACE_MASK=0xFF00

    def string_is_int( self, s ):
        try:
            int(s)
            return True
        except ValueError:
            return False

    def write_rt_table( self, settings, prefix, verbosity ):

        filename = prefix + self.rtTableFilename
        fileDir = os.path.dirname( filename )
        if not os.path.exists( fileDir ):
            os.makedirs( fileDir )

        file = open( filename, "w+" )
        file.write("## Auto Generated\n");
        file.write("## DO NOT EDIT. Changes will be overwritten.\n");
        file.write("\n\n");

        file.write("#" + "\n");
        file.write("# reserved values" + "\n");
        file.write("#" + "\n");
        file.write("255\tlocal" + "\n");
        file.write("254\tmain" + "\n");
        file.write("253\tdefault" + "\n");
        file.write("0\tunspec" + "\n");
        file.write("\n\n");

        file.write("#" + "\n");
        file.write("# local" + "\n");
        file.write("#" + "\n");
        file.write("#1\tinr.ruhep" + "\n");
        file.write("\n\n");

        file.write("# WAN tables " + "\n");
        for intf in settings['interfaces']['list']:
            if 'isWan' in intf and intf['isWan']:
                file.write("%i\tuplink.%i" % ( int(intf['interfaceId']), int(intf['interfaceId']) ) + "\n")
        for intf in settings['virtualInterfaces']['list']:
            if 'isWan' in intf and intf['isWan']:
                file.write("%i\tuplink.%i" % ( int(intf['interfaceId']), int(intf['interfaceId']) ) + "\n")
        file.write("\n\n");

        file.write("# special tables " + "\n");
        file.write("500\tbalance" + "\n")
        file.write("\n\n");
            
        file.flush()
        file.close()

        if verbosity > 0: print "RouteManager: Wrote %s" % filename
        return

    def write_routes( self, settings, prefix, verbosity ):

        filename = prefix + self.routesFilename
        fileDir = os.path.dirname( filename )
        if not os.path.exists( fileDir ):
            os.makedirs( fileDir )

        file = open( filename, "w+" )
        file.write("#!/bin/dash");
        file.write("\n\n");

        file.write("## Auto Generated\n");
        file.write("## DO NOT EDIT. Changes will be overwritten.\n");
        file.write("\n\n");

        file.write("expected_ip_route_rules()" + "\n")
        file.write("{" + "\n")
        for intfId in NetworkUtil.wan_list():
            file.write("    printf \"%s%03d:\\tfrom all fwmark %#x/%#x lookup uplink.%d \\n\"\n" % (self.IP_RULE_PRIORITY, intfId, intfId << self.DST_INTERFACE_SHIFT, self.DST_INTERFACE_MASK, intfId))
        file.write("}" + "\n")
        file.write("\n\n");

        file.write(r"""
current_ip_route_rules()
{
    ip rule show | awk "/^%s[0-9][0-9][0-9]:/ { print }" 
}
""" % self.IP_RULE_PRIORITY)
        file.write("\n\n");
        
        file.write(r"""
flush_ip_route_rules()
{
    local t_priority
    for t_priority in `ip rule show | awk "/^%s[0-9][0-9][0-9]:/ { sub( \":\", \"\", \\$1 ) ; print \\$1 }"`; do
        ip rule del priority ${t_priority}
    done
}
""" % self.IP_RULE_PRIORITY);
        file.write("\n\n");

        file.write("insert_ip_route_rules()" + "\n")
        file.write("{" + "\n")
        for intfId in NetworkUtil.wan_list():
            file.write("    ip rule add priority %s%03d fwmark %#x/%#x lookup uplink.%i\n" % ( self.IP_RULE_PRIORITY, intfId, intfId << self.DST_INTERFACE_SHIFT, self.DST_INTERFACE_MASK, intfId))
        file.write("}" + "\n")

        file.write(r"""
if [ "`expected_ip_route_rules | md5sum`" != "`current_ip_route_rules  | md5sum`" ]; then
    echo "Flushing  ip route rules..."
    flush_ip_route_rules
    echo "Inserting ip route rules..."
    insert_ip_route_rules
fi

""")
        # Write the static routes from settings
        if settings == None or 'staticRoutes' not in settings or 'list' not in settings['staticRoutes']:
            print "ERROR: Missing Static Routes"
        else:
            static_routes = settings['staticRoutes']['list'];
            for static_route in static_routes:
                for key in ['ruleId','nextHop','network','prefix']:
                    if key not in static_route:
                        print "ERROR: ignoring bad route missing key: %s\n" % key
                        continue
                    
                if self.string_is_int(static_route['nextHop']):
                    # if nextHop is an interfaceId
                    interfaceId = int(static_route['nextHop'])
                    for intf in settings['interfaces']['list']:
                        if intf.get('interfaceId') == interfaceId:
                            # device route since nextHop includes alphas
                            file.write("# Static Route %i\n" % static_route['ruleId'])
                            file.write("ip route add %s/%s dev %s\n" % ( static_route['network'], static_route['prefix'], intf.get('symbolicDev') ) )
                            file.write("if [ $? != 0 ] ; then echo \"ERROR: inserting route %i\" ; fi \n" % static_route['ruleId'])
                            file.write("\n")
                else:
                    # otherwise gateway route
                    file.write("# Static Route %i\n" % static_route['ruleId'])
                    file.write("ip route add %s/%s via %s\n" % ( static_route['network'], static_route['prefix'], static_route['nextHop'] ) )
                    file.write("if [ $? != 0 ] ; then echo \"ERROR: inserting route %i\" ; fi \n" % static_route['ruleId'])
                    file.write("\n")


        file.flush()
        file.close()

        os.system("chmod a+x %s" % filename)
        if verbosity > 0: print "RouteManager: Wrote %s" % filename

        return

    def write_routes_pre_hook( self, settings, prefix, verbosity ):

        filename = prefix + self.preRoutesFilename
        fileDir = os.path.dirname( filename )
        if not os.path.exists( fileDir ):
            os.makedirs( fileDir )

        file = open( filename, "w+" )
        file.write("#!/bin/dash");
        file.write("\n\n");

        file.write("## Auto Generated\n");
        file.write("## DO NOT EDIT. Changes will be overwritten.\n");
        file.write("\n\n");

        file.write("# Delete the default route, we do this because this might no longer be the default\n")
        file.write("ip rule del priority %s 2>/dev/null\n" % self.IP_RULE_DEFAULT_RULE_PRIORITY)
        file.write("\n");

        file.write("# Delete the main table, we do this because some routes may have been removed\n")
        file.write("# All routes will be recreated later\n")
        file.write("ip route flush table main \n")
        file.write("\n");

        file.write("# Delete the old routing priorities\n")
        file.write("ip rule ls | grep -E '^36[5-6][0-9]{3}:' | awk -F: '{print $1}' | while read i ; do ip rule delete priority $i ; done\n")
        file.write("\n");

        file.write("# Delete source route rules\n")
        file.write("""ip -4 rule show | awk -v min_priority=50000 -v max_priority=59999 '{ sub( ":", "" ) ; if (( $1 >= min_priority ) && ( $1 < max_priority ) ) print $1 }' | while read prio ; do ip rule delete priority $prio ; done""" + "\n")
        file.write("\n");

        file.flush()
        file.close()

        os.system("chmod a+x %s" % filename)
        if verbosity > 0: print "RouteManager: Wrote %s" % filename

        return


    def sync_settings( self, settings, prefix="", verbosity=0 ):

        if verbosity > 1: print "RouteManager: sync_settings()"
        
        self.write_rt_table( settings, prefix, verbosity )
        self.write_routes( settings, prefix, verbosity )
        self.write_routes_pre_hook( settings, prefix, verbosity )

        return
