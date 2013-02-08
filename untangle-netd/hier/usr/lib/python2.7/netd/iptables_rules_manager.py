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
    srcInterfaceMarkMask = 0x00ff
    dstInterfaceMarkMask = 0xff00
    bothInterfacesMarksMask = 0xffff

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
            print "IptablesRulesManager: Wrote %s" % filename

    def write_interface_marks( self, settings, prefix, verbosity ):

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
        file.write("${IPTABLES} -t mangle -F restore-interface-marks >/dev/null 2>&1" + "\n");
        file.write("\n");
        
        file.write("# Call restore-interface-marks chain from PREROUTING chain in mangle" + "\n");
        file.write("${IPTABLES} -t mangle -D PREROUTING -m comment --comment \"Restore interface marks (0xffff) from connmark\" -j restore-interface-marks >/dev/null 2>&1" + "\n");
        file.write("${IPTABLES} -t mangle -A PREROUTING -m comment --comment \"Restore interface marks (0xffff) from connmark\" -j restore-interface-marks" + "\n");
        file.write("\n");

        file.write("# First zero out any marks on this packet"+ "\n");
        file.write("${IPTABLES} -t mangle -A restore-interface-marks -j MARK --and-mark 0xFFFF0000 -m comment --comment \"Zero out source and destination interface marks\"" + "\n");
        file.write("\n");
        
        file.write("# Ignore and broadcast sessions as they will all share the same conntrack entry so the connmark cant be used for src/dst intf" + "\n");
        file.write("# These packets will still be marked in the mark-src-intf and mark-dst-intf chains later");
        file.write("${IPTABLES} -t mangle -A restore-interface-marks -m addrtype --dst-type broadcast  -j RETURN -m comment --comment \"Do not mark broadcast packets\"" + "\n");
        file.write("${IPTABLES} -t mangle -A restore-interface-marks -m addrtype --src-type broadcast  -j RETURN -m comment --comment \"Do not mark broadcast packets\"" + "\n");
        file.write("\n");

        file.write("# This rule says if the packet is in the original direction, just copy the intf marks from the connmark/session mark" + "\n");
        file.write("# The rule actually says REPLY and not ORIGINAL and thats because ctdir matches backwards in 2.6.32 # http://www.spinics.net/lists/netfilter-devel/msg17864.html" + "\n");
        file.write("${IPTABLES} -t mangle -A restore-interface-marks -m conntrack --ctdir REPLY -j CONNMARK --restore-mark --mask 0x%X -m comment --comment \"If packet is in original direction, copy mark from connmark to packet\"" % self.bothInterfacesMarksMask + "\n");
        file.write("${IPTABLES} -t mangle -A restore-interface-marks -m conntrack --ctdir REPLY -j RETURN -m comment --comment \"If packet is in original direction we are done, just return\"" + "\n");
        file.write("\n");

        file.write("# Since this is a reply packet, copy dst intf from connmark to src intf mark, copy src intf from connmark to dst intf mark." + "\n");
        file.write("# Two rules for each interfaces, one to set src mark, one to set dst mark" + "\n")
        if settings == None or settings['interfaces'] == None or settings['interfaces']['list'] == None:
            print "ERROR: Missisg interfaces settings!"
            return
        interfaces = settings['interfaces']['list']
        for interface_settings in interfaces:
            if not 'interfaceId' in interface_settings:
                print "ERROR: Missing settings on intf!"
                continue;
            id = interface_settings['interfaceId']
            file.write("${IPTABLES} -t mangle -A restore-interface-marks -m connmark --mark 0x%04X/0x%04X -j MARK --set-mark 0x%04X/0x%04X -m comment --comment \"Set dst interface mark from connmark for intf %i\"" % (id, self.srcInterfaceMarkMask, id << 8, self.dstInterfaceMarkMask, id) + "\n");
            file.write("${IPTABLES} -t mangle -A restore-interface-marks -m connmark --mark 0x%04X/0x%04X -j MARK --set-mark 0x%04X/0x%04X -m comment --comment \"Set src interface mark from connmark for intf %i\"" % (id << 8, self.dstInterfaceMarkMask, id, self.srcInterfaceMarkMask, id) + "\n");
        file.write("\n");


        file.flush()
        file.close()

        if verbosity > 0:
            print "IptablesRulesManager: Wrote %s" % filename

        return

    def sync_settings( self, settings, prefix="", verbosity=0 ):
        if verbosity > 1: print "IptablesRulesManager: sync_settings()"

        self.write_flush_file( prefix, verbosity )

        self.write_interface_marks( settings, prefix, verbosity )

