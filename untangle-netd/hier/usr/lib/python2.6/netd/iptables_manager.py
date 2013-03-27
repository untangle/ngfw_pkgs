import os
import sys
import subprocess
import datetime
import traceback

# This class is responsible for writing:
# /etc/untangle-netd/post-network-hook.d/960-iptables
# /etc/untangle-netd/iptables-rules.d/010-flush
# /etc/untangle-netd/iptables-rules.d/100-interface-marks
#
# based on the settings object passed from sync-settings.py
#
class IptablesManager:
    flushFilename = "/etc/untangle-netd/iptables-rules.d/010-flush"
    iptablesHookFilename = "/etc/untangle-netd/post-network-hook.d/960-iptables"

    def write_flush_file( self, prefix, verbosity ):

        filename = prefix + self.flushFilename
        fileDir = os.path.dirname( filename )
        if not os.path.exists( fileDir ):
            os.makedirs( fileDir )

        file = open( filename, "w+" )
        file.write("## Auto Generated on %s\n" % datetime.datetime.now());
        file.write("## DO NOT EDIT. Changes will be overwritten.\n");
        file.write("\n\n");
        
        file.write("## Flush all iptables rules.\n")
        file.write("for t_table in `cat /proc/net/ip_tables_names` ; do ${IPTABLES} -t ${t_table} -F ; done" + "\n" + "\n")

        file.write("## Flush all etables rules. (the only rules exist in the broute table)\n")
        file.write("${EBTABLES} -t broute -F" + "\n" + "\n")

        file.flush()
        file.close()

        if verbosity > 0:
            print "IptablesManager: Wrote %s" % filename

    def sync_settings( self, settings, prefix="", verbosity=0 ):
        if verbosity > 1: print "IptablesManager: sync_settings()"

        self.write_flush_file( prefix, verbosity )

        os.system("ln -sf /usr/share/untangle-netd/bin/generate-iptables-rules.sh %s" % self.iptablesHookFilename);
        if verbosity > 0:
            print "IptablesManager: Wrote %s" % self.iptablesHookFilename

