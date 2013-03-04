import os
import sys
import subprocess
import datetime
import traceback
import re
from netd.network_util import NetworkUtil

# This class is responsible for writing 
# based on the settings object passed from sync-settings.py
class DnsMasqManager:
    dnsmasqConfFilename = "/etc/dnsmasq.conf"

    def write_dnsmasq_conf( self, settings, prefix="", verbosity=0 ):
        
        filename = prefix + self.dnsmasqConfFilename
        fileDir = os.path.dirname( filename )
        if not os.path.exists( fileDir ):
            os.makedirs( fileDir )

        file = open( filename, "w+" )
        file.write("## Auto Generated on %s\n" % datetime.datetime.now());
        file.write("## DO NOT EDIT. Changes will be overwritten.\n");
        file.write("\n\n");
        
        for intf in settings['interfaces']['list']:
            if intf.get('configType') == 'ADDRESSED' and intf.get('isWan') == True and intf.get('v4ConfigType') == 'STATIC':
                if intf.get('v4StaticDns1') != None:
                    file.write("# Interface %s DNS 1" % str(intf.get('interfaceId')) + "\n")
                    file.write("server=%s # uplink.%s" % (intf.get('v4StaticDns1'), str(intf.get('interfaceId'))) + "\n")
                    file.write("\n");
                

        file.flush()
        file.close()
    
        if verbosity > 0: print "DnsMasqManager: Wrote %s" % filename
        return

    def sync_settings( self, settings, prefix="", verbosity=0 ):

        if verbosity > 1: print "DnsMasqManager: sync_settings()"
        
        self.write_dnsmasq_conf( settings, prefix, verbosity )

        return
