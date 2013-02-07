import os
import sys
import subprocess
import datetime
import traceback

# This class is responsible for writing /etc/untangle-netd/iptables-rules.d/010-flush
# based on the settings object passed from sync-settings.py
class IptablesRulesManager:
    flushFilename = "/etc/untangle-netd/iptables-rules.d/010-flush"
    interfaceMarksFilename = "/etc/untangle-netd/iptables-rules.d/100-interface-marks"

    def write_flush_file( self, prefix, verbosity ):
        flushFile = None

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

        if verbosity > 0:
            print "IptablesRulesManager: Wrote %s" % filename

    def write_interface_marks( self, settings, prefix, verbosity ):
        interfaceMarksFile = None

        filename = prefix + self.interfaceMarksFilename
        fileDir = os.path.dirname( filename )
        if not os.path.exists( fileDir ):
            os.makedirs( fileDir )

        file = open( filename, "w+" )
        file.write("## Auto Generated on %s\n" % datetime.datetime.now());
        file.write("## DO NOT EDIT. Changes will be overwritten.\n");
        file.write("\n\n");

        file.write("# Create (if needed) and flush restore-interface-marks chain" + "\n");
        file.write("${IPTABLES} -t mangle -N restore-interface-marks 2>/dev/null" + "\n");
        file.write("${IPTABLES} -t mangle -F restore-interface-marks >/dev/null 2>&1" + "\n" + "\n");
        
        file.write("# Call restore-interface-marks chain from PREROUTING chain in mangle" + "\n");
        file.write("${IPTABLES} -t mangle -D PREROUTING -m comment --comment \"Restore interface marks from connmark\" -j restore-interface-marks >/dev/null 2>&1" + "\n");
        file.write("${IPTABLES} -t mangle -A PREROUTING -m comment --comment \"Restore interface marks from connmark\" -j restore-interface-marks" + "\n" + "\n");

        if verbosity > 0:
            print "IptablesRulesManager: Wrote %s" % filename

        return

    def sync_settings( self, settings, prefix="", verbosity=0 ):
        if verbosity > 1: print "IptablesRulesManager: sync_settings()"

        self.write_flush_file( prefix, verbosity )

        self.write_interface_marks( settings, prefix, verbosity )

