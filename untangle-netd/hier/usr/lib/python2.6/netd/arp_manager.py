import os
import sys
import subprocess
import datetime
import traceback

# This class is responsible for writing /etc/untangle-netd/post-network-hook.d/025-arp
# based on the settings object passed from sync-settings.py
class ArpManager:
    filename = "/etc/untangle-netd/post-network-hook.d/025-arp"

    def write_arp( self, settings, prefix, verbosity ):

        filename = prefix + self.filename
        fileDir = os.path.dirname( filename )
        if not os.path.exists( fileDir ):
            os.makedirs( fileDir )

        file = open( filename, "w+" )
        file.write("#!/bin/dash");
        file.write("\n\n");

        file.write("## Auto Generated on %s\n" % datetime.datetime.now());
        file.write("## DO NOT EDIT. Changes will be overwritten.\n");
        file.write("\n\n");
        
        # FIXME: get IP from interface instead of settings (so DHCP is supported)
        # FIXME: add support for aliases
        file.write("# For gateways to update MAC table" + "\n");
        file.write("# This is necessary for malfunctioning ISP routers that have permanent ARP caches" + "\n");
        file.write("\n");
        for intf in settings['interfaces']['list']:
            if 'v4StaticGateway' in intf:
                if 'v4StaticAddress' in intf:
                    file.write("arping -U -c 1 -I %s -s %s %s >/dev/null &\n" % (intf['systemDev'], intf['v4StaticAddress'], intf['v4StaticGateway']) );
        file.write("\n\n");

        file.flush()
        file.close()

        os.system("chmod a+x %s" % filename)
        if verbosity > 0: print "ArpManager: Wrote %s" % filename

        return


    def sync_settings( self, settings, prefix="", verbosity=0 ):

        if verbosity > 1: print "ArpManager: sync_settings()"
        
        self.write_arp( settings, prefix, verbosity )


        return
