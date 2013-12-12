import os
import sys
import subprocess
import datetime
import traceback
import re
from netd.network_util import NetworkUtil

# This class is responsible for writing:
# /etc/untangle-netd/post-network-hook.d/200-vrrp
# based on the settings object passed from sync-settings.py
class VrrpManager:
    postNetworkHookFilename = "/etc/untangle-netd/post-network-hook.d/200-vrrp"

    def write_post_network_hook( self, settings, prefix="", verbosity=0 ):

        filename = prefix + self.postNetworkHookFilename
        fileDir = os.path.dirname( filename )
        if not os.path.exists( fileDir ):
            os.makedirs( fileDir )

        file = open( filename, "w+" )
        file.write("#!/bin/dash");
        file.write("\n\n");

        file.write("## Auto Generated on %s\n" % datetime.datetime.now());
        file.write("## DO NOT EDIT. Changes will be overwritten.\n");
        file.write("\n\n");

        file.write(r"""
if [ ! -z "`pidof vrrpd`" ] ; then
    killall vrrpd
fi
""")
        file.write("\n\n");

        for interface_settings in settings['interfaces']['list']:
            if interface_settings.get('vrrpEnabled'):
                if not interface_settings.get('vrrpId') or not interface_settings.get('vrrpPriority') or not interface_settings.get('vrrpAddress'):
                    print "Missing VRRP Config: %s, %s, %s" % (str(vrrpId), str(vrrpPriority), str(vrrpAddress))
                    continue
                file.write("# Interface %s VRRP" % str(interface_settings.get('interfaceId')) + "\n")
                file.write("vrrpd -i %s -v %s -D -p %s %s" % ( str(interface_settings.get('systemDev')), str(interface_settings.get('vrrpId')), str(interface_settings.get('vrrpPriority')), str(interface_settings.get('vrrpAddress'))) + "\n")
                file.write("\n\n");
        
        file.flush()
        file.close()

        os.system("chmod a+x %s" % filename)
        if verbosity > 0: print "VrrpManager: Wrote %s" % filename

        return

    def sync_settings( self, settings, prefix="", verbosity=0 ):

        if verbosity > 1: print "VrrpManager: sync_settings()"
        
        self.write_post_network_hook( settings, prefix, verbosity )

        return

