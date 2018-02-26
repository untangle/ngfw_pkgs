import os
import sys
import subprocess
import datetime
import traceback

# This class is responsible for writing /etc/untangle/post-network-hook.d/025-arp
# based on the settings object passed from sync-settings.py
class ArpManager:
    filename = "/etc/untangle/post-network-hook.d/025-arp"

    def write_arp( self, settings, prefix, verbosity ):

        filename = prefix + self.filename
        fileDir = os.path.dirname( filename )
        if not os.path.exists( fileDir ):
            os.makedirs( fileDir )

        file = open( filename, "w+" )
        file.write("#!/bin/dash");
        file.write("\n\n");

        file.write("## Auto Generated\n");
        file.write("## DO NOT EDIT. Changes will be overwritten.\n");
        file.write("\n\n");
        
        file.write("# Force send ARP to the gateways to update MAC table" + "\n");
        file.write("# This is necessary for malfunctioning ISP routers that have permanent ARP caches" + "\n");
        file.write("\n");
        for intf in settings['interfaces']['list']:
            if intf.get('v4ConfigType') == 'STATIC':
                if 'v4StaticGateway' in intf and 'v4StaticAddress' in intf:
                    file.write("# Static IP of interface %i\n" % intf.get('interfaceId'));
                    file.write("arping -U -c 1 -I %s -s %s %s >/dev/null &\n" % (intf.get('systemDev'), intf.get('v4StaticAddress'), intf.get('v4StaticGateway')) );
                    if intf.get('v4Aliases') != None and intf.get('v4Aliases').get('list') != None:
                        for alias in intf.get('v4Aliases').get('list'):
                            file.write("# Alias IPs of interface %i\n" % intf.get('interfaceId'));
                            file.write("arping -U -c 1 -I %s -s %s %s >/dev/null &\n" % (intf.get('systemDev'), alias.get('staticAddress'), intf.get('v4StaticGateway')) );
                        

        file.write("\n\n");

        file.flush()
        file.close()

        os.system("chmod a+x %s" % filename)
        if verbosity > 0: print("ArpManager: Wrote %s" % filename)

        return


    def sync_settings( self, settings, prefix="", verbosity=0 ):

        if verbosity > 1: print("ArpManager: sync_settings()")
        
        self.write_arp( settings, prefix, verbosity )


        return
