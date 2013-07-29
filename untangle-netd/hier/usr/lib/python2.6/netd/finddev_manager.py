import os
import sys
import subprocess
import datetime
import traceback
import re
from netd.iptables_util import IptablesUtil
from netd.network_util import NetworkUtil

# This class is responsible for writing /etc/untangle-netd/post-network-hook.d/100-finddev
# based on the settings object passed from sync-settings.py
class FindDevManager:
    defaultFilename = "/etc/untangle-netd/post-network-hook.d/100-finddev"
    filename = defaultFilename
    file = None

    def calculate_cmd( self, settings, verbosity=0 ):
        cmd = "/usr/share/untangle-netd/bin/finddev -v -d -l /var/log/uvm/finddev.log "
        for intf in settings['interfaces']['list']:
            if 'interfaceId' not in intf or 'systemDev' not in intf:
                continue
            cmd = cmd + ( " -i %s:%i " % ( intf['systemDev'], int(intf['interfaceId']) ) )

        cmd = re.sub(r"\s+",' ',cmd).strip()
        return cmd;

    def sync_settings( self, settings, prefix="", verbosity=0 ):
        if verbosity > 1: print "FindDevManager: sync_settings()"

        self.filename = prefix + self.defaultFilename
        self.fileDir = os.path.dirname( self.filename )
        if not os.path.exists( self.fileDir ):
            os.makedirs( self.fileDir )

        self.file = open( self.filename, "w+" )
        self.file.write("#!/bin/dash");
        self.file.write("\n\n");

        self.file.write("## Auto Generated on %s\n" % datetime.datetime.now());
        self.file.write("## DO NOT EDIT. Changes will be overwritten.\n");
        self.file.write("\n");
        self.file.write("\n");

        self.file.write("QUEUE_NUM=1979" + "\n");
        self.file.write("\n");

        self.file.write("queue_owner()" + "\n");
        self.file.write("{" + "\n");
        self.file.write("    if [ -f /proc/net/netfilter/nfnetlink_queue ] ; then" + "\n");
        self.file.write("        echo `awk -v queue=$QUEUE_NUM '{ if ( $1 == queue  ) print $2 } ' /proc/net/netfilter/nfnetlink_queue`" + "\n");
        self.file.write("    fi" + "\n");
        self.file.write("}" + "\n");
        self.file.write("\n");

        self.file.write("start_finddev()" + "\n");
        self.file.write("{" + "\n");
        self.file.write("    %s \n" % self.calculate_cmd( settings ));
        self.file.write("}" + "\n");
        self.file.write("\n");

        self.file.write("current_cmd()" + "\n");
        self.file.write("{" + "\n");
        self.file.write("    if [ -z \"`queue_owner`\" ] ; then return ; fi" + "\n");
        self.file.write("    cat /proc/`queue_owner`/cmdline | tr '\\000' ' '" + "\n");
        self.file.write("}" + "\n");
        self.file.write("\n");

        self.file.write("wait_queue()" + "\n");
        self.file.write("{" + "\n");
        self.file.write("    for i in `seq 10` ; do" + "\n")
        self.file.write("        if [ -z \"`queue_owner`\" ] ; then" + "\n")
        self.file.write("            return" + "\n")
        self.file.write("        fi" + "\n")
        self.file.write("        sleep 1" + "\n")
        self.file.write("    done" + "\n")
        self.file.write("    echo \"finddev queue still owned by `queue_owner`!\"" + "\n")
        self.file.write("}" + "\n");
        self.file.write("\n");

        #self.file.write("echo \"CURRENT QUEUE OWNER:\" `queue_owner`" + "\n");
        #self.file.write("echo \"CURRENT CMD:\" `current_cmd`" + "\n");
        #self.file.write("\n");
        
        self.file.write("if [ ! -z \"`queue_owner`\" ] ; then" + "\n");
        self.file.write("    echo \"Stopping finddev [`queue_owner`].\"" + "\n");
        self.file.write("    kill -INT `queue_owner`" + "\n");
        self.file.write("    wait_queue" + "\n");
        self.file.write("fi" + "\n");
        self.file.write("\n");


        self.file.write("if [ ! -z \"`queue_owner`\" ] ; then" + "\n");
        self.file.write("    echo \"Killing finddev [`queue_owner`].\"" + "\n");
        self.file.write("    kill `queue_owner`" + "\n");
        self.file.write("    wait_queue" + "\n");
        self.file.write("fi" + "\n");
        self.file.write("\n");

        self.file.write("if [ -z \"`queue_owner`\" ] ; then" + "\n");
        self.file.write("    start_finddev" + "\n");
        self.file.write("    echo \"Started  finddev.\"" + "\n");
        self.file.write("fi" + "\n");
        self.file.write("\n");

        self.file.flush();
        self.file.close();

        os.system("chmod a+x %s" % self.filename)

        if verbosity > 0:
            print "FindDevManager: Wrote %s" % self.filename

        return



    
