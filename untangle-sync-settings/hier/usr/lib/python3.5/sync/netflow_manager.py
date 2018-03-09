import os
import stat
import sys
import subprocess
import datetime
import traceback
import re
from shutil import move
from sync.network_util import NetworkUtil
from sync import registrar

# This class is responsible for writing 
# based on the settings object passed from sync-settings.py
class NetflowManager:
    softflow_daemon_conf_filename = "/etc/default/softflowd"
    restart_hook_filename = "/etc/untangle/post-network-hook.d/990-restart-softflowd"

    def sync_settings( self, settings, prefix, delete_list, verbosity=0 ):
        if verbosity > 1: print("NetflowManager: sync_settings()")
        self.write_softflow_daemon_conf( settings, prefix, verbosity )
        self.write_restart_softflow_daemon_hook( settings, prefix, verbosity )

    def initialize( self ):
        registrar.register_file( self.softflow_daemon_conf_filename, "restart-softflowd", self )
        registrar.register_file( self.restart_hook_filename, "restart-softflowd", self )
        
    def write_softflow_daemon_conf( self, settings, prefix="", verbosity=0 ):
        """
        Create softflow configuration file
        """
        filename = prefix + self.softflow_daemon_conf_filename
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
            except Exception as exc:
                traceback.print_exc()
            
        

        file.write("\n");
        file.flush()
        file.close()

        if verbosity > 0: print("NetflowManager: Wrote %s" % filename)
        return

    def write_restart_softflow_daemon_hook( self, settings, prefix="", verbosity=0 ):
        """
        Create network process extension to restart or stop daemon
        """
        filename = prefix + self.restart_hook_filename
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
    systemctl --no-block stop softflowd
fi
""")
        else:
            file.write(r"""
SOFTFLOWD_PID="`pidof softflowd`"

# Restart softflowd if it isnt found
# Or if /etc/default/softflowd has been written since softflowd was started
if [ ! -z "$SOFTFLOWD_PID" ] ; then
    systemctl --no-block restart softflowd
# use not older than (instead of newer than) because it compares seconds and we want an equal value to still do a restart
elif [ ! /etc/default/softflowd -ot /proc/$SOFTFLOWD_PID ] ; then
    systemctl --no-block restart softflowd
fi
""")

        file.write("\n");
        file.flush()
        file.close()
    
        os.chmod(filename, os.stat(filename).st_mode | stat.S_IEXEC)
        if verbosity > 0: print("NetflowManager: Wrote %s" % filename)
        return

