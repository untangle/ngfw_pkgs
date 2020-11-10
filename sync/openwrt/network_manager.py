"""network_manager manages /etc/config/network"""
# pylint: disable=unused-argument
# pylint: disable=no-self-use
# pylint: disable=too-many-statements
# pylint: disable=bare-except
# pylint: disable=too-many-branches
# pylint: disable=too-many-public-methods
# pylint: disable=too-many-locals
import os
import subprocess
import ipaddress
import re
import base64
import stat
from sync import registrar, Manager
from sync import network_util
from sync import board_util
from sync import vlan_util

class NetworkManager(Manager):
    """
    This class is responsible for writing /etc/config/network
    based on the settings object passed from sync-settings
    """
    GREEK_NAMES = ["alpha", "beta", "gamma", "delta", "epsilon", "zeta", "eta", "theta", "iota", "kappa", "lambda", "mu"]
    network_filename = "/etc/config/network"
    network_file = None

    def initialize(self):
        """initialize this module"""
        registrar.register_settings_file("settings", self)
        registrar.register_file(self.network_filename, "restart-networking", self)

    def sanitize_settings(self, settings_file):
        """sanitizes removes blank settings"""
        interfaces = settings_file.settings.get('network').get('interfaces')
        # Remove all "" and 0 and null values
        for intf in interfaces:
            for k, v in dict(intf).items():
                if v == "":
                    del intf[k]
                if intf.get(k, "missing") is None:
                    del intf[k]
            # The UI currently doesn't set wan = false for LANS
            # if it is not specified, assume its false
            if intf.get("wan") is None:
                intf["wan"] = False
            if intf.get("interfaceId") is None:
                intf["interfaceId"] = find_lowest_available_interface_id(interfaces)
            # We used to set configType == DISABLED to disable interfaces
            if intf.get("enabled") is None:
                if intf["configType"] == "DISABLED":
                    intf["enabled"] = False
                else:
                    intf["enabled"] = True
            # mfw-1093 ensure no more remaining openVpnBoundInterfaceId properties
            # change openvpnBoundInterfaceId to boundInterfaceId
            if intf.get('openvpnBoundInterfaceId'):
                intf['boundInterfaceId'] = intf.pop('openvpnBoundInterfaceId', "0")

            # sync vlan device with vlan name for debuggability's sake
            if intf.get('type') == 'VLAN':
                intf['device'] = intf.get('name')

        # Give any OpenVPN interfaces tun devices
        openvpn_set_tun_interfaces(settings_file.settings)

    def validate_settings(self, settings_file):
        """validates settings"""
        interfaces = settings_file.settings.get('network').get('interfaces')
        for intf in interfaces:
            self.validate_interface(intf, settings_file)
            # TODO add mulit-setting validation:
            # for example:
            # if dhcp is enabled, dhcpStart and dhcpEnd are specified
            # etc
            # TODO add multi-interface validation:
            # for example:
            # if an interface is bridged its bridged to an interface that exists
            # a static interface doesn't have the same subnet as another static interface
            # etc

    def create_settings(self, settings_file, prefix, delete_list, filename):
        """creates settings"""
        print("%s: Initializing settings" % self.__class__.__name__)
        network = {}
        network['interfaces'] = []
        settings_file.settings['network'] = network

        self.create_settings_devices(settings_file.settings, prefix, delete_list)
        self.create_settings_interfaces(settings_file.settings, prefix, delete_list)
        self.create_settings_switches(settings_file.settings, prefix, delete_list)

    def sync_settings(self, settings_file, prefix, delete_list):
        """syncs settings"""
        self.write_network_file(settings_file.settings, prefix)

    def write_network_file(self, settings, prefix):
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
                if intf2.get('enabled') and intf2.get('configType') == 'BRIDGED' and intf2.get('bridgedTo') == intf.get('interfaceId'):
                    bridged_interfaces_str.append(str(intf2.get('device')))
                    bridged_interfaces.append(intf2)
            if bridged_interfaces:
                is_bridge = True
                bridged_interfaces_str.insert(0, intf.get('device'))  # include yourself in bridge at front
                bridged_interfaces.insert(0, intf)  # include yourself in bridge at front
            intf['is_bridge'] = is_bridge
            if is_bridge:
                intf['bridged_interfaces_str'] = bridged_interfaces_str

            if intf.get('is_bridge'):
                intf['logical_name'] = "b_" + intf['name']
                # https://wiki.openwrt.org/doc/uci/network#aliasesthe_new_way
                # documentation says to use "br-" plus logical name
                intf['ifname'] = "br-" + intf['logical_name']
                intf['netfilterDev'] = intf['ifname']
            else:
                intf['logical_name'] = intf['name']
                # Set vlan ifname to the name of the vlan so configuration works properly
                if intf.get('type') == 'VLAN':
                    intf['ifname'] = intf['name']
                else:
                    intf['ifname'] = intf.get('device')
                intf['netfilterDev'] = intf['device']


        for intf in interfaces:
            if intf.get('enabled'):
                if intf.get('type') == 'OPENVPN':
                    self.write_interface_openvpn(intf, settings, prefix)
                elif intf.get('type') == 'WIREGUARD':
                    self.write_interface_wireguard(intf, settings)
                elif intf.get('type') == 'WWAN':
                    self.write_interface_wwan(intf, settings)
                else: 
                    if intf.get('type') == 'VLAN':
                        file.write(vlan_util.write_interface_vlan(intf, settings))
                    self.write_interface_bridge(intf, settings)
                    self.write_interface_v4(intf, settings)
                    self.write_interface_v6(intf, settings)

        switches = settings['network'].get('switches')
        if switches is not None:
            for swi in switches:
                self.write_switch(swi, settings)

        self.write_lan_route_rules(settings)
        self.write_route_rules(settings)

        file.flush()
        file.close()

        print("%s: Wrote %s" % (self.__class__.__name__, filename))

    def write_lan_route_rules(self, settings):
        """
        Create route rules to ensure local lan to lan traffic gets
        routed correctly.  Local lans will be enabled, non-wan, staticly
        addressed interfaces
        """
        priority = 3000
        file = self.network_file
        file.write("\n")

        interfaces = settings['network']['interfaces']
        for intf in interfaces:
            if (
                intf.get('enabled')
                and not intf.get('wan')
                and intf.get('configType') == 'ADDRESSED'
                and intf.get('v4ConfigType') == "STATIC"
               ):
                    file.write("config rule\n")
                    file.write("\toption dest '%s/%d'\n" % (intf.get('v4StaticAddress'), intf.get('v4StaticPrefix')))
                    file.write("\toption priority '%d'\n" % priority)
                    file.write("\toption lookup 'main'\n")
                    file.write("\n")

                    priority = priority + 1


    def write_route_rules(self, settings):
        """write the route rules"""
        fwmark_priority = 7000
        oif_priority = 5000
        file = self.network_file
        file.write("\n")

        interfaces = settings['network']['interfaces']
        for intf in interfaces:
            if network_util.enabled_wan(intf):
                if intf.get('v4ConfigType') != "DISABLED":
                    self.create_route_rules_ipfamily(file, settings, intf, fwmark_priority, oif_priority, "ipv4")

                if intf.get('v6ConfigType') != "DISABLED":
                    self.create_route_rules_ipfamily(file, settings, intf, fwmark_priority, oif_priority, "ipv6")

                fwmark_priority = fwmark_priority + 1
                oif_priority = oif_priority + 1

    def create_route_rules_ipfamily(self, file, settings, intf, fwmark_priority, oif_priority, family):
        """create_route_rules_ipfamily creates route rules for a specific ip family rule type"""
        ruleType = ("rule" if family == "ipv4" else "rule6")
        file.write("config %s\n" % ruleType)
        file.write("\toption mark '0x%x00/0xff00'\n" % intf.get('interfaceId'))
        file.write("\toption priority '%d'\n" % fwmark_priority)
        file.write("\toption lookup 'wan.%d'\n" % intf.get('interfaceId'))
        file.write("\n")

        file.write("config %s\n" % ruleType)
        file.write("\toption out '%s'\n" % network_util.get_interface_name(settings, intf, family))
        file.write("\toption priority '%d'\n" % oif_priority)
        file.write("\toption lookup 'wan.%d'\n" % intf.get('interfaceId'))
        file.write("\n")

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

    def write_interface_wwan(self, intf, settings):
        """write a wwan interface"""
        file = self.network_file
        ifname = intf['ifname']
        device = "/dev/cdc-wdm" + ifname.split('wwan')[-1]

        file.write("\n")
        file.write("config interface '%s'\n" % intf['logical_name'])
        file.write("\toption proto 'qmi'\n")
        file.write("\toption ifname '%s'\n" % ifname)
        file.write("\toption device '%s'\n" % device)

        if intf.get('simDelay') is not None:
            file.write("\toption delay '%d'\n" % intf.get('simDelay'))

        if intf.get('simTimeout') is not None:
            file.write("\toption timeout '%d'\n" % intf.get('simTimeout'))

        if intf.get('simApn') is not None:
            file.write("\toption apn '%s'\n" % intf.get('simApn'))

        if intf.get('simProfile') is not None:
            file.write("\toption profile '%d'\n" % intf.get('simProfile'))

        if intf.get('simPin') is not None:
            file.write("\toption pincode '%s'\n" % intf.get('simPin'))

        auth = intf.get('simAuth')
        if auth is not None and auth != "NONE":
            if auth == "PAP":
                file.write("\toption auth 'pap'\n")
            elif auth == "CHAP":
                file.write("\toption auth 'chap'\n")
            else:
                file.write("\toption auth 'both'\n")

            file.write("\toption username '%s'\n" % intf.get('simUsername'))
            file.write("\toption password '%s'\n" % intf.get('simPassword'))

        mode = intf.get('simMode')
        if mode is None:
            file.write("\toption modes 'all'\n")
        else:
            if mode == "ALL":
                file.write("\toption modes 'all'\n")
            elif mode == "LTE":
                file.write("\toption modes 'lte'\n")
            elif mode == "UMTS":
                file.write("\toption modes 'umts'\n")
            elif mode == "GSM":
                file.write("\toption modes 'gsm'\n")
            elif mode == "CDMA":
                file.write("\toption modes 'cdma'\n")
            elif mode == "TDSCDMA":
                file.write("\toption modes 'td-scdma'\n")

        pdptype = intf.get('simPdptype')
        if pdptype is None:
            file.write("\toption pdptype 'ip'\n")
        else:
            if pdptype == "IPV4":
                file.write("\toption pdptype 'ip'\n")
            elif pdptype == "IPV6":
                file.write("\toption pdptype 'ipv6'\n")
            elif pdptype == "IPV4V6":
                file.write("\toption pdptype 'ipv4v6'\n")

        plmn = intf.get('simPlmn')
        if plmn is not None:
            file.write("\toption plmn '%d'\n" % intf.get('simPlmn'))

        autoconnect = intf.get('simAutoconnect')
        if autoconnect is not None:
            if autoconnect is True:
                file.write("\toption autoconnect '1'\n")
            else:
                file.write("\toption autoconnect '0'\n")

        if intf.get('wan'):
            if intf.get('v4ConfigType') != "DISABLED":
                file.write("\toption ip4table 'wan.%d'\n" % intf.get('interfaceId'))

            if intf.get('v6ConfigType') != "DISABLED":
                file.write("\toption ip6table 'wan.%d'\n" % intf.get('interfaceId'))

            if intf.get('v6ConfigType') != "DISABLED" or intf.get('v4ConfigType') != "DISABLED":
                file.write("\toption defaultroute '1'\n")

            if intf.get('v6ConfigType') == "DHCP":
                file.write("\toption dhcpv6 '1'\n")

    def write_interface_wireguard(self, intf, settings):
        """write a wireguard interface"""
        file = self.network_file

        file.write("\n")
        file.write("config interface '%s'\n" % intf['logical_name'])
        file.write("\toption proto 'wireguard'\n")
        file.write("\toption private_key '%s'\n" % intf.get('wireguardPrivateKey'))
        addresses = intf.get('wireguardAddresses')
        for address in addresses:
            file.write("\tlist addresses '{address}/{prefix}'\n".format(address=address.get('address'), prefix=address.get('prefix')))
        if intf.get('wireguardType') == 'TUNNEL' and intf.get('wireguardPort') is not None:
            file.write("\toption listen_port '%s'\n" % intf.get('wireguardPort'))

        if intf.get('wan'):
            if intf.get('v4ConfigType') != "DISABLED":
                file.write("\toption ip4table 'wan.%d'\n" % intf.get('interfaceId'))

            if intf.get('v6ConfigType') != "DISABLED":
                file.write("\toption ip6table 'wan.%d'\n" % intf.get('interfaceId'))

            if intf.get('v6ConfigType') != "DISABLED" or intf.get('v4ConfigType') != "DISABLED":
                file.write("\toption defaultroute '1'\n")

        file.write("\n")
        peers = intf.get('wireguardPeers')
        for peer in peers:
            file.write("config 'wireguard_%s'\n" % intf['logical_name'])
            file.write("\toption public_key '%s'\n" % peer.get('publicKey'))
            if peer.get('routeAllowedIps') is not None and peer.get('routeAllowedIps'):
                file.write("\toption route_allowed_ips '1'\n")
            else:
                file.write("\toption route_allowed_ips '0'\n")
            allowedIps = []
            ips = peer.get('allowedIps')
            for ip in ips:
                allowedIps.append("{address}/{prefix}".format(address=ip.get('address'), prefix=ip.get('prefix')))
            file.write("\tlist allowed_ips '{allowedIps}'\n".format(allowedIps=",".join(allowedIps)))
            if peer.get('host') is not None:
                file.write("\toption endpoint_host '%s'\n" % peer.get('host'))
            if peer.get('port') is not None:
                file.write("\toption endpoint_port '%s'\n" % peer.get('port'))
            if peer.get('keepalive') is not None:
                file.write("\toption persistent_keepalive '%d'\n" % peer.get('keepalive'))
            if peer.get('presharedKey') is not None:
                file.write("\toption preshared_key '%s'\n" % peer.get('presharedKey'))

    def write_interface_openvpn(self, intf, settings, prefix):
        """write an openvpn interface"""
        file = self.network_file

        path = "/etc/config/openvpn-" + str(intf["interfaceId"]) + ".ovpn"
        auth_path = "/etc/config/openvpn-" + str(intf["interfaceId"]) + ".auth"

        file.write("\n")
        file.write("config interface '%s'\n" % intf['logical_name'])
        file.write("\toption ifname '%s'\n" % intf['ifname'])
        file.write("\toption proto 'openvpn'\n")
        file.write("\toption config '%s'\n" % path)

        if intf.get('wan'):
            if intf.get('v4ConfigType') != "DISABLED":
                file.write("\toption ip4table 'wan.%d'\n" % intf.get('interfaceId'))

            if intf.get('v6ConfigType') != "DISABLED":
                file.write("\toption ip6table 'wan.%d'\n" % intf.get('interfaceId'))

            if intf.get('v6ConfigType') != "DISABLED" or intf.get('v4ConfigType') != "DISABLED":
                file.write("\toption defaultroute '1'\n")

            if('openvpnPeerDns' in intf and intf.get('openvpnPeerDns') == True):
                file.write("\toption peerdns '1'\n")

        if intf.get('openvpnUsernamePasswordEnabled'):
            file.write("\toption authfile '%s'\n" % auth_path)

        wanId = intf.get('boundInterfaceId')
        if wanId is not None:

            # FIXME: This is currently defined as a string, but probably should be an int.
            # Deal with either for now
            if isinstance(wanId, str):
                wanId = int(wanId,10)

            if wanId != 0:
                # If we have v4 or v6 configured, we can bind to both. The openvpn.sh script in openvpn-proto adds a local bind for both the IPv4 wanif and IPv6 wanif6 configurations
                if intf.get('v4ConfigType') != "DISABLED":
                    file.write("\toption wanif '%s'\n" % network_util.get_interface_name(settings, network_util.get_interface_by_id(settings, wanId), 'ipv4'))
                if intf.get('v6ConfigType') != "DISABLED":
                    file.write("\toption wanif6 '%s'\n" % network_util.get_interface_name(settings, network_util.get_interface_by_id(settings, wanId), 'ipv6'))

        # also write the conf file
        self.write_openvpn_conf_file(intf, path, prefix)
        if intf.get('openvpnUsernamePasswordEnabled'):
            self.write_openvpn_auth_file(intf, auth_path, prefix)

    def write_openvpn_auth_file(self, intf, path, prefix):
        """write the openvpn username/password auth file"""
        username = intf.get('openvpnUsername')
        password_base64 = intf.get('openvpnPasswordBase64')
        if username is None:
            raise Exception("Missing username on openvpn interface: " + intf["interfaceId"])
        if password_base64 is None:
            raise Exception("Missing password on openvpn interface: " + intf["interfaceId"])
        try:
            password = base64.b64decode(password_base64).decode()
        except:
            raise Exception("Failed to parse password on openvpn interface: " + intf["interfaceId"])

        filename = prefix + path
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        file = open(filename, "w+")
        file.write("%s\n%s\n" % (username, password))
        file.flush()
        file.close()
        os.chmod(filename, stat.S_IWRITE | stat.S_IREAD)
        print("%s: Wrote %s" % (self.__class__.__name__, filename))

    def write_openvpn_conf_file(self, intf, path, prefix):
        """write the specified file"""

        filename = prefix + path
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)
        conffile = intf["openvpnConfFile"]

        file = open(filename, "wb+")
        # only base64 is currently supported
        if conffile.get('encoding') == 'base64':
            contents = base64.b64decode(conffile.get('contents'))
            contents = contents.replace(b'nobind',b'#nobind')
            contents = contents.replace(b'persist-tun',b'#persist-tun')
            file.write(contents)
            file.flush()
            file.close()
            print("%s: Wrote %s" % (self.__class__.__name__, filename))

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

        if intf.get('v4Aliases') is not None and intf.get('v4ConfigType') == "STATIC":
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
            if intf.get('v4DhcpAddressOverride') is not None and intf.get('v4DhcpAddressOverride') != "":
                file.write("\toption ipaddr '%s'\n" % intf.get('v4DhcpAddressOverride'))
            if intf.get('v4DhcpDNS1Override') is not None and intf.get('v4DhcpDNS1Override') != "" and intf.get('v4DhcpDNS2Override') is not None and intf.get('v4DhcpDNS2Override') != "":
                file.write("\toption dns '%s %s'\n" % (intf.get('v4DhcpDNS1Override'), intf.get('v4DhcpDNS2Override')))
                file.write("\toption peerdns '0'\n")
            elif intf.get('v4DhcpDNS1Override') is not None and intf.get('v4DhcpDNS1Override') != "":
                file.write("\toption dns '%s'\n" % intf.get('v4DhcpDNS1Override'))
                file.write("\toption peerdns '0'\n")
        elif intf.get('v4ConfigType') == "STATIC":
            file.write("\toption proto 'static'\n")
            if intf.get('wan'):
                file.write("\toption force_link '0'\n")
            file.write("\toption ipaddr '%s'\n" % intf.get('v4StaticAddress'))
            file.write("\toption netmask '%s'\n" % network_util.ipv4_prefix_to_netmask(intf.get('v4StaticPrefix')))
            if intf.get('wan') and intf.get('v4StaticGateway') is not None:
                file.write("\toption gateway '%s'\n" % intf.get('v4StaticGateway'))
        elif intf.get('v4ConfigType') == "PPPOE":
            if not intf.get('wan'):
                raise Exception('Invalid v4ConfigType: Can not use PPPOE on non-WAN interfaces')
            file.write("\toption proto 'pppoe'\n")
            file.write("\toption username '%s'\n" % intf.get('v4PPPoEUsername'))
            file.write("\toption password '%s'\n" % intf.get('v4PPPoEPassword'))
            if intf.get("v4PPPoEUsePeerDNS") == True:
                file.write("\toption peerdns '1'\n")
            else:
                file.write("\toption peerdns '0'\n")
                dnslist = ""
                if intf.get('v4PPPoEOverrideDNS1') is not None and intf.get('v4PPPoEOverrideDNS1') != "":
                    dnslist = intf.get('v4PPPoEOverrideDNS1')
                if intf.get('v4PPPoEOverrideDNS2') is not None and intf.get('v4PPPoEOverrideDNS2') != "":
                    if len(dnslist) != 0:
                        dnslist += ", "
                        dnslist += intf.get('v4PPPoEOverrideDNS2')
                    else:
                        dnslist = intf.get('v4PPPoEOverrideDNS2')
                if len(dnslist) == 0:
                    raise Exception('Use Peer DNS is disabled and no DNS servers are configured')
                file.write("\toption dns '%s'\n" % dnslist)

            # Create the pppoe interface name here, and use it for any netfilterDev references
            # for this interface later
            pppoeName = "ppp-" + intf['logical_name']
            file.write("\toption pppname '%s'\n" % pppoeName)
            intf['netfilterDev'] = pppoeName

        elif intf.get('v4ConfigType') == "DISABLED":
            # This needs to be written for addressless bridges
            file.write("\toption proto 'none'\n")
            file.write("\toption auto '1'\n")

        if intf.get('wan') and intf.get('v4ConfigType') != "DISABLED":
            file.write("\toption ip4table 'wan.%d'\n" % intf.get('interfaceId'))

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
            if intf.get('v6DhcpDNS1Override') is not None and intf.get('v6DhcpDNS2Override') is not None:
                file.write("\toption dns '%s %s'\n" % (intf.get('v6DhcpDNS1Override'), intf.get('v6DhcpDNS2Override')))
                file.write("\toption peerdns '0'\n")
            elif intf.get('v6DhcpDNS1Override') is not None:
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
            if intf.get('v6StaticAddress') is not None and intf.get('v6StaticPrefix') is not None:
                file.write("\toption proto 'static'\n")
                file.write("\toption ip6addr '%s/%s'\n" % (intf.get('v6StaticAddress'), intf.get('v6StaticPrefix')))
                if intf.get('wan') and intf.get('v6StaticGateway') is not None:
                    file.write("\toption ip6gw '%s'\n" % intf.get('v6StaticGateway'))

        if intf.get('v6Aliases') is not None and intf.get('v6ConfigType') == "STATIC":
            for idx, alias in enumerate(intf.get('v6Aliases')):
                self.write_interface_v6_alias(intf, alias, (idx+1), settings)

        if intf.get('wan'):
            file.write("\toption ip6table 'wan.%d'\n" % intf.get('interfaceId'))
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
        file.write("\toption ip6addr '%s/%s'\n" % (alias.get('v6Address'), alias.get('v6Prefix')))

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
            internal_device_list = []
            internal_device_name = "None"
            wan_device_list = []
            wan_device_list.append(device_list[0])
        else:
            internal_device_list = board_util.get_internal_interfaces()
            internal_device_name = internal_device_list[0]
            wan_device_list = board_util.get_wan_interfaces()

        # Move wans to top of list
        for wan_device_name in wan_device_list:
            if wan_device_name in device_list:
                device_list.remove(wan_device_name)
                device_list.insert(wan_device_list.index(wan_device_name), wan_device_name)

        settings['network']['interfaces'] = []
        interface_list = []
        intf_id = 0
        internal_id = None
        wwan_index = 0
        internal_count = 1
        for dev in settings['network']['devices']:
            if dev['name'] in board_util.get_hidden_interfaces():
                continue
            intf_id = intf_id + 1
            interface = {}
            interface['interfaceId'] = intf_id
            interface['device'] = dev['name']
            interface['name'] = board_util.get_interface_name(interface['device'])

            interface['qosEnabled'] = False
            interface['downloadKbps'] = 0
            interface['uploadKbps'] = 0
            interface['wanWeight'] = 0
            interface['macaddr'] = board_util.get_interface_macaddr(interface['device'])

            if interface['device'].startswith("wlan"):
                interface['type'] = 'WIFI'
            elif interface['device'].startswith("wwan"):
                interface['type'] = 'WWAN'
            else:
                interface['type'] = 'NIC'

            if dev.get('name') == internal_device_name:
                internal_id = intf_id
                create_settings_internal_interface(interface, internal_count)
                internal_count = internal_count + 1
            elif dev.get('name') in wan_device_list:
                create_settings_wan_interface(interface, wan_device_list.index(dev.get('name')))
            elif interface['type'] == 'WWAN':
                create_settings_wwan_interface(interface, wwan_index)
                wwan_index += 1
            else:
                interface['wan'] = False
                interface['enabled'] = True
                if interface['name'] == "":
                    if intf_id < len(self.GREEK_NAMES):
                        interface['name'] = self.GREEK_NAMES[intf_id]
                    else:
                        interface['name'] = "intf%i" % intf_id
                if internal_id is not None and (dev.get('name').startswith('wlan') or dev.get('name') in internal_device_list):
                    interface['configType'] = 'BRIDGED'
                    interface['bridgedTo'] = internal_id
                else:
                    create_settings_internal_interface(interface, internal_count)
                    internal_count = internal_count + 1
                    interface['enabled'] = False

            interface_list.append(interface)
        settings['network']['interfaces'] = interface_list

    def write_macaddr(self, file, macaddr):
        """write macaddr option"""
        if macaddr != "" and macaddr is not None:
            file.write("\toption macaddr '%s'\n" % macaddr)

    def create_settings_switches(self, settings, prefix, delete_list):
        """create switches config"""
        settings['network']['switches'] = board_util.get_switch_settings()

    def validate_interface(self, intf, settings_file):
        """
        validates that each field within an interface makes sense individually
        @param self - this class instance
        @param intf - the network interface we are validating
        @param settings_file - the settings file
        """
        # If the interface is disabled, don't bother verifying attributes
        if intf.get("enabled") is None:
            raise Exception("Missing enabled attribute: " + intf.get('name'))
        if not intf.get("enabled"):
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
            if intf.get(ipv4_prefix_key) is not None and (intf.get(ipv4_prefix_key) < 1 or intf.get(ipv4_prefix_key) > 32):
                raise Exception("Invalid IPv4 Prefix: " + intf.get('name') + " " + ipv4_prefix_key + " = " + intf.get(ipv4_prefix_key))

        for ipv6_prefix_key in ["v6StaticPrefix", "v6AssignPrefix"]:
            if intf.get(ipv6_prefix_key) is not None and (intf.get(ipv6_prefix_key) < 1 or intf.get(ipv6_prefix_key) > 128):
                raise Exception("Invalid IPv6 Prefix: " + intf.get('name') + " " + ipv6_prefix_key + " = " + intf.get(ipv6_prefix_key))

        # check individual settings
        if '-' in intf.get("name"):
            raise Exception("Invalid interface name contains hyphen: " + intf.get('name'))

        # validate that interface name is not only integers
        if not re.match("^[a-zA-Z]+[a-zA-Z0-9_]*$", intf.get("name")): 
            raise Exception("Invalid interface name, at least one character required: " + intf.get('name'))

        # validate interface name is "nftables compatible"
        if intf.get("name")[0].isdigit(): 
            raise Exception("Invalid interface name, interfaces should not start with an integer: " + intf.get('name'))
 
        if intf.get("v4ConfigType") not in [None, "STATIC", "DHCP", "PPPOE", "DISABLED"]:
            raise Exception("Invalid v4ConfigType: " + intf.get('name') + " " + intf.get("v4ConfigType"))

        if intf.get("v4Aliases") is not None:
            for v4_alias in intf.get("v4Aliases"):
                if not valid_ipv4(v4_alias.get("v4Address")):
                    raise Exception("Invalid IPv4 Alias Address: " + intf.get('name') + " " + v4_alias.get("v4Address"))
                if v4_alias.get("v4Prefix") < 1 or v4_alias.get("v4Prefix") > 32:
                    raise Exception("Invalid IPv4 Alias Prefix: " + intf.get('name') + " " + v4_alias.get("v4Prefix"))

        if intf.get("v4PPPoEUsername") is not None and not isinstance(intf.get("v4PPPoEUsername"), str):
            raise Exception("Invalid PPPoE Username: " + intf.get('name') + " " + intf.get("v4PPPoEUsername"))

        if intf.get("v4PPPoEPassword") is not None and not isinstance(intf.get("v4PPPoEPassword"), str):
            raise Exception("Invalid PPPoE Password: " + intf.get('name') + " " + intf.get("v4PPPoEPassword"))

        if intf.get("v4PPPoEUsePeerDNS") is not None and not isinstance(intf.get("v4PPPoEUsePeerDNS"), bool):
            raise Exception("Invalid PPPoE UsePeerDNS: " + intf.get('name') + " " + intf.get("v4PPPoEUsePeerDNS"))

        if intf.get("v6ConfigType") not in [None, "DHCP", "SLAAC", "ASSIGN", "STATIC", "DISABLED"]:
            raise Exception("Invalid v6ConfigType: " + intf.get('name') + " " + intf.get("v6ConfigType"))

        if intf.get("v6AssignHint") is not None and not isinstance(intf.get("v6AssignHint"), str):
            raise Exception("Invalid v6AssignHint: " + intf.get('name') + " " + intf.get("v6AssignHint"))

        if intf.get("v6RelayEnabled") is not None and not isinstance(intf.get("v6RelayEnabled"), bool):
            raise Exception("Invalid IPv6 Relay option: " + intf.get('name') + " " + intf.get("v6RelayEnabled"))

        if intf.get("routerAdvertisements") is not None and not isinstance(intf.get("routerAdvertisements"), bool):
            raise Exception("Invalid Router Advertisements: " + intf.get('name') + " " + intf.get("routerAdvertisements"))

        if intf.get("bridgedTo") is not None and not isinstance(intf.get("bridgedTo"), int):
            raise Exception("Invalid Bridged To: " + intf.get('name') + " " + intf.get("bridgedTo"))

        if intf.get("wan") and intf.get("qosEnabled"):
            if intf.get("downloadKbps") is not None and not isinstance(intf.get("downloadKbps"), int):
                raise Exception("Invalid DownloadKbps: " + intf.get('name') + " " + intf.get("downloadKbps"))

            if intf.get("downloadKbps") is None or intf.get("downloadKpbs") == 0:
                raise Exception("No DownloadKbps specified: " + intf.get('name'))

            if intf.get("uploadKbps") is not None and not isinstance(intf.get("uploadKbps"), int):
                raise Exception("Invalid UploadKbps: " + intf.get('name') + " " + intf.get("uploadKbps"))

            if intf.get("uploadKbps") is None or intf.get("uploadKpbs") == 0:
                raise Exception("No UploadKbps specified: " + intf.get('name'))

        if intf.get("macaddr") is not None and not isinstance(intf.get("macaddr"), str):
            raise Exception("Invalid MAC Address: " + intf.get('name') + " " + intf.get("macaddr"))
        if intf.get("macaddr") is not None and not re.match("[0-9a-f]{2}([-:]?)[0-9a-f]{2}(\\1[0-9a-f]{2}){4}$", intf.get("macaddr")):
            raise Exception("Invalid MAC Address: " + intf.get('name') + " " + intf.get("macaddr"))

        if intf.get("dhcpEnabled") is not None and not isinstance(intf.get("dhcpEnabled"), bool):
            raise Exception("Invalid DHCP Enabled: " + intf.get('name') + " " + intf.get("dhcpEnabled"))

        if intf.get("dhcpOptions") is not None:
            for dhcp_option in intf.get("dhcpOptions"):
                if not isinstance(dhcp_option.get("enabled"), bool):
                    raise Exception("Invalid DHCP Option Enabled: " + intf.get('name') + " " + dhcp_option.get("enabled"))
                if not isinstance(dhcp_option.get("value"), str):
                    raise Exception("Invalid DHCP Option Value: " + intf.get('name') + " " + dhcp_option.get("value"))

        if intf.get("vrrpEnabled") is not None and not isinstance(intf.get("vrrpEnabled"), bool):
            raise Exception("Invalid VRRP Enabled: " + intf.get('name') + " " + intf.get("vrrpEnabled"))

        if intf.get("vrrpId") is not None and (not isinstance(intf.get("vrrpId"), int) or intf.get("vrrpId") < 1 or intf.get("vrrpId") > 255):
            raise Exception("Invalid VRRP Id: " + intf.get('name') + " " + intf.get("vrrpId"))

        if intf.get("vrrpPriority") is not None and (not isinstance(intf.get("vrrpPriority"), int) or intf.get("vrrpPriority") < 1 or intf.get("vrrpPriority") > 255):
            raise Exception("Invalid VRRP Priority: " + intf.get('name') + " " + intf.get("vrrpPriority"))

        if intf.get("vrrpV4Aliases") is not None:
            for v4_alias in intf.get("vrrpV4Aliases"):
                if not valid_ipv4(v4_alias.get("v4Address")):
                    raise Exception("Invalid IPv4 VRRP Alias Address: " + intf.get('name') + " " + v4_alias.get("v4Address"))
                if v4_alias.get("v4Prefix") < 1 or v4_alias.get("v4Prefix") > 32:
                    raise Exception("Invalid IPv4 VRRP Alias Prefix: " + intf.get('name') + " " + v4_alias.get("v4Prefix"))

        if intf.get("wirelessSsid") is not None and not isinstance(intf.get("wirelessSsid"), str):
            raise Exception("Invalid Wireless SSID: " + intf.get('name') + " " + intf.get("wirelessSsid"))

        if not intf.get("wirelessEncryption") in [None, "NONE", "WPA1", "WPA12", "WPA2"]:
            raise Exception("Invalid Wireless Encryption: " + intf.get('name') + intf.get("wirelessEncryption"))

        if not intf.get("wirelessMode") in [None, "AP", "CLIENT"]:
            raise Exception("Invalid Wireless Mode: " + intf.get('name') + " " + intf.get("wirelessMode"))

        if intf.get("wirelessPassword") is not None and not isinstance(intf.get("wirelessPassword"), str):
            raise Exception("Invalid Wireless Password: " + intf.get('name') + " " + intf.get("wirelessPassword"))

        if intf.get("wirelessChannel") is not None and (not isinstance(intf.get("wirelessChannel"), int) or intf.get("wirelessChannel") < 0 or intf.get("wirelessChannel") > 200):
            raise Exception("Invalid Wireless Channel: " + intf.get('name') + " " + intf.get("wirelessChannel"))

        if intf.get("type") == 'OPENVPN':
            if intf.get("configType") not in ["ADDRESSED"]:
                raise Exception("Unsupported OPENVPN config type: " + intf.get("configType"))
            for required_attribute in ["name", "device", "openvpnConfFile", "natEgress", "wan"]:
                if intf.get(required_attribute) is None:
                    raise Exception("Missing required OpenVPN interface attribute: " + required_attribute)
            conffile = intf["openvpnConfFile"]
            for required_attribute in ["encoding", "contents"]:
                if conffile.get(required_attribute) is None:
                    raise Exception("Missing required OpenVPN interface confFile attribute: " + required_attribute)
            if conffile["encoding"] != "base64":
                raise Exception("Unsupported encoding in OpenVPN conf file: " + conffile["encoding"])
            path = "/etc/config/openvpn-" + str(intf["interfaceId"]) + ".ovpn"
            auth_path = "/etc/config/openvpn-" + str(intf["interfaceId"]) + ".auth"

            wanId = intf.get("openvpnBoundInterfaceId")
            if wanId is not None:

                if isinstance(wanId, str):
                    wanId = int(wanId,10)

                interfaces = settings_file.settings.get('network').get('interfaces')
                if wanId != 0:
                    for interface in interfaces:
                        if interface.get('interfaceId') == wanId:
                            if interface.get('enabled') is not True:
                                raise Exception("Openvpn interface " + intf.get('name') + " is bound to disabled wan " + interface.get('name'))
                else:
                    wanEnabled = False
                    openvpnId = intf.get('interfaceId')
                    for interface in interfaces:
                        if interface.get('enabled') and interface.get('wan') and openvpnId != interface.get('interfaceId'):
                            wanEnabled = True

                    if wanEnabled is not True:
                        raise Exception("Openvpn interface " + intf.get('name') + " is enabled, but no parent wans are enabled")

            # register a new operation to restart this interface if this config file changes
            # register the config file with the new operation
            cmd = "ifdown " + intf["name"] + " ; " + "ifup " + intf["name"]
            opname = "restart-" + intf["device"]
            registrar.register_operation(opname, [""], [cmd], 99, None)
            registrar.register_file(path, opname, self)
            registrar.register_file(auth_path, opname, self)

            # if this openvpn interface uses a username and password, also
            # register the auth file
            if intf.get('openvpnUsernamePasswordEnabled'):
                path = "/etc/config/openvpn-" + str(intf["interfaceId"]) + ".auth"
                registrar.register_operation(opname, [""], [cmd], 99, None)
                registrar.register_file(path, opname, self)

        if intf.get("type") == 'WIREGUARD':
            if intf.get("wireguardPrivateKey") is None or intf.get("wireguardPrivateKey") == "":
                raise Exception("No wireguard private key specified for interface: " + intf.get('name'))

            if not isinstance(intf.get("wireguardPrivateKey"), str):
                raise Exception("Specified wireguard private key is not a string: " + intf.get('name'))

            if intf.get("wireguardAddresses") is None or intf.get("wireguardAddresses") == []:
                raise Exception("No wireguard addresses specified for interface: " + intf.get('name'))

            addresses = intf.get('wireguardAddresses')
            for address in addresses:
                if not valid_ipv4_network(address.get('address')) and not valid_ipv6_network(address.get('address')):
                    raise Exception("Invalid wireguard address: " + intf.get('name') + " " + address)

            if intf.get("wireguardPeers") is None or intf.get("wireguardPeers") == []:
                raise Exception("No wireguard peers specified for interface: " + intf.get('name'))

            peers = intf.get('wireguardPeers')
            for peer in peers:
                if peer.get("publicKey") is None or peer.get("publicKey") == "":
                    raise Exception("No public key specified for wireguard peer of interface: " + intf.get('name'))

                if not isinstance(peer.get("publicKey"), str):
                    raise Exception("Specified wireguard peer private key is not a string: " + intf.get('name'))

                if peer.get("allowedIps") is None or peer.get("allowedIps") == []:
                    raise Exception("No wireguard peer addresses specified for interface: " + intf.get('name'))

                networks = peer.get('allowedIps')
                for network in networks:
                    cidr_network = "{address}/{prefix}".format(address=network.get('address'), prefix=network.get('prefix'))
                    if not valid_ipv4_network(cidr_network) and not valid_ipv6_network(cidr_network):
                        raise Exception("Invalid wireguard ip: " + intf.get('name') + " " + cidr_network)

                if peer.get("routeAllowedIps") is not None and not isinstance(peer.get("routeAllowedIps"), bool):
                    raise Exception("wireguard peer settings routeAllowedIps is not a bool: " + intf.get('name'))

                if peer.get("keepalive") is not None and not isinstance(peer.get("keepalive"), int):
                    raise Exception("wireguard peer keepalive is not an integer: " + intf.get('name'))

                if peer.get("keepalive") is not None and peer.get("keepalive") < 0:
                    raise Exception("Invalid wireguard peer keepalive: " + intf.get('name') + " " + str(peer.get("keepalive")))

            if intf.get("wireguardPort") is not None:
                if not isinstance(intf.get("wireguardPort"), int):
                    raise Exception("Specified wireguard port is not an integer: " + intf.get('name'))

                if intf.get("wireguardPort") < 0 or intf.get("wireguardPort") > 65535:
                    raise Exception("Invalid wireguard port (valid values 0-65535): " + intf.get('name') + " " + str(intf.get('wireguardPort')))

        if intf.get("type") == 'WWAN':
            if intf.get("simApn") is not None and not isinstance(intf.get("simApn"), str):
                raise Exception("Invalid WWAN apn: must be a string: " + intf.get('name'))

            if intf.get("simProfile") is not None and not isinstance(intf.get("simProfile"), int):
                raise Exception("Invalid WWAN profile: must be an int: " + intf.get('name'))

            if intf.get("simPin") is not None and not isinstance(intf.get("simPin"), int):
                raise Exception("Invalid WWAN pin: must be an int: " + intf.get('name'))

            auth = intf.get('simAuth')
            if auth is not None:
                if not isinstance(auth, str):
                    raise Exception("Invalid WWAN auth: must be a string: " + intf.get('name'))

                if auth != "NONE":
                    if auth not in ["PAP", "CHAP", "BOTH"]:
                        raise Exception("Invalid WWAN auth: must NONE, PAP, CHAP, or BOTH: " + intf.get('name'))

                    if intf.get('simUsername') is None:
                        raise Exception("Invalid WWAN config: Must specify username for PAP/CHAP/BOTH: " + intf.get('name'))

                    if not isinstance(intf.get("simUsername"), str):
                        raise Exception("Invalid WWAN username: Username must be string: " + intf.get('name'))

                    if intf.get('simPassword') is None:
                        raise Exception("Invalid WWAN config: Must specify password for PAP/CHAP/BOTH: " + intf.get('name'))

                    if not isinstance(intf.get("simPassword"), str):
                        raise Exception("Invalid WWAN password: Password must be string: " + intf.get('name'))

            mode = intf.get('simMode')
            if mode is not None:
                if not isinstance(mode, str):
                    raise Exception("Invalid WWAN mode: must be a string: " + intf.get('name'))

                if mode not in ["ALL", "LTE", "UMTS", "GSM", "CDMA", "TDSCDMA"]:
                    raise Exception("Invalid WWAN mode: must be ALL, LTE, UMTS, GSM, CDMA, or TDSCDMA: " + intf.get('name'))

            pdptype = intf.get('simPdptype')
            if pdptype is not None:
                if not isinstance(pdptype, str):
                    raise Exception("Invalid WWAN pdptype: must be a string: " + intf.get('name'))

                if pdptype not in ["IPV4", "IPV6", "IPV4V6"]:
                    raise Exception("Invalid WWAN pdptype: must be IPV4, IPV6, or IPV4V6: " + intf.get('name'))

            plmn = intf.get('simPlmn')
            if plmn is not None:
                if not isinstance(plmn, int):
                    raise Exception("Invalid WWAN plmn: must be an int: " + intf.get('name'))

            autoconnect = intf.get('simAutoconnect')
            if autoconnect is not None:
                if not isinstance(autoconnect, bool):
                    raise Exception("Invalid WWAN autoconnect: must be a bool: " + intf.get('name'))

            if intf.get('v6ConfigType') is not None and intf.get('v6ConfigType') == "DHCP" and (pdptype is None or pdptype == "IPV4"):
                raise Exception("Invalid WWAN config: pdptype must be IPV6 or IPV4V6 to enable dhcpv6: " + intf.get('name'))

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
    device_list.extend(get_devices_matching_glob("wwan*"))
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
    """returns true if address (string) is a valid IPv6 address"""
    if address is None and accept_none:
        return True
    try:
        ipaddress.IPv6Address(address)
        return True
    except:
        return False

