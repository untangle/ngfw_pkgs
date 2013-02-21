import os
import sys
import subprocess
import datetime
import traceback
import re
from netd.network_util import NetworkUtil

# This class is responsible for writing /etc/untangle-netd/pre-network-hook.d/015-ethernet-media
# based on the settings object passed from sync-settings.py
class RouteManager:
    rtTableFilename = "/etc/iproute2/rt_tables"
    routesFilename = "/etc/untangle-netd/post-network-hook.d/30-routes"

    IP_RULE_PRIORITY="366"
    DST_INTERFACE_SHIFT=8
    DST_INTERFACE_MASK=0xFF00

    def write_rt_table( self, settings, prefix, verbosity ):

        filename = prefix + self.rtTableFilename
        fileDir = os.path.dirname( filename )
        if not os.path.exists( fileDir ):
            os.makedirs( fileDir )

        file = open( filename, "w+" )
        file.write("## Auto Generated on %s\n" % datetime.datetime.now());
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

        file.write("## Auto Generated on %s\n" % datetime.datetime.now());
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
    ip rule show | awk "/^%s[0-2][0-9][0-9]:/ { print }" 
}
""" % self.IP_RULE_PRIORITY)
        file.write("\n\n");
        
        file.write(r"""
flush_ip_route_rules()
{
    local t_priority
    for t_priority in `ip rule show | awk "/^%s[0-2][0-9][0-9]:/ { sub( \":\", \"\", \\$1 ) ; print \\$1 }"`; do
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
if [ "`expected_ip_route_rules | md5sum`" = "`current_ip_route_rules  | md5sum`" ]; then
    echo "ip route rules are up to date."
else
    echo "Flushing  ip rules..."
    flush_ip_route_rules
    echo "Inserting ip rules..."
    insert_ip_route_rules
fi

""")

        # Write an implicit route for each gateway
        # This is necessary for dumb ISPs that provide gateways outside the netmask range
        # Some other OSs (windows) do this, so people expect it
        for intf in settings['interfaces']['list']:
            if 'isWan' in intf and intf['isWan']:
                if 'v4StaticGateway' in intf:
                    file.write("# Implicit Gateway Route for Interface %i\n" % intf['interfaceId'])
                    file.write("ip route add %s dev %s\n" % ( intf['v4StaticGateway'], intf['systemDev'] ) )
                    file.write("if [ $? != 0 ] ; then echo \"ERROR: inserting implicity gateway for interface %i\" ; fi \n" % intf['interfaceId'])
                    file.write("\n")

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
                    
                if re.match('[a-z]+', static_route['nextHop']):
                    # device route since nextHop includes alphas
                    file.write("# Static Route %i\n" % static_route['ruleId'])
                    file.write("ip route add %s/%s dev %s\n" % ( static_route['network'], static_route['prefix'], static_route['nextHop'] ) )
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


    def sync_settings( self, settings, prefix="", verbosity=0 ):

        if verbosity > 1: print "RouteManager: sync_settings()"
        
        self.write_rt_table( settings, prefix, verbosity )
        self.write_routes( settings, prefix, verbosity )

        return
