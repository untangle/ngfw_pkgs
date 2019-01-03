import os
import stat
import sys
import subprocess
import datetime
import traceback
from sync import registrar
from sync import network_util
from sync import board_util

# This class is responsible for writing /etc/config/network
# based on the settings object passed from sync-settings


class NetworkManager:
    network_filename = "/etc/config/network"
    GREEK_NAMES = ["alpha", "beta", "gamma", "delta", "epsilon", "zeta", "eta", "theta", "iota", "kappa", "lambda", "mu"]

    def initialize(self):
        registrar.register_file(self.network_filename, "restart-networking", self)

    def sanitize_settings(self, settings):
        pass

    def validate_settings(self, settings):
        pass

    def create_settings(self, settings, prefix, delete_list, filename):
        print("%s: Initializing settings" % self.__class__.__name__)
        network = {}
        network['interfaces'] = []
        settings['network'] = network

        self.create_settings_devices(settings, prefix, delete_list)
        self.create_settings_interfaces(settings, prefix, delete_list)
        self.create_settings_switches(settings, prefix, delete_list)

    def sync_settings(self, settings, prefix, delete_list):
        self.write_network_file(settings, prefix)

    def write_network_file(self, settings, prefix=""):
        filename = prefix + self.network_filename
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        self.network_file = open(filename, "w+")
        file = self.network_file
        file.write("## Auto Generated\n")
        file.write("## DO NOT EDIT. Changes will be overwritten.\n")

        file.write("\n")
        file.write("config interface 'loopback'\n")
        file.write("\t" + "option ifname 'lo'\n")
        file.write("\t" + "option proto 'static'\n")
        file.write("\t" + "option ipaddr '127.0.0.1'\n")
        file.write("\t" + "option netmask '255.0.0.0'\n")

        file.write("\n")
        file.write("config globals 'globals'" + "\n")
        file.write("\t" + "option ula_prefix 'fdf1:ab86:f5ab::/48'" + "\n")

        interfaces = settings['network']['interfaces']
        for intf in interfaces:
            is_bridge = False
            bridged_interfaces_str = []
            bridged_interfaces = []
            for intf2 in interfaces:
                if intf2.get('configType') == 'BRIDGED' and intf2.get('bridgedTo') == intf.get('interfaceId'):
                    bridged_interfaces_str.append(str(intf2.get('device')))
                    bridged_interfaces.append(intf2)
            if len(bridged_interfaces) > 0:
                is_bridge = True
                bridged_interfaces_str.insert(0, intf.get('device'))  # include yourself in bridge at front
                bridged_interfaces.insert(0, intf)  # include yourself in bridge at front
            intf['is_bridge'] = is_bridge
            if is_bridge:
                intf['bridged_interfaces_str'] = bridged_interfaces_str
                intf['bridged_interfaces'] = bridged_interfaces

            if intf.get('is_bridge'):
                intf['logical_name'] = "b_" + intf['name']
                intf['ifname'] = intf['logical_name']
            else:
                intf['logical_name'] = intf['name']
                intf['ifname'] = intf.get('device')

        for intf in interfaces:
            intf['netfilterDev'] = intf['device']
            if intf.get('configType') != "DISABLED":
                self.write_interface_bridge(intf, settings)
                self.write_interface_v4(intf, settings)
                self.write_interface_v6(intf, settings)

        switches = settings['network'].get('switches')
        if switches != None:
            for swi in switches:
                self.write_switch(swi, settings)

        self.write_route_rules(settings)

        file.flush()
        file.close()

        print("%s: Wrote %s" % (self.__class__.__name__, filename))

    def write_route_rules(self, settings):
        priority = 70000
        file = self.network_file
        file.write("\n")

        interfaces = settings['network']['interfaces']
        for intf in interfaces:
            if intf.get('wan') and intf.get('configType') != "DISABLED" and intf.get('v4ConfigType') != "DISABLED":
                file.write("config rule\n")
                file.write("\toption mark '0x%x00/0xff00'\n" % intf.get('interfaceId'))
                file.write("\toption priority '%d'\n" % priority)
                file.write("\toption lookup 'wan.%d'\n" % intf.get('interfaceId'))
                file.write("\n")
                priority = priority + 1

        return

    def write_switch(self, swi, settings):
        file = self.network_file

        file.write("\n")
        file.write("config switch\n")
        file.write("\toption name '%s'\n" % swi['name'])
        file.write("\toption reset '1'\n")
        file.write("\toption enable_vlan '1'\n")
        file.write("\n")
        vlan_list = swi['vlans']
        for vlan in vlan_list:
            file.write("config switch_vlan\n")
            file.write("\toption device '%s'\n" % swi['name'])
            file.write("\toption vlan '%s'\n" % vlan['id'])
            vlan_ports = []
            for port in swi['ports']:
                if port['pvid'] == vlan['id']:
                    if port['cpu_port'] == True:
                        vlan_ports.append("%st" % port['id'])
                    else:
                        vlan_ports.append("%s" % port['id'])
            file.write("\toption ports '%s'\n" % " ".join(vlan_ports))
            file.write("\n")

        return

    def write_interface_bridge(self, intf, settings):
        if intf.get('configType') != "ADDRESSED":
            return
        if not intf.get('is_bridge'):
            return
        # find interfaces bridged to this interface
        file = self.network_file

        file.write("\n")
        file.write("config interface '%s'\n" % intf['logical_name'])
        file.write("\toption type 'bridge'\n")
        file.write("\toption ifname '%s'\n" % " ".join(intf.get('bridged_interfaces_str')))
        # In some cases netifd handles it better if the ipv4 config is written under the main
        # bridge interface instead of the first alias
        # To do so uncomment this line and disable writing of the first alias
        # This is commented out for now to see if treating bridges normally works
        # If so, this should be removed
        # self.write_interface_v4_config(intf, settings)

        return

    def write_interface_v4(self, intf, settings):
        """
        Writes a new logical interface containing the IPv4 configuration
        """
        if intf.get('configType') != "ADDRESSED":
            return
        if intf.get('v4ConfigType') == "DISABLED":
            return
        # If this interface is a bridge-master
        # the IPv4 config would have been written in the bridge interface
        # This is commented out for now to see if treating bridges normally works
        # If so, this should be removed
        # if intf.get('is_bridge'):
        #     return

        file = self.network_file

        file.write("\n")
        file.write("config interface '%s'\n" % (intf['logical_name']+"4"))
        if intf.get('is_bridge'):
            # https://wiki.openwrt.org/doc/uci/network#aliasesthe_new_way
            # documentation says to use "br-" plus logical name
            file.write("\toption ifname '%s'\n" % ("br-"+intf['ifname']))
        else:
            file.write("\toption ifname '%s'\n" % intf['ifname'])
        self.write_macaddr(file, intf.get('macaddr'))
        self.write_interface_v4_config(intf, settings)

        if intf.get('v4Aliases') != None and intf.get('v4ConfigType') == "STATIC":
            for idx, alias in enumerate(intf.get('v4Aliases')):
                self.write_interface_v4_alias(intf, alias, (idx+1), settings)

        return

    def write_interface_v4_config(self, intf, settings):
        """
        Writes the actual IPv4 configuration options for an interface
        This is a separate function because depending on the configuration this may be written in different locations
        """
        file = self.network_file

        if intf.get('v4ConfigType') == "DHCP":
            if not intf.get('wan'):
                raise Exception('Invalid v4ConfigType: Can not use DHCP on non-WAN interfaces')
            file.write("\toption proto 'dhcp'\n")
        elif intf.get('v4ConfigType') == "STATIC":
            file.write("\toption proto 'static'\n")
            file.write("\toption force_link '0'\n")
            file.write("\toption ipaddr '%s'\n" % intf.get('v4StaticAddress'))
            file.write("\toption netmask '%s'\n" % network_util.ipv4_prefix_to_netmask(intf.get('v4StaticPrefix')))
            if intf.get('wan') and intf.get('v4StaticGateway') != None:
                file.write("\toption gateway '%s'\n" % intf.get('v4StaticGateway'))
        elif intf.get('v4ConfigType') == "PPPOE":
            if not intf.get('wan'):
                raise Exception('Invalid v4ConfigType: Can not use PPPOE on non-WAN interfaces')
            file.write("\toption proto 'pppoe'\n")
            # FIXME
            # If its PPPoE the "netfilterDev" is the actual device that netfilter rules should match on
            # In this case we need to set 'netfilterDev' to 'pppX' so subsequent modules know the proper
            # netfilter device to use
            # intf['netfilterDev'] = ppp0

        elif intf.get('v4ConfigType') == "DISABLED":
            # This needs to be written for addressless bridges
            file.write("\toption proto 'none'\n")
            file.write("\toption auto '1'\n")

        if intf.get('wan') and intf.get('v4ConfigType') != "DISABLED":
            file.write("\toption ip4table 'wan.%d'\n" % intf.get('interfaceId'))

        return

    def write_interface_v4_alias(self, intf, alias, count, settings):
        """
        Write an IPv4 alias interface
        """
        file = self.network_file

        file.write("\n")
        file.write("config interface '%s'\n" % (intf['logical_name']+"4"+"_"+str(count)))
        if intf.get('is_bridge'):
            # https://wiki.openwrt.org/doc/uci/network#aliasesthe_new_way
            # documentation says to use "br-" plus logical name
            file.write("\toption ifname '%s'\n" % ("br-"+intf['ifname']))
        else:
            file.write("\toption ifname '%s'\n" % intf['ifname'])
        file.write("\toption proto 'static'\n")
        file.write("\toption ipaddr '%s'\n" % alias.get('v4Address'))
        file.write("\toption netmask '%s'\n" % network_util.ipv4_prefix_to_netmask(alias.get('v4Prefix')))

    def write_interface_v6(self, intf, settings):
        """
        Writes a new logical interface containing the IPv6 configuration
        """
        if intf.get('configType') != "ADDRESSED":
            return
        if intf.get('v6ConfigType') == "DISABLED":
            return
        file = self.network_file
        file.write("\n")
        file.write("config interface '%s'\n" % (intf['logical_name']+"6"))
        if intf.get('is_bridge'):
            # https://wiki.openwrt.org/doc/uci/network#aliasesthe_new_way
            # documentation says to use "br-" plus logical name
            file.write("\toption ifname '%s'\n" % ("br-"+intf['ifname']))
        else:
            file.write("\toption ifname '%s'\n" % intf['ifname'])
        self.write_macaddr(file, intf.get('macaddr'))

        if intf.get('v6ConfigType') == "DHCP":
            file.write("\toption proto 'dhcpv6'\n")
        elif intf.get('v6ConfigType') == "SLAAC":
            # FIXME
            pass
        elif intf.get('v6ConfigType') == "ASSIGN":
            file.write("\toption proto 'static'\n")
            file.write("\toption ip6assign '%s'\n" % intf.get('v6AssignPrefix'))
            file.write("\toption ip6hint '%s'\n" % intf.get('v6AssignHint'))
        elif intf.get('v6ConfigType') == "STATIC":
            if intf.get('v6StaticAddress') != None and intf.get('v6StaticPrefix') != None:
                file.write("\toption proto 'static'\n")
                file.write("\toption ip6addr '%s'\n" % intf.get('v6StaticAddress'))
                file.write("\toption ip6prefix '%s'\n" % intf.get('v6StaticPrefix'))
                if intf.get('wan') and intf.get('v6StaticGateway') != None:
                    file.write("\toption ip6gw '%s'\n" % intf.get('v6StaticGateway'))

        if intf.get('v6Aliases') != None and intf.get('v6ConfigType') == "STATIC":
            for idx, alias in enumerate(intf.get('v6Aliases')):
                self.write_interface_v6_alias(intf, alias, (idx+1), settings)

        return

    def write_interface_v6_alias(self, intf, alias, count, settings):
        """
        Write an IPv6 alias interface
        """
        file = self.network_file

        file.write("\n")
        file.write("config interface '%s'\n" % (intf['logical_name']+"6"+"_"+str(count)))
        file.write("\toption ifname '%s'\n" % intf['ifname'])
        file.write("\toption proto 'static'\n")
        file.write("\toption ip6addr '%s'\n" % alias.get('v6Address'))
        file.write("\toption ip6prefix '%s'\n" % alias.get('v6Prefix'))

    def create_settings_devices(self, settings, prefix, delete_list):
        device_list = get_devices()
        settings['network']['devices'] = []
        for dev in device_list:
            settings['network']['devices'].append(new_device_settings(dev))

    def create_settings_interfaces(self, settings, prefix, delete_list):
        device_list = get_devices()
        if len(device_list) == 1:
            internal_device_name = "None"
            external_device_name = device_list[0]
        else:
            internal_device_name = board_util.get_internal_device_name()
            external_device_name = board_util.get_external_device_name()

        # Move wan to top of list, in OpenWRT eth1 is the WAN
        if external_device_name in device_list:
            device_list.remove(external_device_name)
            device_list.insert(0, external_device_name)
        settings['network']['interfaces'] = []
        interface_list = []
        intf_id = 0
        for dev in settings['network']['devices']:
            intf_id = intf_id + 1
            interface = {}
            interface['interfaceId'] = intf_id
            interface['device'] = dev['name']

            if interface['device'] in board_util.get_hidden_interfaces():
                interface['hidden'] = True
            else:
                interface['hidden'] = False

            interface['downloadKbps'] = 0
            interface['uploadKbps'] = 0
            interface['wanWeight'] = 0
            interface['macaddr'] = board_util.get_interface_macaddr(interface['device'])

            if dev.get('name') == internal_device_name:
                interface['name'] = 'internal'
                interface['type'] = 'NIC'
                interface['wan'] = False
                interface['configType'] = 'ADDRESSED'
                interface['v4ConfigType'] = 'STATIC'
                interface['v4StaticAddress'] = '192.168.1.1'
                interface['v4StaticPrefix'] = 24
                interface['dhcpEnabled'] = True
                interface['dhcpRangeStart'] = '192.168.1.100'
                interface['dhcpRangeEnd'] = '192.168.1.200'
                interface['dhcpLeaseDuration'] = 60*60
                interface['v6ConfigType'] = 'ASSIGN'
                interface['v6AssignPrefix'] = 64
                interface['v6AssignHint'] = '1234'
            elif dev.get('name') == external_device_name:
                interface['name'] = 'external'
                interface['type'] = 'NIC'
                interface['wan'] = True
                interface['configType'] = 'ADDRESSED'
                interface['v4ConfigType'] = 'DHCP'
                interface['v6ConfigType'] = 'DHCP'
                interface['natEgress'] = True
            else:
                interface['type'] = 'NIC'
                interface['wan'] = False
                interface['configType'] = 'DISABLED'
                try:
                    interface['name'] = self.GREEK_NAMES[intf_id]
                except:
                    interface['name'] = "intf%i" % intf_id

            interface_list.append(interface)
        settings['network']['interfaces'] = interface_list

    def write_macaddr(self, file, macaddr):
        if macaddr != "":
            file.write("\toption macaddr '%s'\n" % macaddr)

    def create_settings_switches(self, settings, prefix, delete_list):
        settings['network']['switches'] = board_util.get_switch_settings()

def get_wireless_devices():
    device_list = []
    devices = subprocess.check_output("find /sys/class/ieee80211 -type l -name 'phy*' | sed -e 's|/sys/class/ieee80211/||' | sort", shell=True).decode('ascii')
    for dev in devices.splitlines():
        if dev:
            device_list.append(dev.replace("phy", "wlan"))
    return device_list

def get_devices():
    device_list = []
    device_list.extend(get_devices_matching_glob("eth*"))
    device_list.extend(get_devices_matching_glob("lan*"))
    device_list.extend(get_devices_matching_glob("wan*"))
    device_list.extend(get_wireless_devices())
    return device_list


def get_devices_matching_glob(glob):
    device_list = []
    devices = subprocess.check_output("find /sys/class/net -type l -name '%s' | sed -e 's|/sys/class/net/||' | sort" % glob, shell=True).decode('ascii')
    for dev in devices.splitlines():
        if dev:
            device_list.append(dev)
    return device_list


def new_device_settings(devname):
    return {
        "name": devname,
        "duplex": "AUTO",
        "mtu": None
    }


registrar.register_manager(NetworkManager())
