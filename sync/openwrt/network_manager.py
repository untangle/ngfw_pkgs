"""network_manager manages /etc/config/network"""
# pylint: disable=unused-argument
# pylint: disable=no-self-use
# pylint: disable=too-many-statements
# pylint: disable=bare-except
# pylint: disable=too-many-branches
import os
import subprocess
import ipaddress
import re
from sync import registrar
from sync import network_util
from sync import board_util

class NetworkManager:
    """
    This class is responsible for writing /etc/config/network
    based on the settings object passed from sync-settings
    """
    GREEK_NAMES = ["alpha", "beta", "gamma", "delta", "epsilon", "zeta", "eta", "theta", "iota", "kappa", "lambda", "mu"]
    network_filename = "/etc/config/network"
    network_file = None

    def initialize(self):
        """initialize this module"""
        registrar.register_file(self.network_filename, "restart-networking", self)

    def sanitize_settings(self, settings):
        """sanitizes removes blank settings"""
        interfaces = settings.get('network').get('interfaces')
        # Remove all "" and 0 and null values
        for intf in interfaces:
            for k, v in dict(intf).items():
                if v == "":
                    del intf[k]
                if v == 0:
                    del intf[k]
                if intf.get(k, "missing") is None:
                    del intf[k]
            # The UI currently doesn't set wan = false for LANS
            # if it is not specified, assume its false
            if intf.get("wan") is None:
                intf["wan"] = False

    def validate_settings(self, settings):
        """validates settings"""
        interfaces = settings.get('network').get('interfaces')
        for intf in interfaces:
            validate_interface(intf)
            # TODO add mulit-setting validation:
            # for example:
            # if dhcp is enabled, dhcpStart and dhcpEnd are specified
            # etc
            # TODO add multi-interface validation:
            # for example:
            # if an interface is bridged its bridged to an interface that exists
            # a static interface doesn't have the same subnet as another static interface
            # etc

    def create_settings(self, settings, prefix, delete_list, filename):
        """creates settings"""
        print("%s: Initializing settings" % self.__class__.__name__)
        network = {}
        network['interfaces'] = []
        settings['network'] = network

        self.create_settings_devices(settings, prefix, delete_list)
        self.create_settings_interfaces(settings, prefix, delete_list)
        self.create_settings_switches(settings, prefix, delete_list)

    def sync_settings(self, settings, prefix, delete_list):
        """syncs settings"""
        self.write_network_file(settings, prefix)

    def write_network_file(self, settings, prefix=""):
        """write /etc/config/network"""
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
                # https://wiki.openwrt.org/doc/uci/network#aliasesthe_new_way
                # documentation says to use "br-" plus logical name
                intf['ifname'] = "br-" + intf['logical_name']
                intf['netfilterDev'] = intf['ifname']
            else:
                intf['logical_name'] = intf['name']
                intf['ifname'] = intf.get('device')
                intf['netfilterDev'] = intf['device']

        for intf in interfaces:
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
        """write the route rules"""
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
        """write the switch config"""
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
                    if port['cpu_port'] is True:
                        vlan_ports.append("%st" % port['id'])
                    else:
                        vlan_ports.append("%s" % port['id'])
            file.write("\toption ports '%s'\n" % " ".join(vlan_ports))
            file.write("\n")

        return

    def write_interface_bridge(self, intf, settings):
        """write a bridge interface"""
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
            if intf.get('v4DhcpAddressOverride') != None and intf.get('v4DhcpAddressOverride') != "":
                file.write("\toption ipaddr '%s'\n" % intf.get('v4DhcpAddressOverride'))
            if intf.get('v4DhcpDNS1Override') != None and intf.get('v4DhcpDNS1Override') != "" and intf.get('v4DhcpDNS2Override') != None and intf.get('v4DhcpDNS2Override') != "":
                file.write("\toption dns '%s %s'\n" % (intf.get('v4DhcpDNS1Override'), intf.get('v4DhcpDNS2Override')))
                file.write("\toption peerdns '0'\n")
            elif intf.get('v4DhcpDNS1Override') != None and intf.get('v4DhcpDNS1Override') != "":
                file.write("\toption dns '%s'\n" % intf.get('v4DhcpDNS1Override'))
                file.write("\toption peerdns '0'\n")
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
        file.write("\toption ifname '%s'\n" % intf['ifname'])
        self.write_macaddr(file, intf.get('macaddr'))

        if intf.get('v6ConfigType') == "DHCP":
            file.write("\toption proto 'dhcpv6'\n")
            if intf.get('v6DhcpDNS1Override') != None and intf.get('v6DhcpDNS2Override') != None:
                file.write("\toption dns '%s %s'\n" % (intf.get('v6DhcpDNS1Override'), intf.get('v6DhcpDNS2Override')))
                file.write("\toption peerdns '0'\n")
            elif intf.get('v6DhcpDNS1Override') != None:
                file.write("\toption dns '%s'\n" % intf.get('v6DhcpDNS1Override'))
                file.write("\toption peerdns '0'\n")
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
        """create device settings"""
        device_list = get_devices()
        settings['network']['devices'] = []
        for dev in device_list:
            settings['network']['devices'].append(new_device_settings(dev))

    def create_settings_interfaces(self, settings, prefix, delete_list):
        """create interfaces settings"""
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
        internal_id = None
        for dev in settings['network']['devices']:
            intf_id = intf_id + 1
            interface = {}
            interface['interfaceId'] = intf_id
            interface['device'] = dev['name']
            interface['hidden'] = (interface['device'] in board_util.get_hidden_interfaces())

            interface['downloadKbps'] = 0
            interface['uploadKbps'] = 0
            interface['wanWeight'] = 0
            interface['macaddr'] = board_util.get_interface_macaddr(interface['device'])

            if interface['device'].startswith("wlan"):
                interface['type'] = 'WIFI'
            else:
                interface['type'] = 'NIC'

            if dev.get('name') == internal_device_name:
                internal_id = intf_id
                interface['name'] = 'internal'
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
                interface['wan'] = True
                interface['configType'] = 'ADDRESSED'
                interface['v4ConfigType'] = 'DHCP'
                interface['v6ConfigType'] = 'DHCP'
                interface['natEgress'] = True
            else:
                interface['wan'] = False
                if intf_id < len(self.GREEK_NAMES):
                    interface['name'] = self.GREEK_NAMES[intf_id]
                else:
                    interface['name'] = "intf%i" % intf_id
                if internal_id != None and (dev.get('name').startswith('wlan') or dev.get('name').startswith('lan')):
                    interface['configType'] = 'BRIDGED'
                    interface['bridgedTo'] = internal_id
                else:
                    interface['configType'] = 'DISABLED'

            interface_list.append(interface)
        settings['network']['interfaces'] = interface_list

    def write_macaddr(self, file, macaddr):
        """write macaddr option"""
        if macaddr != "":
            file.write("\toption macaddr '%s'\n" % macaddr)

    def create_settings_switches(self, settings, prefix, delete_list):
        """create switches config"""
        settings['network']['switches'] = board_util.get_switch_settings()