def valid_ipv4_network(address, accept_none=False):
    """returns true if address (string) is a valid IPv4 network"""
    if address is None and accept_none:
        return True
    try:
        ipaddress.IPv4Interface(address)
        return True
    except:
        return False

def valid_ipv6_network(address, accept_none=False):
    """returns true if address (string) is a valid IPv6 network"""
    if address is None and accept_none:
        return True
    try:
        ipaddress.IPv6Interface(address)
        return True
    except:
        return False

def openvpn_set_tun_interfaces(settings):
    """
    openvpn_set_tun_interfaces sets the "device" for an openvpn interface
    When creating new openvpn interfaces the UI doesn't know which tunX
    interface to use so it leaves it unset. This process will go through
    and find the first available tunX interface for any openvpn interface
    without a device set
    """
    interfaces = settings.get('network').get('interfaces')
    for intf in interfaces:
        if intf.get("type") == "OPENVPN" and intf.get("device") is None:
            intf["device"] = find_lowest_available_tun(interfaces)

def find_lowest_available_tun(interfaces):
    """
    This loops throught the specified interfaces
    and finds the lowest available unused tunX device
    If no other tun devices exists tun0 is returned
    """
    available = list(range(0, 255))
    for intf in interfaces:
        if intf.get("device") is not None and intf.get("device").startswith("tun"):
            dev = intf["device"].replace("tun", "")
            try:
                available.remove(int(dev))
            except ValueError:
                raise Exception("Invalid tun interface: " + intf["device"])
    if not available:
        raise Exception("No available tun interfaces")
    else:
        return "tun" + str(available[0])


