import os
import sys
import subprocess
import datetime
import traceback
import re
from netd.network_util import NetworkUtil

# This class is responsible for writing PPPoE related conf files
# based on the settings object passed from sync-settings.py
# 
# 
class PPPoEManager:
    papSecretsFilename = "/etc/ppp/pap-secrets"
    chapSecretsFilename = "/etc/ppp/chap-secrets"
    peersDirectory = "/etc/ppp/peers/"
    connectionBaseName = "connection.intf"

    def write_pppoe_connection_files( self, settings, prefix="", verbosity=0 ):

        for interface_settings in settings.get('interfaces').get('list'):
            if "PPPOE" == interface_settings.get('v4ConfigType'):
                # open this pppoe config file for this connection
                fileName = self.peersDirectory + self.connectionBaseName + str(interface_settings.get('interfaceId'))
                conffile = open( fileName, "w+" )
                conffile.write("## Auto Generated on %s\n" % datetime.datetime.now());
                conffile.write("## DO NOT EDIT. Changes will be overwritten.\n");
                conffile.write("\n");

                conffile.write("""
noipdefault
hide-password
noauth
persist
maxfail 0

""")
                conffile.write("# PPPoE settings for %s." % interface_settings.get('systemDev') + "\n");

                conffile.write("plugin rp-pppoe.so %s" % interface_settings.get('physicalDev') + "\n")
                conffile.write("user \"%s\"" % interface_settings.get('v4PPPoEUsername') + "\n")

                if ( interface_settings.get('v4PPPoEUsePeerDns') == True ):
                    conffile.write("usepeerdns" + "\n")

                conffile.flush()
                conffile.close()

                if verbosity > 0:
                    print "PPPoEManager: Wrote %s" % fileName

        return

    def write_secret_files( self, settings, prefix="", verbosity=0 ):

        secrets = ""
        secrets += "## Auto Generated on %s\n" % datetime.datetime.now()
        secrets += "## DO NOT EDIT. Changes will be overwritten.\n"
        secrets += "\n"

        pppoe_found = False
        for interface_settings in settings.get('interfaces').get('list'):
            if "PPPOE" == interface_settings.get('v4ConfigType'):
                pppoe_found = True
                secrets += "\"%s\" * \"%s\" *\n" % ( interface_settings.get('v4PPPoEUsername'), interface_settings.get('v4PPPoEPassword') )

        if not pppoe_found:
            return

        papSecretsFile = open( self.papSecretsFilename, "w+" )
        papSecretsFile.write(secrets)
        papSecretsFile.flush();
        papSecretsFile.close();
        if verbosity > 0:
            print "PPPoEManager: Wrote %s" % self.papSecretsFilename
        
        chapSecretsFile = open( self.chapSecretsFilename, "w+" )
        chapSecretsFile.write(secrets)
        chapSecretsFile.flush();
        chapSecretsFile.close();
        if verbosity > 0:
            print "PPPoEManager: Wrote %s" % self.chapSecretsFilename
        
        return

    def sync_settings( self, settings, prefix="", verbosity=0 ):

        if verbosity > 1: print "PPPoEManager: sync_settings()"
        
        self.write_pppoe_connection_files( settings, prefix, verbosity )
        self.write_secret_files( settings, prefix, verbosity )

        return
