import os
import sys
import subprocess
import datetime
import traceback
import time
import re
from sync import registrar,Manager

# This class is responsible for writing /etc/network/interfaces
# based on the settings object passed from sync-settings


class WirelessManager(Manager):
    wpasupplicant_conf_filename = "/etc/wpa_supplicant/wpa_supplicant.conf"
    hostapd_conf_filename = "/etc/hostapd/hostapd.conf"
    crda_default_filename = "/etc/default/crda"

    def initialize(self):
        registrar.register_settings_file("network", self)
        registrar.register_file(self.wpasupplicant_conf_filename+".*", "restart-networking", self)
        registrar.register_file(self.hostapd_conf_filename+".*", "restart-networking", self)
        registrar.register_file(self.crda_default_filename, "restart-networking", self)

    def sync_settings(self, settings_file, prefix, delete_list):

        # on Asus AC88U, find each disabled wifi interface, and remove
        # its corresponding hostapd configuration file if it
        # exists. untangle-broadcom-wireless relies solely on the
        # presence of that file to decide whether to start the AP
        # daemon or not (#13066)
        enabledInterfaces = [x['physicalDev'] for x in settings_file.settings.get('interfaces')]
        for intfName in [x for x in ('eth1', 'eth2') if not x in enabledInterfaces]:
            filename = prefix + self.hostapd_conf_filename + "-" + intfName
            if os.path.exists(filename):
                delete_list.append(filename)

        self.write_wpasupplicant_conf(settings_file.settings, prefix)
        self.write_hostapd_conf(settings_file.settings, prefix)
        self.write_crda_file(settings_file.settings, prefix)

        # 14.0 delete obsolete file (can be removed in 14.1)
        delete_list.append("/etc/untangle/pre-network-hook.d/990-restart-hostapd")

    # Much of the ht_capab and vht_capab logic shamelessly copied from openwrt:
    # https://dev.openwrt.org/browser/trunk/package/kernel/mac80211/files/lib/netifd/wireless/mac80211.sh
    # https://dev.openwrt.org/browser/trunk/package/kernel/mac80211/files/lib/wifi/mac80211.sh

    def get_iw_info(self, phy_dev):
        output = subprocess.Popen(("iw phy %s info" % phy_dev).split(), stdout=subprocess.PIPE, stderr=subprocess.STDOUT).communicate()[0]
        str = output.decode('ascii').split('\n')
        return str

    def set_hw_mode(self, conf, channel):
        if channel > 11 or channel == -2:
            conf['hw_mode'] = 'a'
        else:
            conf['hw_mode'] = 'g'
        return

    def set_fallback_ht_capab(self, conf, channel):
        ht_capabs = []
        if channel > 11 or channel == -2:
            if ((channel // 4) % 2) == 0:
                ht_capabs.append("[HT40-]")
            if ((channel // 4) % 2) == 1:
                ht_capabs.append("[HT40+]")
        else:
            if channel < 7:
                ht_capabs.append("[HT40+]")
            else:
                ht_capabs.append("[HT40-]")

        ht_capabs.append("[SHORT-GI-40]")
        ht_capabs.append("[TX-STBC]")
        ht_capabs.append("[RX-STBC1]")
        ht_capabs.append("[DSSS_CCK-40]")
        conf['ht_capab'] = "".join(map(str, ht_capabs))

    def set_ht_capab(self, conf, iw_info, channel, wlan_dev):
        capab_line = None
        for line in iw_info:
            if re.search(r'\s*Capabilities:\s.*', line):
                capab_line = line
                break

        if capab_line == None:
            print("Unable to determine capabilities: %s\n" % wlan_dev)
            return set_fallback_ht_capab(conf, channel)

        segments = line.split()
        if len(segments) != 2:
            print("Unknown capabilities: %s\n" % line)
            return set_fallback_ht_capab(conf, channel)
        capab_int = None
        try:
            capab_int = int(segments[1], 16)
        except Exception as exc:
            print("Unknown capabilities: %s\n" % line)
            traceback.print_exc()
            return set_fallback_ht_capab(conf, channel)

        ht_capabs = []
        if channel > 11 or channel == -2:
            if ((channel // 4) % 2) == 0:
                ht_capabs.append("[HT40-]")
            if ((channel // 4) % 2) == 1:
                ht_capabs.append("[HT40+]")
        else:
            if channel < 7:
                ht_capabs.append("[HT40+]")
            else:
                ht_capabs.append("[HT40-]")
        if (capab_int & 0x1) == 0x1:
            ht_capabs.append("[LDPC]")
        if (capab_int & 0x10) == 0x10:
            ht_capabs.append("[GF]")
        if (capab_int & 0x20) == 0x20:
            ht_capabs.append("[SHORT-GI-20]")
        if (capab_int & 0x40) == 0x40:
            ht_capabs.append("[SHORT-GI-40]")
        if (capab_int & 0x80) == 0x80:
            ht_capabs.append("[TX-STBC]")
        if (capab_int & 0x300) == 0x100:
            ht_capabs.append("[RX-STBC1]")
        if (capab_int & 0x300) == 0x200:
            ht_capabs.append("[RX-STBC12]")
        if (capab_int & 0x300) == 0x300:
            ht_capabs.append("[RX-STBC123]")
        if (capab_int & 0x800) == 0x800:
            ht_capabs.append("[MAX-AMSDU-7935]")
        if (capab_int & 0x1000) == 0x1000:
            ht_capabs.append("[DSSS_CCK-40]")
        conf['ht_capab'] = "".join(map(str, ht_capabs))
        return

    def set_80211n(self, conf):
        conf['ieee80211n'] = 1
        conf['wmm_enabled'] = 1

    def set_80211ac(self, conf):
        conf['ieee80211ac'] = 1

    def set_vht(self, conf):
        # assume VHT40h
        # need some user options for VHT80
        conf['vht_oper_chwidth'] = 0

    def set_vht_capab(self, conf, iw_info, channel, wlan_dev):
        capab_line = None
        for line in iw_info:
            if re.search(r'\s*VHT Capabilities\s.*', line):
                capab_line = line
                break

        if capab_line == None:
            print("Unable to determine VHT capabilitiese: %s\n" % wlan_dev)
            return set_fallback_ht_capab(conf, channel)

        segments = line.split()
        if len(segments) != 3:
            print("Unknown VHT capabilities: %s\n" % line)
            return set_fallback_ht_capab(conf, channel)
        capab_str = segments[2]
        capab_str = re.sub('[\(\):]', '', capab_str)
        capab_int = None
        try:
            capab_int = int(capab_str, 16)
        except Exception as exc:
            print("Unknown VHT capabilities: %s\n" % line)
            traceback.print_exc()
            return set_fallback_ht_capab(conf, channel)

        ht_capabs = []
        if (capab_int & 0x10) == 0x10:
            ht_capabs.append("[RXLDPC]")
        if (capab_int & 0x20) == 0x20:
            ht_capabs.append("[SHORT-GI-80]")
        if (capab_int & 0x40) == 0x40:
            ht_capabs.append("[SHORT-GI-160]")
        if (capab_int & 0x80) == 0x80:
            ht_capabs.append("[TX-STBC-2BY1]")
        if (capab_int & 0x800) == 0x800:
            ht_capabs.append("[SU-BEAMFORMER]")
        if (capab_int & 0x1000) == 0x1000:
            ht_capabs.append("[SU-BEAMFORMEE]")
        if (capab_int & 0x80000) == 0x80000:
            ht_capabs.append("[MU-BEAMFORMER]")
        if (capab_int & 0x100000) == 0x100000:
            ht_capabs.append("[MU-BEAMFORMEE]")
        if (capab_int & 0x200000) == 0x200000:
            ht_capabs.append("[VHT-TXOP-PS]")
        if (capab_int & 0x400000) == 0x400000:
            ht_capabs.append("[HTC-VHT]")
        if (capab_int & 0x10000000) == 0x10000000:
            ht_capabs.append("[RX-ANTENNA-PATTERN]")
        if (capab_int & 0x20000000) == 0x20000000:
            ht_capabs.append("[TX-ANTENNA-PATTERN]")
        if (capab_int & 0x700) == 0x100:
            ht_capabs.append("[RX-STBC1]")
        if (capab_int & 0x700) == 0x200:
            ht_capabs.append("[RX-STBC12]")
        if (capab_int & 0x700) == 0x300:
            ht_capabs.append("[RX-STBC123]")
        if (capab_int & 0x700) == 0x400:
            ht_capabs.append("[RX-STBC1234]")
        conf['vht_capab'] = "".join(map(str, ht_capabs))
        return

    def find_string(self, iw_info, regex):
        for line in iw_info:
            if re.search(regex, line):
                return True
        return False

    def supports_80211ac(self, channel, iw_info):
        # if a 2.4 channel is chosen - then its 2.4 which does not support AC
        if channel > 0 and channel <= 11:
            return False
        # channel -1 means 2.4 auto
        if channel == -1:
            return False
        if not self.find_string(iw_info, r'\s*VHT Capabilities.*'):
            return False
        if not self.find_string(iw_info, r'\s*Band 2.*'):
            return False
        return True

    def get_wificard_config(self, wlan_dev, channel):
        try:
            conf = {}
            phy_dev = open('/sys/class/net/%s/phy80211/name' % wlan_dev, 'r').read()
            iw_info = self.get_iw_info(phy_dev)

            self.set_hw_mode(conf, channel)
            self.set_80211n(conf)
            self.set_ht_capab(conf, iw_info, channel, wlan_dev)

            if self.supports_80211ac(channel, iw_info):
                self.set_80211ac(conf)
                self.set_vht(conf)
                self.set_vht_capab(conf, iw_info, channel, wlan_dev)

            return conf
        except Exception as exc:
            print("Unexpected error:", sys.exc_info()[0])
            traceback.print_exc()
            return None

    def write_hostapd_conf(self, settings, prefix=""):

        configFilename = prefix + self.hostapd_conf_filename
        for filename in [configFilename]:
            file_dir = os.path.dirname(filename)
            if not os.path.exists(file_dir):
                os.makedirs(file_dir)

        interfaces = settings.get('interfaces')

        for intf in interfaces:
            if intf.get('isWirelessInterface') and intf.get('wirelessMode') == 'AP':
                passwordLen = 0
                if intf.get('wirelessPassword') != None:
                    passwordLen = len(intf.get('wirelessPassword'))
                if passwordLen < 8:
                    print("WirelessManager: Ignoring " + intf.get('systemDev') + " because password is too short (" + str(passwordLen) + ")")
                    continue

                filename = configFilename + "-" + intf.get('systemDev')
                self.hostapdConfFile = open(filename, "w+")

                self.hostapdConfFile.write("## Auto Generated\n")
                self.hostapdConfFile.write("## DO NOT EDIT. Changes will be overwritten.\n")
                self.hostapdConfFile.write("\n\n")
                self.hostapdConfFile.write("interface=%s\n" % intf.get('systemDev'))
                self.hostapdConfFile.write("ssid=%s\n" % intf.get('wirelessSsid'))
                self.hostapdConfFile.write("country_code=US\n")
                self.hostapdConfFile.write("max_num_sta=255\n")
                self.hostapdConfFile.write("auth_algs=1\n")
                self.hostapdConfFile.write("ignore_broadcast_ssid=%u\n" % intf.get('wirelessVisibility'))

                channel = intf.get('wirelessChannel')

                # Channel will be -1 for 2.4 GHz Auto and -2 for 5 GHz Auto
                # hostapd expect the channel to be 0 for auto channel selection
                if channel < 0:
                    channel = 0

                self.hostapdConfFile.write("channel=%u\n" % channel)
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

                # build the card specific hostapd config
                conf = self.get_wificard_config(intf.get('systemDev'), intf.get('wirelessChannel'))
                if conf != None:
                    for key, value in sorted(conf.items()):
                        self.hostapdConfFile.write("%s=%s\n" % (str(key), str(value)))

                self.hostapdConfFile.flush()
                self.hostapdConfFile.close()

                print("WirelessManager: Wrote " + filename)

    def write_wpasupplicant_conf(self, settings, prefix=""):

        configFilename = prefix + self.wpasupplicant_conf_filename
        for filename in [configFilename]:
            fileDir = os.path.dirname(filename)
            if not os.path.exists(fileDir):
                os.makedirs(fileDir)

        interfaces = settings.get('interfaces')

        for intf in interfaces:
            if intf.get('isWirelessInterface') and intf.get('wirelessMode') == 'CLIENT':
                passwordLen = 0
                if intf.get('wirelessPassword') != None:
                    passwordLen = len(intf.get('wirelessPassword'))
                if passwordLen < 8:
                    print("WirelessManager: Ignoring " + intf.get('systemDev') + " because password is too short (" + str(passwordLen) + ")")
                    continue

                filename = configFilename + "-" + intf.get('systemDev')
                self.wpasupplicantConfFile = open(filename, "w+")

                self.wpasupplicantConfFile.write("## Auto Generated\n")
                self.wpasupplicantConfFile.write("## DO NOT EDIT. Changes will be overwritten.\n")
                self.wpasupplicantConfFile.write("\n\n")
                self.wpasupplicantConfFile.write("ctrl_interface=/run/wpa_supplicant\n")
                self.wpasupplicantConfFile.write("update_config=1\n")
                self.wpasupplicantConfFile.write("network={\n")
                self.wpasupplicantConfFile.write("\tssid=\"%s\"\n" % intf.get('wirelessSsid'))

                if intf.get('wirelessEncryption') == 'NONE':
                    self.wpasupplicantConfFile.write("\tkey_mgmt=NONE\n")
                elif intf.get('wirelessEncryption') == 'WPA1':
                    self.wpasupplicantConfFile.write("\tproto=WPA\n")
                    self.wpasupplicantConfFile.write("\tkey_mgmt=WPA-PSK\n")
                    self.wpasupplicantConfFile.write("\tpairwise=TKIP CCMP\n")
                    self.wpasupplicantConfFile.write("\tgroup=TKIP CCMP\n")
                    self.wpasupplicantConfFile.write("\tpsk=\"%s\"\n" % intf.get('wirelessPassword'))
                elif intf.get('wirelessEncryption') == 'WPA12':
                    self.wpasupplicantConfFile.write("\tproto=WPA RSN\n")
                    self.wpasupplicantConfFile.write("\tkey_mgmt=WPA-PSK\n")
                    self.wpasupplicantConfFile.write("\tpairwise=TKIP CCMP\n")
                    self.wpasupplicantConfFile.write("\tgroup=TKIP CCMP\n")
                    self.wpasupplicantConfFile.write("\tpsk=\"%s\"\n" % intf.get('wirelessPassword'))
                elif intf.get('wirelessEncryption') == 'WPA2':
                    self.wpasupplicantConfFile.write("\tproto=RSN\n")
                    self.wpasupplicantConfFile.write("\tkey_mgmt=WPA-PSK\n")
                    self.wpasupplicantConfFile.write("\tpairwise=TKIP CCMP\n")
                    self.wpasupplicantConfFile.write("\tgroup=TKIP CCMP\n")
                    self.wpasupplicantConfFile.write("\tpsk=\"%s\"\n" % intf.get('wirelessPassword'))

                self.wpasupplicantConfFile.write("}\n")

                self.wpasupplicantConfFile.flush()
                self.wpasupplicantConfFile.close()

                print("WirelessManager: Wrote " + filename)

    def write_crda_file(self, settings, prefix=""):
        crdaFilename = prefix + self.crda_default_filename
        for filename in [crdaFilename]:
            file_dir = os.path.dirname(filename)
            if not os.path.exists(file_dir):
                os.makedirs(file_dir)

        # FIXME need to get regulatory domain from the UI
        self.crdaDefaultFile = open(crdaFilename, "w+")
        self.crdaDefaultFile.write("## Auto Generated\n")
        self.crdaDefaultFile.write("## DO NOT EDIT. Changes will be overwritten.\n")
        self.crdaDefaultFile.write("REGDOMAIN=US\n")
        self.crdaDefaultFile.flush()
        self.crdaDefaultFile.close()

        print("WirelessManager: Wrote " + crdaFilename)

        return


registrar.register_manager(WirelessManager())