def find_lowest_available_interface_id(interfaces):
    """
    This loops throught the specified interfaces
    and finds the lowest available unused interfaceID
    """
    available = list(range(1, 254))
    for intf in interfaces:
        interface_id = intf.get("interfaceId")
        try:
            if interface_id is not None:
                available.remove(interface_id)
        except ValueError:
            raise Exception("Invalid interface ID: " + intf["interfaceId"])
    if not available:
        raise Exception("No available interface IDs")
    else:
        return available[0]

def create_settings_wwan_interface(interface, index):
    """create the default wwan settings"""
    if interface['name'] == "":
        interface['name'] = "WWAN" + str(index)
    interface['wan'] = True
    interface['enabled'] = True
    interface['simDelay'] = 10
    interface['simTimeout'] = 30
    interface['simMode'] = 'ALL'
    interface['simPdptype'] = 'IPV4'
    interface['configType'] = 'ADDRESSED'
    interface['v4ConfigType'] = 'DHCP'
    interface['v6ConfigType'] = 'DISABLED'
    interface['natEgress'] = True

def create_settings_internal_interface(interface, internal_count):
    """create the default internal settings"""
    if interface['name'] == "":
        if internal_count > 1:
            interface['name'] = 'internal%i' % internal_count
        else:
            interface['name'] = 'internal'
    interface['wan'] = False
    interface['enabled'] = True
    interface['configType'] = 'ADDRESSED'
    interface['v4ConfigType'] = 'STATIC'
    interface['v4StaticAddress'] = '192.168.%i.1' % internal_count
    interface['v4StaticPrefix'] = 24
    interface['dhcpEnabled'] = True
    interface['dhcpRangeStart'] = '192.168.%i.100' % internal_count
    interface['dhcpRangeEnd'] = '192.168.%i.200' % internal_count
    interface['dhcpLeaseDuration'] = 60*60
    interface['v6ConfigType'] = 'ASSIGN'
    interface['v6AssignPrefix'] = 64
    interface['v6AssignHint'] = '1234'
    if board_util.is_docker():
        interface['configType'] = 'ADDRESSED'
        interface['v4ConfigType'] = 'STATIC'
        interface['v4StaticAddress'] = "172.51.0.2"
        interface['v4StaticPrefix'] = 16
        interface['v6ConfigType'] = 'DISABLED'
        interface['dhcpEnabled'] = False

def create_settings_wan_interface(interface, index):
    """create the default wan settings"""
    if interface['name'] == "":
        interface['name'] = "WAN" + str(index)
    interface['wan'] = True
    interface['enabled'] = True
    interface['configType'] = 'ADDRESSED'
    interface['v4ConfigType'] = 'DHCP'
    interface['v6ConfigType'] = 'DHCP'
    interface['natEgress'] = True
    if board_util.is_docker():
        interface['configType'] = 'ADDRESSED'
        interface['v4ConfigType'] = 'STATIC'
        interface['v4StaticAddress'] = "172.50.0.2"
        interface['v4StaticPrefix'] = 16
        interface['v4StaticGateway'] = "172.50.0.1"
        interface['v4StaticDNS1'] = "8.8.8.8"
        interface['v4StaticDNS2'] = "8.8.4.4"
        interface['v6ConfigType'] = 'DISABLED'

registrar.register_manager(NetworkManager())
