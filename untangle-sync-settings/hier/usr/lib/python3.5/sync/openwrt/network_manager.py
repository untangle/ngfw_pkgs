import os
import stat
import sys
import subprocess
import datetime
import traceback
from sync import registrar

# This class is responsible for writing /etc/config/network
# based on the settings object passed from sync-settings.py
class NetworkManager:
    network_filename = "/etc/config/network"
    GREEK_NAMES = ["Alpha","Beta","Gamma","Delta","Epsilon","Zeta","Eta","Theta","Iota","Kappa","Lambda","Mu"];

    def initialize( self ):
        registrar.register_file( self.network_filename, "restart-networking", self )

    def create_settings( self, settings, prefix, delete_list, verbosity=0 ):
        print("%s: Initializing settings" % self.__class__.__name__)
        network = {}
        network['interfaces'] = []
        settings['network'] = network

        self.create_settings_devices(settings, prefix, delete_list, verbosity)
        self.create_settings_interfaces(settings, prefix, delete_list, verbosity)
        
    def sync_settings( self, settings, prefix, delete_list, verbosity=0 ):
        self.write_network_file( settings, prefix, verbosity )
        
    def write_network_file( self, settings, prefix="", verbosity=0 ):
        filename = prefix + self.network_filename
        file_dir = os.path.dirname( filename )
        if not os.path.exists( file_dir ):
            os.makedirs( file_dir )

        self.network_file = open( filename, "w+" )
        self.network_file.write("## Auto Generated\n");
        self.network_file.write("## DO NOT EDIT. Changes will be overwritten.\n");
        self.network_file.write("\n\n");

        self.network_file.write("\n");
        self.network_file.write("config interface 'loopback'" + "\n");
        self.network_file.write("\t" + "option ifname 'lo'" + "\n");
        self.network_file.write("\t" + "option proto 'static'" + "\n");
        self.network_file.write("\t" + "option ipaddr '127.0.0.1'" + "\n");
        self.network_file.write("\t" + "option netmask '255.0.0.0'" + "\n");

        self.network_file.write("\n");
        self.network_file.write("config globals 'globals'" + "\n");
        self.network_file.write("\t" + "option ula_prefix 'fdf1:ab86:f5ab::/48'" + "\n");

        self.network_file.flush()
        self.network_file.close()
        
        if verbosity > 0:
            print("%s: Wrote %s" % (self.__class__.__name__,filename))

    def create_settings_devices( self, settings, prefix, delete_list, verbosity=0 ):
        device_list = get_devices()
        settings['network']['devices'] = []
        for dev in device_list:
            settings['network']['devices'].append(new_device_settings(dev))

    def create_settings_interfaces( self, settings, prefix, delete_list, verbosity=0 ):
        device_list = get_devices()
        # Move eth1 to top of list, in OpenWRT eth1 is the WAN
        if "eth1" in device_list:
            device_list.remove("eth1")
            device_list.insert(0,"eth1")
        settings['network']['interfaces'] = []
        interface_list = []
        intf_id = 0
        for dev in settings['network']['devices']:
            intf_id = intf_id + 1
            interface = {}
            interface['interfaceId'] = intf_id
            interface['physicalDev'] = dev['name']
            interface['systemDev'] = dev['name']
            interface['symbolicDev'] = dev['name']
            if dev.get('name').startswith("wlan"):
                interface['wireless'] = True
                interface['wirelessChannel'] = 6

            if dev.get('name') == 'eth0':
                interface['name'] = 'Internal'
                interface['wan'] = False
                interface['configType'] = 'ADDRESSED'
                interface['v4ConfigType'] = 'STATIC'
                interface['v4StaticAddress'] = '192.168.1.1'
                interface['v4StaticPrefix'] = 24
                interface['dhcpEnabled'] = True
                interface['dhcpRangeStart'] = '192.168.1.100'
                interface['dhcpRangeEnd'] = '192.168.1.200'
                interface['dhcpLeaseDuration'] = 60*60
                interface['v6ConfigType'] = 'AUTO'
            elif dev.get('name') == 'eth1':
                interface['name'] = 'External'
                interface['wan'] = True
                interface['configType'] = 'ADDRESSED'
                interface['v4ConfigType'] = 'AUTO'
                interface['v6ConfigType'] = 'DISABLED'
                interface['natEgress'] = True
            else:
                try:
                    interface['name'] = self.GREEK_NAMES[intf_id]
                except:
                    interface['name'] = "Interface %i"%intf_id
                interface['configType'] = 'DISABLED'

            interface_list.append(interface)
        settings['network']['interfaces'] = interface_list
                
            
def get_devices():
    device_list = []
    device_list.extend(get_devices_matching_glob("eth*"))
    device_list.extend(get_devices_matching_glob("wlan*"))
    return device_list

def get_devices_matching_glob(glob):
    device_list = []
    devices = subprocess.check_output("find /sys/class/net -type l -name '%s' | sed -e 's|/sys/class/net/||' | sort"%glob, shell=True).decode('ascii')
    for dev in devices.splitlines():
        if dev:
            device_list.append(dev)
    return device_list
    

def new_device_settings(devname):
    return {
        "name": devname,
        "duplex": "auto",
        "mtu": None
    }

registrar.register_manager(NetworkManager())
