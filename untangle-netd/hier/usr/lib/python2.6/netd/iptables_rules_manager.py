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

    def write_restore_interface_marks( self, file, interfaces, prefix, verbosity ):

        file.write("\n\n");
        file.write("#\n");
        file.write("# Create restore-interface-marks chain"+ "\n");
        file.write("#\n\n");

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

        for intf in interfaces:
            id = intf['interfaceId']
            file.write("${IPTABLES} -t mangle -A restore-interface-marks -m connmark --mark 0x%04X/0x%04X -j MARK --set-mark 0x%04X/0x%04X -m comment --comment \"Set dst interface mark from connmark for intf %i\"" % (id, self.srcInterfaceMarkMask, id << 8, self.dstInterfaceMarkMask, id) + "\n");
            file.write("${IPTABLES} -t mangle -A restore-interface-marks -m connmark --mark 0x%04X/0x%04X -j MARK --set-mark 0x%04X/0x%04X -m comment --comment \"Set src interface mark from connmark for intf %i\"" % (id << 8, self.dstInterfaceMarkMask, id, self.srcInterfaceMarkMask, id) + "\n");
        file.write("\n");

    def write_mark_src_intf( self, file, interfaces, prefix, verbosity ):

        file.write("\n\n");
        file.write("#\n");
        file.write("# Create the mark-src-intf chain." + "\n");
        file.write("#\n\n");

        file.write("${IPTABLES} -t mangle -A mark-src-intf -m mark ! --mark 0/0x%04X -j RETURN -m comment --comment \"If its already set, just return\"" % (self.srcInterfaceMarkMask) + "\n");
        file.write("\n");

        file.write("${IPTABLES} -t mangle -A mark-src-intf -i utun -j RETURN -m comment --comment \"Ignore utun traffic\"" + "\n");
        file.write("\n");

        for intf in interfaces:
            id = intf['interfaceId']
            systemDev = intf['systemDev']
            symbolicDev = intf['symbolicDev']
            config = intf['config']

            file.write("${IPTABLES} -t mangle -A mark-src-intf -i %s -j MARK --set-mark 0x%04X/0x%04X -m comment --comment \"Set src interface mark for intf %i\"" % (systemDev, id, self.srcInterfaceMarkMask, id) + "\n");
            # if bridged also add bridge rules
            if symbolicDev.startswith("br.") or config == 'bridged':
                file.write("${IPTABLES} -t mangle -A mark-src-intf -m physdev --physdev-in %s -j MARK --set-mark 0x%04X/0x%04X -m comment --comment \"Set src interface mark for intf %i using physdev\"" % (systemDev, id, self.srcInterfaceMarkMask, id) + "\n");

        file.write("${IPTABLES} -t mangle -A mark-src-intf ! -i lo -m mark --mark 0/0x%04X -j LOG --log-prefix \"WARNING (unknown src intf):\" -m comment --comment \"WARN on missing src mark\"" % (self.srcInterfaceMarkMask) + "\n");
        file.write("${IPTABLES} -t mangle -A mark-src-intf -m conntrack --ctstate NEW -j CONNMARK --save-mark --mask 0x%04X -m comment --comment \"Save src interface mark to connmark\"" % (self.srcInterfaceMarkMask) + "\n");

        file.write("\n");

    def write_mark_dst_intf( self, file, interfaces, prefix, verbosity ):

        file.write("\n\n");
        file.write("#\n");
        file.write("# Create the mark-dst-intf chain." + "\n");
        file.write("#\n\n");

        # We dont bother with already marked packets, except if its the first packet in the session
        # If it is the first packet then WAN-balancer could have picked a WAN but it might be headed elsewhere because of a static route.
        file.write("${IPTABLES} -t mangle -A mark-dst-intf -m mark ! --mark 0/0x%04X -m conntrack ! --ctstate NEW -j RETURN -m comment --comment \"If its already set and an existing session, just return\"" % (self.dstInterfaceMarkMask) + "\n");
        file.write("\n");

        for intf in interfaces:
            id = intf['interfaceId']
            systemDev = intf['systemDev']
            symbolicDev = intf['symbolicDev']
            config = intf['config']

            file.write("${IPTABLES} -t mangle -A mark-dst-intf -o %s -j MARK --set-mark 0x%04X/0x%04X -m comment --comment \"Set dst interface mark for intf %i\"" % (systemDev, id << 8, self.dstInterfaceMarkMask, id) + "\n");
            # if bridged also add bridge rules
            if symbolicDev.startswith("br.") or config == 'bridged':
                # physdev-out doesn't work, instead queue to userspace daemon
                # file.write("${IPTABLES} -t mangle -A mark-dst-intf -m physdev --physdev-out %s -j MARK --set-mark 0x%04X/0x%04X -m comment --comment \"Set dst interface mark for intf %i using physdev\"" % (systemDev, id << 8, self.dstInterfaceMarkMask, id) + "\n");
                file.write("${IPTABLES} -t mangle -A mark-dst-intf -m mark --mark 0/0x%04X -o %s -j NFQUEUE --queue-num 1979 -m comment --comment \"queue bridge packets to daemon to determine dst intf/port\"" % (self.dstInterfaceMarkMask, symbolicDev) + "\n");
                # file.write("${IPTABLES} -t mangle -A mark-dst-intf -o %s -j LOG --log-prefix \"FIXME queue me:\" -m comment --comment \"queue bridge destined packets to daemon to determine destination\"" % (symbolicDev) + "\n");

                
        file.write("${IPTABLES} -t mangle -A mark-dst-intf -m mark --mark 0/0x%04X -j LOG --log-prefix \"WARNING (unknown dst intf):\" -m comment --comment \"WARN on missing dst mark\"" % (self.dstInterfaceMarkMask) + "\n");
        file.write("${IPTABLES} -t mangle -A mark-dst-intf -m conntrack --ctstate NEW -j CONNMARK --save-mark --mask 0x%04X -m comment --comment \"Save dst interface mark to connmark\"" % (self.dstInterfaceMarkMask) + "\n");
                
        file.write("\n");


    def write_interface_marks( self, settings, prefix, verbosity ):
        interfaces = settings['interfaces']['list']

        filename = prefix + self.interfaceMarksFilename
        fileDir = os.path.dirname( filename )
        if not os.path.exists( fileDir ):
            os.makedirs( fileDir )

        file = open( filename, "w+" )
        file.write("## Auto Generated on %s\n" % datetime.datetime.now());
        file.write("## DO NOT EDIT. Changes will be overwritten.\n");
        file.write("\n\n");

        file.write("# Create (if needed) and flush restore-interface-marks, mark-src-intf, mark-dst-intf chains" + "\n");
        file.write("${IPTABLES} -t mangle -N restore-interface-marks 2>/dev/null" + "\n");
        file.write("${IPTABLES} -t mangle -F restore-interface-marks >/dev/null 2>&1" + "\n");
        file.write("${IPTABLES} -t mangle -N mark-src-intf 2>/dev/null" + "\n");
        file.write("${IPTABLES} -t mangle -F mark-src-intf >/dev/null 2>&1" + "\n");
        file.write("${IPTABLES} -t mangle -N mark-dst-intf 2>/dev/null" + "\n");
        file.write("${IPTABLES} -t mangle -F mark-dst-intf >/dev/null 2>&1" + "\n");
        file.write("\n");
        
        file.write("# Call restore-interface-marks then mark-src-intf from PREROUTING chain in mangle" + "\n");
        file.write("${IPTABLES} -t mangle -D PREROUTING -m comment --comment \"Restore interface marks (0xffff) from connmark\" -j restore-interface-marks >/dev/null 2>&1" + "\n");
        file.write("${IPTABLES} -t mangle -D PREROUTING -m comment --comment \"Set src intf mark (0x00ff)\" -j mark-src-intf >/dev/null 2>&1" + "\n");
        file.write("${IPTABLES} -t mangle -A PREROUTING -m comment --comment \"Restore interface marks (0xffff) from connmark\" -j restore-interface-marks" + "\n");
        file.write("${IPTABLES} -t mangle -A PREROUTING -m comment --comment \"Set src intf mark (0x00ff)\" -j mark-src-intf" + "\n");
        file.write("\n");

        file.write("# Call mark-dst-intf from FORWARD chain in mangle" + "\n");
        file.write("${IPTABLES} -t mangle -D FORWARD -m comment --comment \"Set dst intf mark (0xff00)\" -j mark-dst-intf >/dev/null 2>&1" + "\n");
        file.write("${IPTABLES} -t mangle -A FORWARD -m comment --comment \"Set dst intf mark (0xff00)\" -j mark-dst-intf" + "\n");
        file.write("\n");

        self.write_restore_interface_marks( file, interfaces, prefix, verbosity );

        self.write_mark_src_intf( file, interfaces, prefix, verbosity );

        self.write_mark_dst_intf( file, interfaces, prefix, verbosity );

        file.flush()
        file.close()

        if verbosity > 0:
            print "IptablesRulesManager: Wrote %s" % filename

        return

    def sync_settings( self, settings, prefix="", verbosity=0 ):
        if verbosity > 1: print "IptablesRulesManager: sync_settings()"

        self.write_flush_file( prefix, verbosity )

        self.write_interface_marks( settings, prefix, verbosity )

