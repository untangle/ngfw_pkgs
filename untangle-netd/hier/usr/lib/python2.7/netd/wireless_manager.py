import os
import sys
import subprocess
import datetime
import traceback

# This class is responsible for writing /etc/network/interfaces
# based on the settings object passed from sync-settings.py
class WirelessManager:
    hostapdConfFilename = "/etc/default/hostapd"

    def write_hostapd_conf( self, settings, prefix="", verbosity=0 ):

        filename = prefix + self.hostapdConfFilename
        self.hostapdConfFile = open( filename, "w+" )

        self.hostapdConfFile.write("## Auto Generated on %s\n" % datetime.datetime.now());
        self.hostapdConfFile.write("## DO NOT EDIT. Changes will be overwritten.\n");
        self.hostapdConfFile.write("\n\n");
        
        # FIXME
        # FIXME
        # FIXME
        # FIXME

        if settings == None or settings.get('interfaces') == None and settings.get('interfaces').get('list') == None:
            return
        interfaces = settings.get('interfaces').get('list')

        for intf in interfaces:
            if intf.get('isWirelessInterface'):
                print "XXX wireless Device: " + intf.get('systemDev')
                print "XXX wireless SSID: " + intf.get('wirelessSsid')
                print "XXX wireless Encryption: " + intf.get('wirelessEncryption')
                print "XXX wireless Password: " + intf.get('wirelessPassword')
                print "XXX wireless Channel: " + str(intf.get('wirelessChannel'))
                print "XXX wireless RadioMode: " + intf.get('wirelessRadioMode')

        self.hostapdConfFile.flush()
        self.hostapdConfFile.close()

        return

    def sync_settings( self, settings, prefix="", verbosity=0 ):
        if verbosity > 1: print "WirelessManager: sync_settings()"
        
        self.write_hostapd_conf( settings, prefix, verbosity )

