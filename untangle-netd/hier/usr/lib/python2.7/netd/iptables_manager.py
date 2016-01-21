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

    def write_flush_file( self, settings, prefix, verbosity ):

        filename = prefix + self.flushFilename
        fileDir = os.path.dirname( filename )
        if not os.path.exists( fileDir ):
            os.makedirs( fileDir )

        file = open( filename, "w+" )
        file.write("## Auto Generated\n");
        file.write("## DO NOT EDIT. Changes will be overwritten.\n");
        file.write("\n\n");
        
        file.write("## Flush all iptables rules\n")
        file.write("${IPTABLES} -t raw -F" + "\n");
        file.write("${IPTABLES} -t tune -F" + "\n");
        file.write("${IPTABLES} -t nat -F" + "\n");
        file.write("${IPTABLES} -t mangle -F" + "\n");
        file.write("${IPTABLES} -t filter -F" + "\n");
        if settings.get('blockDuringRestarts') != None and settings.get('blockDuringRestarts'):
            file.write("${IPTABLES} -t filter -I FORWARD -m conntrack --ctstate NEW -j DROP -m comment --comment \"drop sessions during restart\"\n");
            file.write("${IPTABLES} -t filter -I INPUT   -m conntrack --ctstate NEW -j DROP -m comment --comment \"drop sessions during restart\"\n");

        file.write("\n");

        file.write("## Flush all etables rules. (the only rules exist in the broute table)\n")
        file.write("${EBTABLES} -t broute -F" + "\n" + "\n")

        file.write("\n");
        file.write("\n");

        file.write("## Create and flush all chains.\n")
        file.write("## We create and insert rules to call all chains here so the order is always the same no matter the order the scripts are called in.\n")
        file.write("## The scripts are responsible for filling in the chains with the appropriate rules.\n")
        
        file.write("${IPTABLES} -t mangle -N prerouting-set-marks 2>/dev/null" + "\n");
        file.write("${IPTABLES} -t mangle -F prerouting-set-marks" + "\n");
        file.write("${IPTABLES} -t mangle -A PREROUTING -j prerouting-set-marks" + "\n");

        file.write("${IPTABLES} -t mangle -N forward-set-marks 2>/dev/null" + "\n");
        file.write("${IPTABLES} -t mangle -F forward-set-marks" + "\n");
        file.write("${IPTABLES} -t mangle -A FORWARD -j forward-set-marks" + "\n");

        file.write("${IPTABLES} -t mangle -N output-set-marks 2>/dev/null" + "\n");
        file.write("${IPTABLES} -t mangle -F output-set-marks" + "\n");
        file.write("${IPTABLES} -t mangle -A OUTPUT -j output-set-marks" + "\n");

        file.write("${IPTABLES} -t mangle -N output-untangle-vm 2>/dev/null" + "\n");
        file.write("${IPTABLES} -t mangle -F output-untangle-vm" + "\n");
        file.write("${IPTABLES} -t mangle -A OUTPUT -j output-untangle-vm" + "\n");

        file.write("${IPTABLES} -t mangle -N input-set-marks 2>/dev/null" + "\n");
        file.write("${IPTABLES} -t mangle -F input-set-marks" + "\n");
        file.write("${IPTABLES} -t mangle -A INPUT -j input-set-marks" + "\n");

        file.write("${IPTABLES} -t mangle -N input-untangle-vm 2>/dev/null" + "\n");
        file.write("${IPTABLES} -t mangle -F input-untangle-vm" + "\n");
        file.write("${IPTABLES} -t mangle -A INPUT -j input-untangle-vm" + "\n");
        
        file.write("${IPTABLES} -t mangle -N prerouting-untangle-vm 2>/dev/null" + "\n");
        file.write("${IPTABLES} -t mangle -F prerouting-untangle-vm" + "\n");
        file.write("${IPTABLES} -t mangle -A PREROUTING -j prerouting-untangle-vm" + "\n");
        
        file.write("${IPTABLES} -t mangle -N prerouting-qos 2>/dev/null" + "\n");
        file.write("${IPTABLES} -t mangle -F prerouting-qos" + "\n");
        file.write("${IPTABLES} -t mangle -A PREROUTING -j prerouting-qos" + "\n");

        file.write("${IPTABLES} -t mangle -N postrouting-qos 2>/dev/null" + "\n");
        file.write("${IPTABLES} -t mangle -F postrouting-qos" + "\n");
        file.write("${IPTABLES} -t mangle -A POSTROUTING -j postrouting-qos" + "\n");
        
        file.write("${IPTABLES} -t mangle -N prerouting-wan-balancer 2>/dev/null" + "\n");
        file.write("${IPTABLES} -t mangle -F prerouting-wan-balancer" + "\n");
        file.write("${IPTABLES} -t mangle -A PREROUTING -j prerouting-wan-balancer" + "\n");
        
        file.flush()
        file.close()

        if verbosity > 0:
            print "IptablesManager: Wrote %s" % filename

    def sync_settings( self, settings, prefix="", verbosity=0 ):
        if verbosity > 1: print "IptablesManager: sync_settings()"

        self.write_flush_file( settings, prefix, verbosity )

        os.system("ln -sf /usr/share/untangle-netd/bin/generate-iptables-rules.sh %s" % self.iptablesHookFilename);
        if verbosity > 0:
            print "IptablesManager: Wrote %s" % self.iptablesHookFilename

