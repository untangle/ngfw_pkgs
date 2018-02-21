import os
import sys
import subprocess
import datetime
import traceback

# This class is responsible for writing:
# /etc/untangle/post-network-hook.d/960-iptables
# /etc/untangle/iptables-rules.d/010-flush
# /etc/untangle/iptables-rules.d/100-interface-marks
#
# based on the settings object passed from sync-settings.py
#
class IptablesManager:
    flushFilename = "/etc/untangle/iptables-rules.d/010-flush"
    helpersFilename = "/etc/untangle/iptables-rules.d/011-helpers"
    iptablesHookFilename = "/etc/untangle/post-network-hook.d/960-iptables"

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
        
        file.write("${IPTABLES} -t mangle -N prerouting-tunnel-vpn 2>/dev/null" + "\n");
        file.write("${IPTABLES} -t mangle -F prerouting-tunnel-vpn" + "\n");
        file.write("${IPTABLES} -t mangle -A PREROUTING -j prerouting-tunnel-vpn" + "\n");

        file.write("${IPTABLES} -t mangle -N prerouting-wan-balancer 2>/dev/null" + "\n");
        file.write("${IPTABLES} -t mangle -F prerouting-wan-balancer" + "\n");
        file.write("${IPTABLES} -t mangle -A PREROUTING -j prerouting-wan-balancer" + "\n");
        
        file.flush()
        file.close()

        if verbosity > 0:
            print("IptablesManager: Wrote %s" % filename)


    def write_helpers_file( self, settings, prefix, verbosity ):

        filename = prefix + self.helpersFilename
        fileDir = os.path.dirname( filename )
        if not os.path.exists( fileDir ):
            os.makedirs( fileDir )

        file = open( filename, "w+" )
        file.write("## Auto Generated\n");
        file.write("## DO NOT EDIT. Changes will be overwritten.\n");
        file.write("\n\n");
        
        file.write("## Create all helper rules.\n")
        
        file.write("${IPTABLES} -t raw -N helpers 2>/dev/null" + "\n");
        file.write("${IPTABLES} -t raw -F helpers" + "\n");
        file.write("\n");

        file.write("${IPTABLES} -t raw -D PREROUTING -j helpers >/dev/null 2>&1" + "\n");
        file.write("${IPTABLES} -t raw -I PREROUTING -j helpers" + "\n");
        file.write("\n");

        file.write("uname -r | grep -q '^4'" + "\n");
        file.write("KERN_4_X=$?" + "\n");
        file.write("\n");

        file.write("if [ ${KERN_4_X} -eq 0 ] ; then" + "\n");
        file.write("\n");

        file.write("\t${IPTABLES} -t raw -A helpers -p udp --dport 1719 -j CT --helper RAS" + "\n");
        file.write("\t${IPTABLES} -t raw -A helpers -p tcp --dport 1720 -j CT --helper Q.931" + "\n");
        file.write("\n");

        if settings.get('enableSipNatHelper'):
            file.write("\t${IPTABLES} -t raw -A helpers -p tcp --dport 5060 -j CT --helper sip" + "\n");
            file.write("\t${IPTABLES} -t raw -A helpers -p udp --dport 5060 -j CT --helper sip" + "\n");
            file.write("\t${IPTABLES} -t raw -A helpers -p tcp --dport 5061 -j CT --helper sip" + "\n");
            file.write("\t${IPTABLES} -t raw -A helpers -p udp --dport 5061 -j CT --helper sip" + "\n");
            file.write("\n");
        
        # file.write("\t# only process bypassed sessions, the ftp-casing will handle scanned sessions" + "\n")
        # file.write("\t${IPTABLES} -t raw -A helpers -m connmark --mark 0x01000000/0x01000000 -p tcp --dport 21 -j CT --helper ftp" + "\n");
        file.write("\t${IPTABLES} -t raw -A helpers -p tcp --dport 21 -j CT --helper ftp" + "\n");
        file.write("\n");

        file.write("\t${IPTABLES} -t raw -A helpers -p tcp --dport 6667 -j CT --helper irc" + "\n");
        file.write("\n");

        # FIXME - in testing it seems this PPTP helper does not work
        # The GRE session does not get redirected
        # the nf_nat_pptp and associated GRE plugin do work correctly, but is deprecated in newer kernels
        file.write("\t${IPTABLES} -t raw -A helpers -p tcp --dport 1723 -j CT --helper pptp" + "\n");
        file.write("\n");

        file.write("\t${IPTABLES} -t raw -A helpers -p udp --dport 69 -j CT --helper tftp" + "\n");
        file.write("\n");

        file.write("\t${IPTABLES} -t raw -A helpers -p udp --dport 137 -j CT --helper netbios-ns" + "\n");
        file.write("\n");

        file.write("\t${IPTABLES} -t raw -A helpers -p udp --dport 161 -j CT --helper snmp" + "\n");
        file.write("\n");

        file.write("fi" + "\n");
        file.write("\n");

        file.flush()
        file.close()

        if verbosity > 0:
            print("IptablesManager: Wrote %s" % filename)


    def sync_settings( self, settings, prefix="", verbosity=0 ):
        if verbosity > 1: print("IptablesManager: sync_settings()")

        self.write_flush_file( settings, prefix, verbosity )
        self.write_helpers_file( settings, prefix, verbosity )

        os.system("ln -sf /usr/share/untangle-sync-settings/bin/generate-iptables-rules.sh %s" % self.iptablesHookFilename);
        if verbosity > 0:
            print("IptablesManager: Wrote %s" % self.iptablesHookFilename)

