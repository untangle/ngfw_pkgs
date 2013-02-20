import os
import sys
import subprocess
import datetime
import traceback

# This class is responsible for writing /etc/untangle-netd/pre-network-hook.d/015-ethernet-media
# based on the settings object passed from sync-settings.py
class EthernetManager:
    ethernetMediaFilename = "/etc/untangle-netd/pre-network-hook.d/015-ethernet-media"

    def write_ethernet_media( self, settings, prefix, verbosity ):

        filename = prefix + self.ethernetMediaFilename
        fileDir = os.path.dirname( filename )
        if not os.path.exists( fileDir ):
            os.makedirs( fileDir )

        file = open( filename, "w+" )
        file.write("#!/bin/dash");
        file.write("\n\n");

        file.write("## Auto Generated on %s\n" % datetime.datetime.now());
        file.write("## DO NOT EDIT. Changes will be overwritten.\n");
        file.write("\n\n");
        
        file.write("SCRIPT_SET_LINK_MEDIA=\"/usr/share/untangle-netd/bin/set-link-media.sh\"\n")
        file.write("\n");

        # FIXME - write something that sets link media based on settings!

        file.write("#    cat \"${ETHERNET_MEDIA_CONF}\" | awk '/^[a-z][^#]*$/ { print }' | while read t_nic t_media ; do \n")
        file.write("#        $DEBUG \"${t_nic}, ${t_media}\" \n")
        file.write("#        ${SCRIPT_SET_LINK_MEDIA} ${t_nic} ${t_media} \n")
        file.write("#    done\n")

        file.write("\n\n");
        file.write("echo \"FIXME: set link media\"\n\n")

        file.flush()
        file.close()

        os.system("chmod a+x %s" % filename)
        if verbosity > 0: print "EthernetManager: Wrote %s" % filename

        return

    def sync_settings( self, settings, prefix="", verbosity=0 ):

        if verbosity > 1: print "EthernetManager: sync_settings()"
        
        self.write_ethernet_media( settings, prefix, verbosity )

        return
