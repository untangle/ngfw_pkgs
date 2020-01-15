import os
import stat
import sys
import subprocess
import datetime
import traceback
from sync import registrar,Manager

# This class is responsible for writing /etc/untangle/pre-network-hook.d/015-ethernet-media
# based on the settings object passed from sync-settings


class EthernetManager(Manager):
    ethernet_media_filename = "/etc/untangle/pre-network-hook.d/015-ethernet-media"
    set_link_media_script = "/usr/share/untangle-sync-settings/bin/set-link-media.sh"

    def initialize(self):
        registrar.register_settings_file("network", self)
        registrar.register_file(self.ethernet_media_filename, "restart-networking", self)

    def sync_settings(self, settings_file, prefix, delete_list):
        self.write_ethernet_media(settings_file.settings, prefix)
        return

    def write_ethernet_media(self, settings, prefix):
        filename = prefix + self.ethernet_media_filename
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        file = open(filename, "w+")
        file.write("#!/bin/dash")
        file.write("\n\n")

        file.write("## Auto Generated\n")
        file.write("## DO NOT EDIT. Changes will be overwritten.\n")
        file.write("\n\n")

        if settings.get('devices') != None:
            for deviceSettings in settings.get('devices'):
                if deviceSettings.get('mtu') != None:
                    file.write("ifconfig %s mtu %s" % (deviceSettings.get('deviceName'), str(deviceSettings.get('mtu'))) + "\n")
                if deviceSettings.get('duplex') != None:
                    duplexString = deviceSettings.get('duplex')
                    if duplexString == "AUTO":
                        file.write("%s %s %s" % (self.set_link_media_script, deviceSettings.get('deviceName'), "auto") + "\n")
                    elif duplexString == "M10000_FULL_DUPLEX":
                        file.write("%s %s %s" % (self.set_link_media_script, deviceSettings.get('deviceName'), "10000-full-duplex") + "\n")
                    elif duplexString == "M10000_HALF_DUPLEX":
                        file.write("%s %s %s" % (self.set_link_media_script, deviceSettings.get('deviceName'), "10000-half-duplex") + "\n")
                    elif duplexString == "M1000_FULL_DUPLEX":
                        file.write("%s %s %s" % (self.set_link_media_script, deviceSettings.get('deviceName'), "1000-full-duplex") + "\n")
                    elif duplexString == "M1000_HALF_DUPLEX":
                        file.write("%s %s %s" % (self.set_link_media_script, deviceSettings.get('deviceName'), "1000-half-duplex") + "\n")
                    elif duplexString == "M100_FULL_DUPLEX":
                        file.write("%s %s %s" % (self.set_link_media_script, deviceSettings.get('deviceName'), "100-full-duplex") + "\n")
                    elif duplexString == "M100_HALF_DUPLEX":
                        file.write("%s %s %s" % (self.set_link_media_script, deviceSettings.get('deviceName'), "100-half-duplex") + "\n")
                    elif duplexString == "M10_FULL_DUPLEX":
                        file.write("%s %s %s" % (self.set_link_media_script, deviceSettings.get('deviceName'), "10-full-duplex") + "\n")
                    elif duplexString == "M10_HALF_DUPLEX":
                        file.write("%s %s %s" % (self.set_link_media_script, deviceSettings.get('deviceName'), "10-half-duplex") + "\n")
                    else:
                        print("ERROR: Unknown duplex: %s" % duplexString)

        file.flush()
        file.close()

        os.chmod(filename, os.stat(filename).st_mode | stat.S_IEXEC)
        print("EthernetManager: Wrote %s" % filename)

        return


registrar.register_manager(EthernetManager())
