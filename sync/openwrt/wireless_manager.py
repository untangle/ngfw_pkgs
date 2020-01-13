"""wireless_manager manages /etc/config/wireless"""
# pylint: disable=unused-argument
# pylint: disable=no-self-use
import os
import subprocess
import re
from sync import registrar, Manager
from sync import board_util
from sync import network_util

class WirelessManager(Manager):
    """
    This class is responsible for writing /etc/config/wireless
    based on the settings object passed from sync-settings
    """
    wireless_filename = "/etc/config/wireless"

    def initialize(self):
        """initialize this module"""
        registrar.register_settings_file("settings", self)
        registrar.register_file(self.wireless_filename, "restart-wireless", self)

    def validate_settings(self, settings_file):
        """validates settings"""
        interfaces = settings_file.settings['network']['interfaces']
        for intf in interfaces:
            if enabled_wifi(intf):
                encryption = intf.get('wirelessEncryption')
                if encryption == None or encryption == "":
                    raise Exception("No wireless encryption specified: " + intf.get('name'))
                if encryption == 'WPA1' or encryption == 'WPA12' or encryption == 'WPA2':
                    password = intf.get('wirelessPassword')
                    if password == None or password == "":
                        raise Exception("No WPA psk specified: " + intf.get('name'))
                    if len(password) < 8:
                        raise Exception("WPA psk too short: " + intf.get('name') + " " + password)

                ssid = intf.get('wirelessSsid')
                if ssid == None or ssid == "":
                    raise Exception("No ssid specified: " + intf.get('name'))

                mode = intf.get('wirelessMode')
                if mode == None or mode == "":
                    raise Exception("No wireless mode specified: " + intf.get('name'))
                if mode != 'AP' and mode != 'CLIENT':
                    raise Exception("Invalid wireless mode specified: " + intf.get('name') + " " + mode)

                if mode == 'AP':
                    channel = intf.get('wirelessChannel')
                    if channel == None:
                        raise Exception("No wireless channel specified: " + intf.get('name'))
                    if channel <= 0:
                        raise Exception("Invalid wireless channel specified: " + intf.get('name') + " " + str(channel))
                    if channel <= 11 and not self.has_2ghz(intf):
                        raise Exception("Invalid wireless channel specified for 5 Ghz: " + intf.get('name') + " " + str(channel))
                    if channel > 11 and not self.has_5ghz(intf):
                        raise Exception("Invalid wireless channel specified for 2.4 Ghz: " + intf.get('name') + " " + str(channel))

    def create_settings(self, settings_file, prefix, delete_list, filename):
        """creates settings"""
        print("%s: Initializing settings" % self.__class__.__name__)
        interfaces = settings_file.settings['network']['interfaces']
        for intf in interfaces:
            if intf.get('type') == 'WIFI':
                if self.has_5ghz(intf):
                    intf['wirelessChannel'] = 36
                else:
                    intf['wirelessChannel'] = 11
                intf['wirelessMode'] = 'AP'
                intf['wirelessEncryption'] = 'WPA2'
                intf['wirelessPassword'] = '12345678'
                intf['wirelessSsid'] = 'Untangle'
                intf['wirelessThroughput'] = 'AUTO'

    def sync_settings(self, settings_file, prefix, delete_list):
        """syncs settings"""
        print("%s: Syncing settings" % self.__class__.__name__)
        self.write_wireless_file(settings_file.settings, prefix)

    def get_phy_name(self, interface):
        "get the phy name for an device"
        return interface['device'].replace("wlan", "phy")

    def get_phy_path(self, interface):
        path = subprocess.check_output("readlink -f /sys/class/ieee80211/%s/device" % self.get_phy_name(interface), shell=True).decode('ascii').rstrip()
        path = os.path.relpath(path, '/sys/devices')
        if bool(re.search('platform.*/pci*', path)):
            path = os.path.relpath(path, 'platform')
        return path

    def get_phy_mac(self, interface):
        try:
            return subprocess.check_output("cat /sys/class/ieee80211/%s/macaddress" % self.get_phy_name(interface), shell=True).decode('ascii').rstrip()
        except:
            print("WARNING: Failed to determine MAC address for %s\n" % str(interface.get('device')))
            return "00:00:00:00:00:00"

    def get_device_id(self, interface):
        if os.path.islink("/sys/class/ieee80211/%s" % self.get_phy_name(interface)):
            return "option path '%s'" % self.get_phy_path(interface)
        else:
            return "option macaddr '%s'" % self.get_phy_mac(interface)

    def is_5ghz(self, interface):
        if interface.get('wirelessChannel') > 11:
            return True
        else:
            return False

    def has_5ghz(self, interface):
        return (0 == subprocess.call("iw phy %s info | grep -q '5180 MHz'" % self.get_phy_name(interface), shell=True))

    def has_2ghz(self, interface):
        return (0 == subprocess.call("iw phy %s info | grep -q '2412 MHz'" % self.get_phy_name(interface), shell=True))

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

    def write_country(self, file):
        country_code = board_util.get_country_code()
        if country_code != "":
            file.write("\toption country '%s'\n" % country_code)

    def write_macaddr(self, file, macaddr):
        if macaddr != "" and macaddr != None:
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
            if intf.get('type') == 'WIFI':
                file.write("config wifi-device 'radio%d'\n" % devidx)
                file.write("\toption type 'mac80211'\n")
                file.write("\toption channel '%s'\n" % intf['wirelessChannel'])
                file.write("\toption hwmode '%s'\n" % self.get_hwmode(intf))
                file.write("\t%s\n" % self.get_device_id(intf))
                thruput = intf.get('wirelessThroughput')
                if thruput == None or thruput == "" or thruput == "AUTO":
                    file.write("%s" % self.get_htmode(intf))
                else:
                    file.write("\toption htmode '%s'\n" % thruput)
                if not intf.get('enabled'):
                    file.write("\toption disabled '1'\n")
                else:
                    file.write("\toption disabled '0'\n")
                self.write_country(file)
                file.write("\n")
                file.write("config wifi-iface 'default_radio%d'\n" % devidx)
                file.write("\toption device 'radio%d'\n" % devidx)
                file.write("\toption ifname '%s'\n" % intf.get('device'))
                if intf.get('configType') == 'BRIDGED':
                    file.write("\toption network '%s'\n" % (network_util.get_bridge_name(settings, intf)))
                elif intf.get('configType') == 'ADDRESSED':
                    file.write("\toption network '%s'\n" % (network_util.get_interface_name(settings, intf)))
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

def enabled_wifi(intf):
    """returns true if the interface is an enabled wifi interface"""
    if intf.get('enabled') and intf.get('type') == 'WIFI':
        return True
    return False

registrar.register_manager(WirelessManager())
