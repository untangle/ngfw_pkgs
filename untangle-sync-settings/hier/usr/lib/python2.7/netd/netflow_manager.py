import os
import sys
import subprocess
import datetime
import traceback
import re
from shutil import move
from netd.network_util import NetworkUtil

# This class is responsible for writing 
# based on the settings object passed from sync-settings.py
class NetflowManager:
    softflowDaemonConfFilename = "/etc/default/softflowd"
    restartHookFilename = "/etc/untangle/post-network-hook.d/990-restart-softflowd"

    def write_softflow_daemon_conf( self, settings, prefix="", verbosity=0 ):
        """
        Create softflow configuration file
        """
        filename = prefix + self.softflowDaemonConfFilename
        fileDir = os.path.dirname( filename )
        if not os.path.exists( fileDir ):
            os.makedirs( fileDir )

        file = open( filename, "w+" )
        file.write("## Auto Generated\n");
        file.write("## DO NOT EDIT. Changes will be overwritten.\n");

        file.write("INTERFACE=\"any\"\n");
        if settings.get('netflowSettings') != None:
            netflowSettings = settings.get('netflowSettings')
            try:
                file.write("OPTIONS=\" -n %s:%i -v %i \"\n" % (netflowSettings.get('host'),netflowSettings.get('port'),netflowSettings.get('version')));
            except Exception,exc:
                traceback.print_exc()
            
        

        file.write("\n");
        file.flush()
        file.close()

        if verbosity > 0: print "NetflowManager: Wrote %s" % filename
        return

    def write_restart_softflow_daemon_hook( self, settings, prefix="", verbosity=0 ):
        """
        Create network process extension to restart or stop daemon
        """
        filename = prefix + self.restartHookFilename
        fileDir = os.path.dirname( filename )
        if not os.path.exists( fileDir ):
            os.makedirs( fileDir )

        file = open( filename, "w+" )
        file.write("#!/bin/dash");
        file.write("\n\n");

        file.write("## Auto Generated\n");
        file.write("## DO NOT EDIT. Changes will be overwritten.\n");
        file.write("\n");

        if settings.get('netflowSettings') == None or settings['netflowSettings'].get('enabled') is False:
            file.write(r"""
SOFTFLOWD_PID="`pidof softflowd`"

# Stop softflowd if running
if [ ! -z "$SOFTFLOWD_PID" ] ; then
    service softflowd stop
fi
""")
        else:
            file.write(r"""
SOFTFLOWD_PID="`pidof softflowd`"

# Restart softflowd if it isnt found
# Or if /etc/default/softflowd has been written since softflowd was started
if [ ! -z "$SOFTFLOWD_PID" ] ; then
    service softflowd restart
# use not older than (instead of newer than) because it compares seconds and we want an equal value to still do a restart
elif [ ! /etc/default/softflowd -ot /proc/$SOFTFLOWD_PID ] ; then
    service softflowd restart
fi
""")

        file.write("\n");
        file.flush()
        file.close()
    
        os.system("chmod a+x %s" % filename)
        if verbosity > 0: print "NetflowManager: Wrote %s" % filename
        return

    def sync_settings( self, settings, prefix="", verbosity=0 ):

        if verbosity > 1: print "NetflowManager: sync_settings()"
        
        self.write_softflow_daemon_conf( settings, prefix, verbosity )
        self.write_restart_softflow_daemon_hook( settings, prefix, verbosity )

        return
