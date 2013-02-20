import os
import sys
import subprocess
import datetime
import traceback

# This class is responsible for writing /etc/untangle-netd/pre-network-hook.d/015-ethernet-media
# based on the settings object passed from sync-settings.py
class SysctlManager:
    filename = "/etc/untangle-netd/post-network-hook.d/00-sysctl"

    def write_sysctl( self, settings, prefix, verbosity ):

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

        file.write("# turn on IP forwarding" + "\n");
        file.write("sysctl -q -w net.ipv4.ip_forward=1" + "\n");
        file.write("\n");

        file.write("# turn on ICMP redirects" + "\n");
        file.write("find /proc/sys/net/ipv4/conf -type f -name 'send_redirects' | while read f ; do" + "\n");
        file.write("  echo 1 > ${f}" + "\n");
        file.write("done" + "\n");
        file.write("\n");

        file.flush()
        file.close()

        os.system("chmod a+x %s" % filename)
        if verbosity > 0: print "SysctlManager: Wrote %s" % filename

        return


    def sync_settings( self, settings, prefix="", verbosity=0 ):

        if verbosity > 1: print "SysctlManager: sync_settings()"
        
        self.write_sysctl( settings, prefix, verbosity )


        return