def get_wireless_devices():
    """get wireless devices"""
    device_list = []
    devices = subprocess.check_output("find /sys/class/ieee80211 -type l -name 'phy*' | sed -e 's|/sys/class/ieee80211/||' | sort", shell=True).decode('ascii')
    for dev in devices.splitlines():
        if dev:
            device_list.append(dev.replace("phy", "wlan"))
    return device_list

def get_devices():
    """get devices"""
    device_list = []
    device_list.extend(get_devices_matching_glob("eth*"))
    device_list.extend(get_devices_matching_glob("lan*"))
    device_list.extend(get_devices_matching_glob("wan*"))
    device_list.extend(get_wireless_devices())
    return device_list


def get_devices_matching_glob(glob):
    """get devices matching the specified glob"""
    device_list = []
    devices = subprocess.check_output("find /sys/class/net -type l -name '%s' | sed -e 's|/sys/class/net/||' | sort" % glob, shell=True).decode('ascii')
    for dev in devices.splitlines():
        if dev:
            device_list.append(dev)
    return device_list

def new_device_settings(devname):
    """get new device settings"""
    return {
        "name": devname,
        "duplex": "AUTO",
        "mtu": None
    }

def valid_ipv4(address, accept_none=False):
    """returns true if address (string) is a valid IPv4 address"""
    if address is None and accept_none:
        return True
    try:
        ipaddress.IPv4Address(address)
        return True
    except:
        return False

def valid_ipv6(address, accept_none=False):
    """returns true if address (string) is a valid IPv4 address"""
    if address is None and accept_none:
        return True
    try:
        ipaddress.IPv6Address(address)
        return True
    except:
        return False

