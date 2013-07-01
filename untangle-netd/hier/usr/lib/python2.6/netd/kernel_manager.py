import os
import sys
import subprocess
import datetime
import traceback

# This class is responsible for writing:
# /etc/untangle-netd/post-network-hook.d/011-kernel
#
# based on the settings object passed from sync-settings.py
#
class KernelManager:
    kernelHookFilename = "/etc/untangle-netd/post-network-hook.d/011-kernel"

    def write_file( self, settings, prefix, verbosity ):

        filename = prefix + self.kernelHookFilename
        fileDir = os.path.dirname( filename )
        if not os.path.exists( fileDir ):
            os.makedirs( fileDir )

        file = open( filename, "w+" )
        file.write("#!/bin/dash");
        file.write("\n\n");

        file.write("## Auto Generated on %s\n" % datetime.datetime.now());
        file.write("## DO NOT EDIT. Changes will be overwritten.\n");
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

        file.flush()
        file.close()

        os.system("chmod a+x %s" % filename)
        if verbosity > 0: print "KernelManager: Wrote %s" % filename

    def sync_settings( self, settings, prefix="", verbosity=0 ):
        if verbosity > 1: print "KernelManager: sync_settings()"

        self.write_file( settings, prefix, verbosity )
