import os
import sys
import subprocess
import datetime
import traceback

# This class is responsible for writing /etc/network/interfaces
# based on the settings object passed from sync-settings.py
class WirelessManager:
    hostapdConfFilename = "/etc/hostapd/hostapd.conf"
    hostapdDefaultFilename = "/etc/default/hostapd"
    hostapdRestartFilename = "/etc/untangle-netd/pre-network-hook.d/990-restart-hostapd"

    def write_hostapd_conf( self, settings, prefix="", verbosity=0 ):

        configFilename = prefix + self.hostapdConfFilename
        defaultFilename = prefix + self.hostapdDefaultFilename
        restartFilename = prefix + self.hostapdRestartFilename

        if settings == None or settings.get('interfaces') == None and settings.get('interfaces').get('list') == None:
            return

        self.hostapdDefaultFile = open( defaultFilename, "w+" )
        self.hostapdDefaultFile.write('DAEMON_CONF="/etc/hostapd/hostapd.conf"' + "\n")
        self.hostapdDefaultFile.flush()
        self.hostapdDefaultFile.close()

        print "WirelessManager: Wrote " + defaultFilename

        self.hostapdConfFile = open( configFilename, "w+" )

        self.hostapdConfFile.write("## Auto Generated on %s\n" % datetime.datetime.now())
        self.hostapdConfFile.write("## DO NOT EDIT. Changes will be overwritten.\n")
        self.hostapdConfFile.write("\n\n")
        
        interfaces = settings.get('interfaces').get('list')

        foundInterface = 0

        for intf in interfaces:
            if intf.get('isWirelessInterface'):
                foundInterface = 1
                self.hostapdConfFile.write("interface=%s\n" % intf.get('systemDev'))
                self.hostapdConfFile.write("ssid=%s\n" % intf.get('wirelessSsid'))
                self.hostapdConfFile.write("country_code=US\n")
                self.hostapdConfFile.write("max_num_sta=255\n")
                self.hostapdConfFile.write("auth_algs=1\n")
                self.hostapdConfFile.write("channel=%u\n" % intf.get('wirelessChannel'))
                if intf.get('wirelessEncryption') == 'NONE':
                    self.hostapdConfFile.write("wpa=0\n")
                elif intf.get('wirelessEncryption') == 'WPA1':
                    self.hostapdConfFile.write("wpa=1\n")
                    self.hostapdConfFile.write("wpa_passphrase=%s\n" % intf.get('wirelessPassword'))
                    self.hostapdConfFile.write("wpa_key_mgmt=WPA-PSK\n")
                    self.hostapdConfFile.write("wpa_pairwise=TKIP\n")
                    self.hostapdConfFile.write("rsn_pairwise=CCMP\n")
                elif intf.get('wirelessEncryption') == 'WPA12':
                    self.hostapdConfFile.write("wpa=3\n")
                    self.hostapdConfFile.write("wpa_passphrase=%s\n" % intf.get('wirelessPassword'))
                    self.hostapdConfFile.write("wpa_key_mgmt=WPA-PSK\n")
                    self.hostapdConfFile.write("wpa_pairwise=TKIP\n")
                    self.hostapdConfFile.write("rsn_pairwise=CCMP\n")
                elif intf.get('wirelessEncryption') == 'WPA2':
                    self.hostapdConfFile.write("wpa=2\n")
                    self.hostapdConfFile.write("wpa_passphrase=%s\n" % intf.get('wirelessPassword'))
                    self.hostapdConfFile.write("wpa_key_mgmt=WPA-PSK\n")
                    self.hostapdConfFile.write("wpa_pairwise=TKIP\n")
                    self.hostapdConfFile.write("rsn_pairwise=CCMP\n")

                if intf.get('wirelessRadioMode') == 'W80211B':
                    self.hostapdConfFile.write("hw_mode=b\n")
                elif intf.get('wirelessRadioMode') == 'W80211BG':
                    self.hostapdConfFile.write("hw_mode=g\n")
                elif intf.get('wirelessRadioMode') == 'W80211BGN':
                    self.hostapdConfFile.write("hw_mode=g\n")
                    self.hostapdConfFile.write("ieee80211n=1\n")
                    self.hostapdConfFile.write("wmm_enabled=1\n")

                # hostapd can only handle one wireless interface, so break after the first one
                break

        self.hostapdConfFile.flush()
        self.hostapdConfFile.close()

        if foundInterface == 1:            
            # Write out the hostapd restart script

            self.hostapdRestartFile = open( restartFilename, "w+" )

            self.hostapdRestartFile.write("#!/bin/dash")
            self.hostapdRestartFile.write("\n\n")
            self.hostapdRestartFile.write("## Auto Generated on %s\n" % datetime.datetime.now())
            self.hostapdRestartFile.write("## DO NOT EDIT. Changes will be overwritten.\n")
            self.hostapdRestartFile.write("\n")

            self.hostapdRestartFile.write("/etc/init.d/hostapd restart\n")

            self.hostapdRestartFile.flush()
            self.hostapdRestartFile.close()

            os.system("chmod a+x %s" % restartFilename)

            print "WirelessManager: Wrote " + configFilename
            print "WirelessManager: Wrote " + restartFilename
        else:
            # Write out the hostapd stop script

            self.hostapdRestartFile = open( restartFilename, "w+" )

            self.hostapdRestartFile.write("#!/bin/dash")
            self.hostapdRestartFile.write("\n\n")
            self.hostapdRestartFile.write("## Auto Generated on %s\n" % datetime.datetime.now())
            self.hostapdRestartFile.write("## DO NOT EDIT. Changes will be overwritten.\n")
            self.hostapdRestartFile.write("\n")

            self.hostapdRestartFile.write("/etc/init.d/hostapd stop\n")

            self.hostapdRestartFile.flush()
            self.hostapdRestartFile.close()

            os.system("chmod a+x %s" % restartFilename)

            print "WirelessManager: Wrote " + restartFilename

            os.unlink(configFilename)
            os.unlink(defaultFilename)

        return

    def sync_settings( self, settings, prefix="", verbosity=0 ):
        if verbosity > 1: print "WirelessManager: sync_settings()"
        
        self.write_hostapd_conf( settings, prefix, verbosity )

