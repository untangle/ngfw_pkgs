import os
import sys
import subprocess
import datetime
import traceback

# This class is responsible for writing /etc/untangle-netd/iptables-rules.d/010-flush
# based on the settings object passed from sync-settings.py
class IptablesRulesManager:
    flushFilename = "/etc/untangle-netd/iptables-rules.d/010-flush"
    flushFile = None

    def sync_settings( self, settings, prefix="", verbosity=0 ):
        if verbosity > 1: print "IptablesRulesManager: sync_settings()"

        self.filename = prefix + self.flushFilename
        self.fileDir = os.path.dirname( self.filename )
        if not os.path.exists( self.fileDir ):
            os.makedirs( self.fileDir )

        self.flushFile = open( self.filename, "w+" )
        self.flushFile.write("## Auto Generated on %s\n" % datetime.datetime.now());
        self.flushFile.write("## DO NOT EDIT. Changes will be overwritten.\n");
        self.flushFile.write("\n\n");
        
        self.flushFile.write("## Flush all iptables rules.\n")
        self.flushFile.write("for t_table in `cat /proc/net/ip_tables_names` ; do ${IPTABLES} -t ${t_table} -F ; done" + "\n" + "\n")

        self.flushFile.write("## Flush all etables rules. (the only rules exist in the broute table)\n")
        self.flushFile.write("${EBTABLES} -t broute -F" + "\n" + "\n")

        if verbosity > 0:
            print "IptablesRulesManager: Wrote %s" % self.filename
