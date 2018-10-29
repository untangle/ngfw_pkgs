import os
import stat
import sys
import subprocess
import datetime
import traceback
import re
from sync import registrar
from sync import board_util

# This class is responsible for writing /etc/config/wireless
# based on the settings object passed from sync-settings


class WirelessManager:
    wireless_filename = "/etc/config/wireless"

    def initialize(self):
        registrar.register_file(self.wireless_filename, "restart-wireless", self)

    def sanitize_settings(self, settings):
        pass

    def validate_settings(self, settings):
        pass

    def create_settings(self, settings, prefix, delete_list, filename):
        print("%s: Initializing settings" % self.__class__.__name__)
        interfaces = settings['network']['interfaces']
        for intf in interfaces:
            if intf['device'].startswith("wlan"):
                intf['wireless'] = True
                if self.is_5ghz(intf):
                    intf['wirelessChannel'] = 36
                else:
                    intf['wirelessChannel'] = 11
                intf['wirelessMode'] = 'AP'
                intf['wirelessEncryption'] = 'WPA2'
                intf['wirelessPassword'] = '12345678'
                intf['wirelessSsid'] = 'Untangle'

    def sync_settings(self, settings, prefix, delete_list):
        print("%s: Syncing settings" % self.__class__.__name__)
        self.write_wireless_file(settings, prefix)

    def get_phy_name(self, interface):
        return subprocess.check_output("cat /sys/class/net/%s/phy80211/name" % interface['device'], shell=True).decode('ascii').rstrip()

    def get_phy_path(self, interface):
        path = subprocess.check_output("readlink -f /sys/class/ieee80211/%s/device" % self.get_phy_name(interface), shell=True).decode('ascii').rstrip()
        path = os.path.relpath(path, '/sys/devices')
        if bool(re.search('platform.*/pci*', path)):
            path = os.path.relpath(path, '/platform')
        return path

    def get_phy_mac(self, interface):
        return subprocess.check_output("cat /sys/class/ieee80211/%s/macaddress" % self.get_phy_name(interface), shell=True).decode('ascii').rstrip()

    def get_device_id(self, interface):
        if os.path.islink("/sys/class/ieee80211/%s" % self.get_phy_name(interface)):
            return "option path '%s'" % self.get_phy_path(interface)
        else:
            return "option macaddr '%s'" % self.get_phy_mac(interface)

    def is_5ghz(self, interface):
        return (0 == subprocess.call("iw phy %s info | grep -q '5180 MHz'" % self.get_phy_name(interface), shell=True))

    def get_hwmode(self, interface):
        if self.is_5ghz(interface):
            return "11a"
        else:
            return "11g"

    def get_htmode(self, interface):
        htmode = ""
        if (0 == subprocess.call("iw phy %s info | grep -q 'Capabilities:'" % self.get_phy_name(interface), shell=True)):
            htmode = "\toption htmode 'HT20'\n"
        if self.is_5ghz(interface):
            if (0 == subprocess.call("iw phy %s info | grep -q 'VHT Capabilities'" % self.get_phy_name(interface), shell=True)):
                htmode = "\toption htmode 'VHT80'\n"
        return htmode

    def get_bridge_name(self, settings, interface):
        interfaces = settings['network']['interfaces']
        for intf in interfaces:
            if intf.get('interfaceId') == interface.get('bridgedTo'):
                return "b_" + intf.get('name')

    def write_country(self, file):
        country_code = board_util.get_country_code()
        if country_code != "":
            file.write("\toption country '%s'\n" % country_code)

    def write_macaddr(self, file, macaddr):
        if macaddr != "":
            file.write("\toption macaddr '%s'\n" % macaddr)

    def write_wireless_file(self, settings, prefix=""):
        filename = prefix + self.wireless_filename
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        self.network_file = open(filename, "w+")
        file = self.network_file
        file.write("## Auto Generated\n")
        file.write("## DO NOT EDIT. Changes will be overwritten.\n")

        file.write("\n")

        interfaces = settings['network']['interfaces']
        devidx = 0
        for intf in interfaces:
            if intf.get('wireless'):
                file.write("config wifi-device 'radio%d'\n" % devidx)
                file.write("\toption type 'mac80211'\n")
                file.write("\toption channel '%s'\n" % intf['wirelessChannel'])
                file.write("\toption hwmode '%s'\n" % self.get_hwmode(intf))
                file.write("\t%s\n" % self.get_device_id(intf))
                file.write("%s" % self.get_htmode(intf))
                if intf.get('configType') == 'DISABLED':
                    file.write("\toption disabled '1'\n")
                else:
                    file.write("\toption disabled '0'\n")
                self.write_country(file)
                file.write("\n")
                file.write("config wifi-iface 'default_radio%d'\n" % devidx)
                file.write("\toption device 'radio%d'\n" % devidx)
                if intf.get('configType') == 'BRIDGED':
                    file.write("\toption network '%s'\n" % self.get_bridge_name(settings, intf))
                elif intf.get('configType') == 'ADDRESSED':
                    file.write("\toption network '%s'\n" % (intf.get('name')+"4"))
                if intf.get('wirelessMode') == 'AP':
                    file.write("\toption mode 'ap'\n")
                else:
                    file.write("\toption mode 'sta'\n")
                file.write("\toption ssid '%s'\n" % intf.get('wirelessSsid'))
                if intf.get('wirelessEncryption') == 'NONE':
                    file.write("\toption encryption 'none'\n")
                elif intf.get('wirelessEncryption') == 'WPA1':
                    file.write("\toption encryption 'psk'\n")
                    file.write("\toption key '%s'\n" % intf.get('wirelessPassword'))
                elif intf.get('wirelessEncryption') == 'WPA12':
                    file.write("\toption encryption 'psk-mixed+tkip+ccmp'\n")
                    file.write("\toption key '%s'\n" % intf.get('wirelessPassword'))
                else:
                    file.write("\toption encryption 'psk2'\n")
                    file.write("\toption key '%s'\n" % intf.get('wirelessPassword'))
                self.write_macaddr(file, intf.get('macaddr'))
                file.write("\n")
                devidx += 1

        file.flush()
        file.close()

        print("%s: Wrote %s" % (self.__class__.__name__, filename))


registrar.register_manager(WirelessManager())
