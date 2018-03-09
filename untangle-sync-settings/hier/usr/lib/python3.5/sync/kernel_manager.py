import os
import stat
import sys
import subprocess
import datetime
import traceback
from sync import registrar

# This class is responsible for writing:
# /etc/untangle/post-network-hook.d/011-kernel
#
# based on the settings object passed from sync-settings.py
#
class KernelManager:
    kernel_hook_filename = "/etc/untangle/post-network-hook.d/011-kernel"

    def sync_settings( self, settings, prefix, delete_list, verbosity=0 ):
        if verbosity > 1: print("KernelManager: sync_settings()")
        self.write_file( settings, prefix, verbosity )

    def initialize( self ):
        registrar.register_file( self.kernel_hook_filename, "restart-networking", self )
        
    def write_file( self, settings, prefix, verbosity ):
        filename = prefix + self.kernel_hook_filename
        fileDir = os.path.dirname( filename )
        if not os.path.exists( fileDir ):
            os.makedirs( fileDir )

        file = open( filename, "w+" )
        file.write("#!/bin/dash");
        file.write("\n\n");

        file.write("## Auto Generated\n");
        file.write("## DO NOT EDIT. Changes will be overwritten.\n");
        file.write("\n\n");
        
        #
        # Handle NF Nat modules
        #
        file.write("uname -r | grep -q '^3'" + "\n");
        file.write("KERN_3_X=$?" + "\n");
        file.write("\n");

        file.write("# automatic conntrack helpers are removed from newer kernels > 4.0 " + "\n");
        file.write("if [ ${KERN_3_X} -eq 0 ] ; then" + "\n");
        file.write("\n");

        file.write("for mod in nf_nat_ftp nf_nat_tftp nf_nat_pptp nf_nat_h323 nf_nat_amanda nf_nat_snmp_basic nf_nat_proto_gre nf_nat_irc nf_nat_ftp nf_conntrack_pptp nf_conntrack_irc nf_conntrack_ftp nf_conntrack_amanda nf_conntrack_tftp nf_conntrack_h323 ; do" + "\n")
        file.write("\tif lsmod | grep -q $mod ; then" + "\n")
        file.write("\t\ttrue # do nothing" + "\n")         
        file.write("\telse" + "\n")
        file.write("\t\techo Loading $mod kernel module..." + "\n")
        file.write("\t\tmodprobe $mod" + "\n")
        file.write("\tfi" + "\n")
        file.write("done" + "\n")
        file.write("\n\n");

        #
        # Handle nf_nat_sip
        #
        file.write("if lsmod | grep -q nf_nat_sip ; then" + "\n")

        # Its already loaded
        if settings.get('enableSipNatHelper'):
            # And should be loaded - do nothing
            file.write("\ttrue" + "\n")         
        else:
            # And should not be loaded - unload it!
            file.write("\techo Unloading nf_nat_sip kernel module..." + "\n")
            file.write("\tmodprobe -r nf_nat_sip" + "\n")

        file.write("else" + "\n")
        # Its not loaded

        if settings.get('enableSipNatHelper'):
            # And should be loaded - load it!
            file.write("\techo Loading nf_nat_sip kernel module..." + "\n")
            file.write("\tmodprobe nf_nat_sip" + "\n")
        else:
            # And should not be loaded - do nothing!
            file.write("\ttrue" + "\n")         

        file.write("fi" + "\n")
        file.write("\n\n");

        #
        # Handle nf_conntrack_sip
        #
        file.write("if lsmod | grep -q nf_conntrack_sip ; then" + "\n")

        # Its already loaded
        if settings.get('enableSipNatHelper'):
            # And should be loaded - do nothing
            file.write("\ttrue" + "\n")         
        else:
            # And should not be loaded - unload it!
            file.write("\techo Unloading nf_conntrack_sip kernel module..." + "\n")
            file.write("\tmodprobe -r nf_conntrack_sip" + "\n")

        file.write("else" + "\n")
        # Its not loaded

        if settings.get('enableSipNatHelper'):
            # And should be loaded - load it!
            file.write("\techo Loading nf_conntrack_sip kernel module..." + "\n")
            file.write("\tmodprobe nf_conntrack_sip" + "\n")
        else:
            # And should not be loaded - do nothing!
            file.write("\ttrue" + "\n")         

        file.write("fi" + "\n")

        file.write("fi" + "\n");
        file.write("\n");
        
        file.flush()
        file.close()

        os.chmod(filename, os.stat(filename).st_mode | stat.S_IEXEC)
        if verbosity > 0: print("KernelManager: Wrote %s" % filename)

