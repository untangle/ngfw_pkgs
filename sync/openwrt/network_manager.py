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
    GREEK_NAMES = ["alpha","beta","gamma","delta","epsilon","zeta","eta","theta","iota","kappa","lambda","mu"];

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
        file = self.network_file
        file.write("## Auto Generated\n");
        file.write("## DO NOT EDIT. Changes will be overwritten.\n");

        file.write("\n");
        file.write("config interface 'loopback'\n");
        file.write("\t" + "option ifname 'lo'\n");
        file.write("\t" + "option proto 'static'\n");
        file.write("\t" + "option ipaddr '127.0.0.1'\n");
        file.write("\t" + "option netmask '255.0.0.0'\n");

        file.write("\n");
        file.write("config globals 'globals'" + "\n");
        file.write("\t" + "option ula_prefix 'fdf1:ab86:f5ab::/48'" + "\n");

        interfaces = settings['network']['interfaces']
        for intf in interfaces:
            is_bridge = False
            bridged_interfaces_str = []
            bridged_interfaces = []
            for intf2 in interfaces:
                if intf2.get('configType') == 'BRIDGED' and intf2.get('bridgedTo') == intf.get('interfaceId'):
                    bridged_interfaces_str.append(str(intf2.get('systemDev')))
                    bridged_interfaces.append(intf2)
            if len(bridged_interfaces) > 0:
                is_bridge = True
                bridged_interfaces_str.append(intf.get('systemDev')) # include yourself in bridge
                bridged_interfaces.append(intf) # include yourself in bridge
            # sort for consistent order
            bridged_interfaces_str.sort(key=lambda x: len(x))
            intf['is_bridge'] = is_bridge
            if is_bridge:
                intf['bridged_interfaces_str'] = bridged_interfaces_str
                intf['bridged_interfaces'] = bridged_interfaces
            
        for intf in interfaces:
            self.write_interface_v4(intf, settings)
        for intf in interfaces:
            self.write_interface_v6(intf, settings)
        
        file.flush()
        file.close()
        
        if verbosity > 0:
            print("%s: Wrote %s" % (self.__class__.__name__,filename))

    def write_interface_v6( self, intf, settings ):
        # find interfaces bridged to this interface
        file = self.network_file

        # Only write IPv6 configs for interfaces that are addressed and WAN
        # Non-WAN IPv6 interfaces just need an ip6assign which is handled in write_interface_v4
        if intf.get('configType') != "ADDRESSED" or intf.get('v6ConfigType') == "DISABLED":
            return
        if not intf.get('wan'):
            return

        logical_name = intf['name']
        if intf.get('is_bridge'):
            logical_name = "br-" + logical_name + "-6"
        
        file.write("\n");
        file.write("config interface '%s'\n" % logical_name);
        if intf.get('is_bridge'):
            file.write("\toption ifname '%s'\n" % ("br-" + logical_name))
        else:
            file.write("\toption ifname '%s'\n" % intf.get('physicalDev'))
        if intf.get('v6ConfigType') == "AUTO":
            file.write("\toption proto 'dhcpv6'\n")
        elif intf.get('v6ConfigType') == "STATIC":
            file.write("\toption proto 'static'\n")
            file.write("\toption ip6addr '%s'\n" % intf.get('v6StaticAddress'))
            file.write("\toption ip6prefix '%s'\n" % intf.get('v6StaticPrefix'))
        return

    def write_interface_v4( self, intf, settings ):
        # find interfaces bridged to this interface
        file = self.network_file

        logical_name = intf['name']
        if intf.get('is_bridge'):
            logical_name = "br-" + logical_name 

        file.write("\n");
        file.write("config interface '%s'\n" % logical_name);
        if intf.get('is_bridge'):
            file.write("\toption type 'bridge'\n");
            file.write("\toption ifname '%s'\n" % " ".join(intf.get('bridged_interfaces_str')))
        else:
            file.write("\toption ifname '%s'\n" % intf.get('physicalDev'))
        if intf.get('configType') == "DISABLED":
            file.write("\toption proto 'none'\n")
        elif intf.get('configType') == "ADDRESSED":
            if intf.get('v4ConfigType') == "AUTO":
                file.write("\toption proto 'dhcp'\n")
            elif intf.get('v4ConfigType') == "STATIC":
                file.write("\toption proto 'static'\n")
                file.write("\toption ipaddr '%s'\n" % intf.get('v4StaticAddress'))
                file.write("\toption netmask '%s'\n" % intf.get('v4StaticNetmask'))
                file.write("\toption ip6assign '60'\n") # FIXME need setting for prefix number
            elif intf.get('v4ConfigType') == "PPPOE":
                file.write("\toption proto 'pppoe'\n")
                # FIXME
        return
                
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
                interface['name'] = 'internal'
                interface['wan'] = False
                interface['configType'] = 'ADDRESSED'
                interface['v4ConfigType'] = 'STATIC'
                interface['v4StaticAddress'] = '192.168.1.1'
                interface['v4StaticNetmask'] = '255.255.255.0'
                interface['v4StaticPrefix'] = 24
                interface['dhcpEnabled'] = True
                interface['dhcpRangeStart'] = '192.168.1.100'
                interface['dhcpRangeEnd'] = '192.168.1.200'
                interface['dhcpLeaseDuration'] = 60*60
                interface['v6ConfigType'] = 'AUTO'
            elif dev.get('name') == 'eth1':
                interface['name'] = 'external'
                interface['wan'] = True
                interface['configType'] = 'ADDRESSED'
                interface['v4ConfigType'] = 'AUTO'
                interface['v6ConfigType'] = 'DISABLED'
                interface['natEgress'] = True
            else:
                try:
                    interface['name'] = self.GREEK_NAMES[intf_id]
                except:
                    interface['name'] = "interface %i"%intf_id
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