def validate_interface(intf):
    """validates that each field within an interface makes sense individually"""
    # If the interface is disabled, don't bother verifying attributes
    if intf.get("configType") == "DISABLED":
        return
    for required_key in ["interfaceId", "name", "wan", "device", "type", "configType"]:
        if required_key not in intf:
            raise Exception("Missing required attribute: " + intf.get('name') + " " + required_key)

    for ipv4_key in ["v4StaticAddress", "v4StaticGateway", "v4StaticDNS1", "v4StaticDNS2", "v4DhcpAddressOverride", "v4DhcpGatewayOverride", "v4DhcpDNS1Override", "v4DhcpDNS2Override", "v4PPPoEOverrideDNS1", "v4PPPoEOverrideDNS2", "dhcpRangeStart", "dhcpRangeEnd", "dhcpGatewayOverride", "dhcpDNSOverride"]:
        if not valid_ipv4(intf.get(ipv4_key), accept_none=True):
            raise Exception("Invalid IPv4 Address: " + intf.get('name') + " " + ipv4_key + " = " + intf.get(ipv4_key))

    for ipv6_key in ["v6StaticAddress", "v6StaticGateway", "v6StaticDNS1", "v6StaticDNS2", "v6DhcpDNS1Override", "v6DhcpDNS2Override"]:
        if not valid_ipv6(intf.get(ipv6_key), accept_none=True):
            raise Exception("Invalid IPv6 Address: " + intf.get('name') + " " + ipv6_key + " = " + intf.get(ipv6_key))

    for ipv4_prefix_key in ["v4StaticPrefix", "v4DhcpPrefixOverride", "dhcpPrefixOverride"]:
        if intf.get(ipv4_prefix_key) != None and (intf.get(ipv4_prefix_key) < 1 or intf.get(ipv4_prefix_key) > 32):
            raise Exception("Invalid IPv4 Prefix: " + intf.get('name') + " " + ipv4_prefix_key + " = " + intf.get(ipv4_prefix_key))

    for ipv6_prefix_key in ["v6StaticPrefix", "v6AssignPrefix"]:
        if intf.get(ipv6_prefix_key) != None and (intf.get(ipv6_prefix_key) < 1 or intf.get(ipv6_prefix_key) > 128):
            raise Exception("Invalid IPv6 Prefix: " + intf.get('name') + " " + ipv6_prefix_key + " = " + intf.get(ipv6_prefix_key))

    # check individual settings
    if intf.get("v4ConfigType") not in [None, "STATIC", "DHCP", "DISABLED"]:
        raise Exception("Invalid v4ConfigType: " + intf.get('name') + " " + intf.get("v4ConfigType"))

    if intf.get("v4_aliases") != None:
        for v4_alias in intf.get("v4_aliases"):
            if not valid_ipv4(v4_alias.get("v4Address")):
                raise Exception("Invalid IPv4 Alias Address: " + intf.get('name') + " " + v4_alias.get("v4Address"))
            if v4_alias.get("v4Prefix") < 1 or v4_alias.get("v4Prefix") > 32:
                raise Exception("Invalid IPv4 Alias Prefix: " + intf.get('name') + " " + v4_alias.get("v4Prefix"))

    if intf.get("v4PPPoEUsername") != None and not isinstance(intf.get("v4PPPoEUsername"), str):
        raise Exception("Invalid PPPoE Username: " + intf.get('name') + " " + intf.get("v4PPPoEUsername"))

    if intf.get("v4PPPoEPassword") != None and not isinstance(intf.get("v4PPPoEPassword"), str):
        raise Exception("Invalid PPPoE Password: " + intf.get('name') + " " + intf.get("v4PPPoEPassword"))

    if intf.get("v4PPPoEUsePeerDNS") != None and not isinstance(intf.get("v4PPPoEUsePeerDNS"), bool):
        raise Exception("Invalid PPPoE UsePeerDNS: " + intf.get('name') + " " + intf.get("v4PPPoEUsePeerDNS"))

    if intf.get("v6ConfigType") not in [None, "DHCP", "SLAAC", "ASSIGN", "STATIC", "DISABLED"]:
        raise Exception("Invalid v6ConfigType: " + intf.get('name') + " " + intf.get("v6ConfigType"))

    if intf.get("v6AssignHint") != None and not isinstance(intf.get("v6AssignHint"), str):
        raise Exception("Invalid v6AssignHint: " + intf.get('name') + " " + intf.get("v6AssignHint"))

    if intf.get("routerAdvertisements") != None and not isinstance(intf.get("routerAdvertisements"), bool):
        raise Exception("Invalid Router Advertisements: " + intf.get('name') + " " + intf.get("routerAdvertisements"))

    if intf.get("bridgedTo") != None and not isinstance(intf.get("bridgedTo"), int):
        raise Exception("Invalid Bridged To: " + intf.get('name') + " " + intf.get("bridgedTo"))

    if intf.get("downloadKbps") != None and not isinstance(intf.get("downloadKbps"), int):
        raise Exception("Invalid DownloadKbps: " + intf.get('name') + " " + intf.get("downloadKbps"))

    if intf.get("uploadKbps") != None and not isinstance(intf.get("uploadKbps"), int):
        raise Exception("Invalid UploadKbps: " + intf.get('name') + " " + intf.get("uploadKbps"))

    if intf.get("macaddr") != None and not isinstance(intf.get("macaddr"), str):
        raise Exception("Invalid MAC Address: " + intf.get('name') + " " + intf.get("macaddr"))
    if intf.get("macaddr") != None and not re.match("[0-9a-f]{2}([-:]?)[0-9a-f]{2}(\\1[0-9a-f]{2}){4}$", intf.get("macaddr")):
        raise Exception("Invalid MAC Address: " + intf.get('name') + " " + intf.get("macaddr"))

    if intf.get("dhcpEnabled") != None and not isinstance(intf.get("dhcpEnabled"), bool):
        raise Exception("Invalid DHCP Enabled: " + intf.get('name') + " " + intf.get("dhcpEnabled"))

    if intf.get("dhcpOptions") != None:
        for dhcp_option in intf.get("dhcpOptions"):
            if not isinstance(dhcp_option.get("enabled"), bool):
                raise Exception("Invalid DHCP Option Enabled: " + intf.get('name') + " " + dhcp_option.get("enabled"))
            if not isinstance(dhcp_option.get("value"), str):
                raise Exception("Invalid DHCP Option Value: " + intf.get('name') + " " + dhcp_option.get("value"))

    if intf.get("vrrpEnabled") != None and not isinstance(intf.get("vrrpEnabled"), bool):
        raise Exception("Invalid VRRP Enabled: " + intf.get('name') + " " + intf.get("vrrpEnabled"))

    if intf.get("vrrpId") != None and (not isinstance(intf.get("vrrpId"), int) or intf.get("vrrpId") < 1 or intf.get("vrrpId") > 255):
        raise Exception("Invalid VRRP Id: " + intf.get('name') + " " + intf.get("vrrpId"))

    if intf.get("vrrpPriority") != None and (not isinstance(intf.get("vrrpPriority"), int) or intf.get("vrrpPriority") < 1 or intf.get("vrrpPriority") > 255):
        raise Exception("Invalid VRRP Priority: " + intf.get('name') + " " + intf.get("vrrpPriority"))

    if intf.get("vrrpV4Aliases") != None:
        for v4_alias in intf.get("v4_aliases"):
            if not valid_ipv4(v4_alias.get("v4Address")):
                raise Exception("Invalid IPv4 VRRP Alias Address: " + intf.get('name') + " " + v4_alias.get("v4Address"))
            if v4_alias.get("v4Prefix") < 1 or v4_alias.get("v4Prefix") > 32:
                raise Exception("Invalid IPv4 VRRP Alias Prefix: " + intf.get('name') + " " + v4_alias.get("v4Prefix"))

    if intf.get("wirelessSsid") != None and not isinstance(intf.get("wirelessSsid"), str):
        raise Exception("Invalid Wireles SSID: " + intf.get('name') + " " + intf.get("wirelessSsid"))

    if not intf.get("wirelessEncryption") in [None, "NONE", "WPA1", "WPA12", "WPA2"]:
        raise Exception("Invalid Wireles Encryption: " + intf.get('name') + intf.get("wirelessEncryption"))

    if not intf.get("wirelessMode") in [None, "AP", "CLIENT"]:
        raise Exception("Invalid Wireles Mode: " + intf.get('name') + " " + intf.get("wirelessMode"))

    if intf.get("wirelessPassword") != None and not isinstance(intf.get("wirelessPassword"), str):
        raise Exception("Invalid Wireles Password: " + intf.get('name') + " " + intf.get("wirelessPassword"))

    if intf.get("wirelessChannel") != None and (not isinstance(intf.get("wirelessChannel"), int) or intf.get("wirelessChannel") < 0 or intf.get("wirelessChannel") > 200):
        raise Exception("Invalid Wireles Channel: " + intf.get('name') + " " + intf.get("wirelessChannel"))

registrar.register_manager(NetworkManager())
