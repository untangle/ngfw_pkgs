import os
import sys
import subprocess
import datetime
import traceback
import re
from netd.network_util import NetworkUtil

# This class is responsible for writing:
# /etc/radvd.conf
# based on the settings object passed from sync-settings.py
class RadvdManager:
    configFilename = "/etc/radvd.conf"

    def write_config_file( self, settings, prefix="", verbosity=0 ):

        filename = prefix + self.configFilename
        fileDir = os.path.dirname( filename )
        if not os.path.exists( fileDir ):
            os.makedirs( fileDir )

        file = open( filename, "w+" )

        if settings.get('raEnabled'):
            for intf in settings.get('interfaces').get('list'):

                if intf.get('configType') != "ADDRESSED":
                    continue
                if intf.get('v6ConfigType') != "STATIC":
                    continue
                if intf.get('v6StaticAddress') == None or intf.get('v6StaticPrefixLength') == None:
                    continue

                file.write("interface %s {" % intf.get('systemDev') + "\n")
                file.write("    AdvSendAdvert on;" + "\n")
                file.write("    MinRtrAdvInterval 3;" + "\n")
                file.write("    MaxRtrAdvInterval 10;" + "\n")
                file.write("    prefix %s/%s {" % (intf.get('v6StaticAddress'), intf.get('v6StaticPrefixLength')) + "\n")
                file.write("        AdvOnLink on;" + "\n")
                file.write("        AdvAutonomous on;" + "\n")
                file.write("        AdvRouterAddr on;" + "\n")
                file.write("    };" + "\n")
                file.write("};" + "\n")
            
        file.flush()
        file.close()

        if verbosity > 0: print "RadvdManager: Wrote %s" % filename

    def sync_settings( self, settings, prefix="", verbosity=0 ):

        if verbosity > 1: print "RadvdManager: sync_settings()"
        
        self.write_config_file( settings, prefix, verbosity )

        return
