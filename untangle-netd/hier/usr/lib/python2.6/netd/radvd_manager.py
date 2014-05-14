import os
import sys
import subprocess
import datetime
import traceback
import re
from netd.network_util import NetworkUtil

# This class is responsible for writing:
# /etc/radvd.conf
# based on the settings object passed from sync-settings.py
class RadvdManager:
    configFilename = "/etc/radvd.conf"
    restartHookFilename = "/etc/untangle-netd/post-network-hook.d/990-restart-radvd"

    def write_config_file( self, settings, prefix="", verbosity=0 ):

        filename = prefix + self.configFilename
        fileDir = os.path.dirname( filename )
        if not os.path.exists( fileDir ):
            os.makedirs( fileDir )

        file = open( filename, "w+" )

        for intf in settings.get('interfaces').get('list'):
            if not intf.get('raEnabled'):
                continue
            if intf.get('configType') != "ADDRESSED":
                continue
            if intf.get('v6ConfigType') != "STATIC":
                continue
            if intf.get('v6StaticAddress') == None or intf.get('v6StaticPrefixLength') == None:
                continue

            file.write("interface %s {" % intf.get('systemDev') + "\n")
            file.write("    IgnoreIfMissing on;" + "\n")
            file.write("    AdvSendAdvert on;" + "\n")
            file.write("    MinRtrAdvInterval 3;" + "\n")
            file.write("    MaxRtrAdvInterval 10;" + "\n")
            file.write("    prefix %s/%s {" % (intf.get('v6StaticAddress'), intf.get('v6StaticPrefixLength')) + "\n")
            file.write("        AdvOnLink on;" + "\n")
            file.write("        AdvAutonomous on;" + "\n")
            file.write("        AdvRouterAddr on;" + "\n")
            file.write("    };" + "\n")
            file.write("};" + "\n")
            
        file.flush()
        file.close()

        if verbosity > 0: print "RadvdManager: Wrote %s" % filename

    def write_restart_radvd_hook( self, settings, prefix="", verbosity=0 ):

        filename = prefix + self.restartHookFilename
        fileDir = os.path.dirname( filename )
        if not os.path.exists( fileDir ):
            os.makedirs( fileDir )

        file = open( filename, "w+" )
        file.write("#!/bin/dash");
        file.write("\n\n");

        file.write("## Auto Generated on %s\n" % datetime.datetime.now());
        file.write("## DO NOT EDIT. Changes will be overwritten.\n");
        file.write("\n");

        file.write(r"""
RADVD_PID="`pidof radvd`"

# Start radvd if it isnt found and is needed (config file is non-zero)
# Restart radvd if it is found and but is outdated and is needed (config file is non-zero)
# Stop if radvd is found, but no longer needed (config file is zero size)
# The reason we don't just stop and then start if needed if to avoid doing anything if nothing is required.
if [ -z "$RADVD_PID" ] && [ -s /etc/radvd.conf ] ; then
    /etc/init.d/radvd start
elif [ /etc/radvd.conf -nt /proc/$RADVD_PID ] && [ -s /etc/radvd.conf ] ; then
    /etc/init.d/radvd restart
elif [ ! -z "$RADVD_PID" ] && [ ! -s /etc/radvd.conf ] ; then
    /etc/init.d/radvd stop
fi
""")

        file.write("\n");
        file.flush()
        file.close()
    
        os.system("chmod a+x %s" % filename)
        if verbosity > 0: print "RadvdManager: Wrote %s" % filename
        return

    def sync_settings( self, settings, prefix="", verbosity=0 ):

        if verbosity > 1: print "RadvdManager: sync_settings()"
        
        self.write_config_file( settings, prefix, verbosity )
        self.write_restart_radvd_hook( settings, prefix, verbosity )

        return
