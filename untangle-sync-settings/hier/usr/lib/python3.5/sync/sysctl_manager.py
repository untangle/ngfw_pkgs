import os
import stat
import sys
import subprocess
import datetime
import traceback

# This class is responsible for writing /etc/untangle/post-network-hook.d/010-sysctl
# based on the settings object passed from sync-settings.py
class SysctlManager:
    filename = "/etc/untangle/post-network-hook.d/010-sysctl"

    def write_sysctl( self, settings, prefix, verbosity ):

        filename = prefix + self.filename
        fileDir = os.path.dirname( filename )
        if not os.path.exists( fileDir ):
            os.makedirs( fileDir )

        file = open( filename, "w+" )
        file.write("#!/bin/dash");
        file.write("\n\n");

        file.write("## Auto Generated\n");
        file.write("## DO NOT EDIT. Changes will be overwritten.\n");
        file.write("\n\n");

        file.write("# turn on IP forwarding" + "\n");
        file.write("sysctl -q -w net.ipv4.ip_forward=1" + "\n");
        file.write("\n");

        if settings.get('sendIcmpRedirects'):
            file.write("# turn on ICMP redirects" + "\n");
            file.write("find /proc/sys/net/ipv4/conf -type f -name 'send_redirects' | while read f ; do" + "\n");
            file.write("  echo 1 > ${f}" + "\n");
            file.write("done" + "\n");
            file.write("\n");
        else:
            file.write("# turn off ICMP redirects" + "\n");
            file.write("find /proc/sys/net/ipv4/conf -type f -name 'send_redirects' | while read f ; do" + "\n");
            file.write("  echo 0 > ${f}" + "\n");
            file.write("done" + "\n");
            file.write("\n");

        if settings.get('strictArpMode'):
            file.write("# set strict ARP mode (no arp flux)" + "\n");
            file.write("find /proc/sys/net/ipv4/conf -type f -name 'arp_ignore' | while read f ; do" + "\n");
            file.write("  echo 1 > ${f}" + "\n");
            file.write("done" + "\n");
            file.write("find /proc/sys/net/ipv4/conf -type f -name 'arp_announce' | while read f ; do" + "\n");
            file.write("  echo 2 > ${f}" + "\n");
            file.write("done" + "\n");
            file.write("\n");
        else:
            file.write("# set default ARP mode (arp flux)" + "\n");
            file.write("find /proc/sys/net/ipv4/conf -type f -name 'arp_ignore' | while read f ; do" + "\n");
            file.write("  echo 0 > ${f}" + "\n");
            file.write("done" + "\n");
            file.write("find /proc/sys/net/ipv4/conf -type f -name 'arp_announce' | while read f ; do" + "\n");
            file.write("  echo 0 > ${f}" + "\n");
            file.write("done" + "\n");
            file.write("\n");

        file.flush()
        file.close()

        os.chmod(filename, os.stat(filename).st_mode | stat.S_IEXEC)
        if verbosity > 0: print("SysctlManager: Wrote %s" % filename)

        return


    def sync_settings( self, settings, prefix="", verbosity=0 ):

        if verbosity > 1: print("SysctlManager: sync_settings()")
        
        self.write_sysctl( settings, prefix, verbosity )

        return
