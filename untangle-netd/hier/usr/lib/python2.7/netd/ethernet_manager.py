import os
import sys
import subprocess
import datetime
import traceback

# This class is responsible for writing /etc/untangle-netd/pre-network-hook.d/015-ethernet-media
# based on the settings object passed from sync-settings.py
class EthernetManager:
    ethernetMediaFilename = "/etc/untangle-netd/pre-network-hook.d/015-ethernet-media"
    setLinkMediaScript = "/usr/share/untangle-netd/bin/set-link-media.sh"

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
        
        if settings.get('devices') != None and settings.get('devices').get('list') != None:
            for deviceSettings in settings.get('devices').get('list'):
                if deviceSettings.get('mtu') != None:
                    file.write("ifconfig %s mtu %s" % (deviceSettings.get('deviceName'), str(deviceSettings.get('mtu'))) + "\n")
                if deviceSettings.get('duplex') != None:
                    duplexString = deviceSettings.get('duplex')
                    if duplexString == "AUTO":
                        file.write("%s %s %s" % (self.setLinkMediaScript, deviceSettings.get('deviceName'), "auto") + "\n")
                    elif duplexString == "M10000_FULL_DUPLEX":
                        file.write("%s %s %s" % (self.setLinkMediaScript, deviceSettings.get('deviceName'), "10000-full-duplex") + "\n")
                    elif duplexString == "M10000_HALF_DUPLEX":
                        file.write("%s %s %s" % (self.setLinkMediaScript, deviceSettings.get('deviceName'), "10000-half-duplex") + "\n")
                    elif duplexString == "M1000_FULL_DUPLEX":
                        file.write("%s %s %s" % (self.setLinkMediaScript, deviceSettings.get('deviceName'), "1000-full-duplex") + "\n")
                    elif duplexString == "M1000_HALF_DUPLEX":
                        file.write("%s %s %s" % (self.setLinkMediaScript, deviceSettings.get('deviceName'), "1000-half-duplex") + "\n")
                    elif duplexString == "M100_FULL_DUPLEX":
                        file.write("%s %s %s" % (self.setLinkMediaScript, deviceSettings.get('deviceName'), "100-full-duplex") + "\n")
                    elif duplexString == "M100_HALF_DUPLEX":
                        file.write("%s %s %s" % (self.setLinkMediaScript, deviceSettings.get('deviceName'), "100-half-duplex") + "\n")
                    elif duplexString == "M10_FULL_DUPLEX":
                        file.write("%s %s %s" % (self.setLinkMediaScript, deviceSettings.get('deviceName'), "10-full-duplex") + "\n")
                    elif duplexString == "M10_HALF_DUPLEX":
                        file.write("%s %s %s" % (self.setLinkMediaScript, deviceSettings.get('deviceName'), "10-half-duplex") + "\n")
                    else:
                        print "ERROR: Unknown duplex: %s" % duplexString

        file.flush()
        file.close()

        os.system("chmod a+x %s" % filename)
        if verbosity > 0: print "EthernetManager: Wrote %s" % filename

        return

    def sync_settings( self, settings, prefix="", verbosity=0 ):

        if verbosity > 1: print "EthernetManager: sync_settings()"
        
        self.write_ethernet_media( settings, prefix, verbosity )

        return
