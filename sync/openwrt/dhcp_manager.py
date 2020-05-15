"""dhcp_manager manages dhcp & dnsmasq settings"""
# pylint: disable=unused-argument
# pylint: disable=no-self-use
# pylint: disable=too-many-branches
# pylint: disable=too-many-public-methods
# pylint: disable=too-many-locals
# pylint: disable=too-many-statements
import os
import ipaddress
from sync import registrar, Manager
from sync import network_util

class DhcpManager(Manager):
    """
    This class is responsible for writing /etc/config/dhcp
    based on the settings object passed from sync-settings
    """
    dhcp_filename = "/etc/config/dhcp"

    def initialize(self):
        """initialize this module"""
        registrar.register_settings_file("settings", self)
        registrar.register_file(self.dhcp_filename, "restart-dhcp", self)

    def validate_settings(self, settings_file):
        """validates settings"""
        dns_settings = settings_file.settings.get('dns')
        if dns_settings is not None:
            if dns_settings.get('localServers') is not None:
                for local_server in dns_settings.get('localServers'):
                    if local_server.get('domain') is None:
                        raise Exception('Missing domain in DNS local server')
                    if local_server.get('localServer') is None:
                        raise Exception('Missing localServer in DNS local server')
        dhcp_settings = settings_file.settings.get('dns')
        if dhcp_settings is not None:
            if dhcp_settings.get('staticDhcpEntries') is not None:
                for static_entry in dhcp_settings.get('staticDhcpEntries'):
                    if static_entry.get('macAddress') is None:
                        raise Exception('Missing macAddress in DHCP static entry')
                    if static_entry.get('address') is None:
                        raise Exception('Missing address in DHCP static entry')
        return

    def create_settings(self, settings_file, prefix, delete_list, filename):
        """creates settings"""
        print("%s: Initializing settings" % self.__class__.__name__)
        settings_file.settings['dns'] = {}
        settings_file.settings['dns']['localServers'] = []
        settings_file.settings['dns']['staticEntries'] = []

        settings_file.settings['dhcp'] = {}
        settings_file.settings['dhcp']['dhcpAuthoritative'] = True
        settings_file.settings['dhcp']['staticDhcpEntries'] = []

    def sync_settings(self, settings_file, prefix, delete_list):
        """syncs settings"""
        print("%s: Syncing settings" % self.__class__.__name__)
        self.write_dhcp_file(settings_file.settings, prefix)

    def write_dhcp_file(self, settings, prefix=""):
        """writes prefix/etc/config/dhcp"""
        filename = prefix + self.dhcp_filename
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        system = settings.get('system')
        dns = settings.get('dns')
        dhcp = settings.get('dhcp')

        file = open(filename, "w+")
        file.write("## Auto Generated\n")
        file.write("## DO NOT EDIT. Changes will be overwritten.\n")
        file.write("\n")
        file.write("config dnsmasq\n")

        interfaces = settings['network']['interfaces']
        for intf in interfaces:
            if intf.get('configType') == 'ADDRESSED' and intf.get('wan') is True and intf.get('v4ConfigType') == 'STATIC':
                if intf.get('v4StaticDNS1') != None:
                    file.write("\tlist server '%s'\n" % intf.get('v4StaticDNS1'))
                if intf.get('v4StaticDNS2') != None:
                    file.write("\tlist server '%s'\n" % intf.get('v4StaticDNS2'))

            if intf.get('configType') == 'ADDRESSED' and intf.get('wan') is True and intf.get('v4ConfigType') == 'PPPOE' and intf.get('v4PPPoEUsePeerDNS') is False:
                if intf.get('v4PPPoEDNS1') != None:
                    file.write("\tlist server '%s'\n" % intf.get('v4PPPoEDNS1'))
                if intf.get('v4PPPoEDNS2') != None:
                    file.write("\tlist server '%s'\n" % intf.get('v4PPPoEDNS2'))

        if dns.get('localServers') != None:
            for local_server in dns.get('localServers'):
                file.write("\tlist server '/%s/%s'\n" % (local_server.get('domain'), local_server.get('localServer')))

        if system.get('domainName') != None:
            file.write("\toption domain '%s'\n" % system.get('domainName'))

        file.write("\toption expandhosts '1'\n")
        file.write("\toption nonegcache '0'\n")
        if dhcp.get('dhcpAuthoritative') is True:
            file.write("\toption authoritative '1'\n")
        else:
            file.write("\toption authoritative '0'\n")

        file.write("\tlist interface '*'\n")
        file.write("\toption localise_queries '1'\n")
        file.write("\toption nohosts '1'\n")
        file.write("\toption domainneeded '0'\n")
        file.write("\toption boguspriv '0'\n")
        file.write("\toption filterwin2k '0'\n")
        file.write("\toption readethers '0'\n")
        file.write("\toption rebind_protection '0'\n")
        file.write("\toption rebind_localhost '0'\n")
        file.write("\toption nonwildcard '0'\n")
        file.write("\toption localservice '0'\n")
        file.write("\toption dhcpleasemax '5000'\n")
        file.write("\toption leasefile '/tmp/dhcp.leases'\n")
        file.write("\toption resolvfile '/tmp/resolv.conf.auto'\n")
        file.write("\tlist addnhosts '/tmp/hosts.untangle'\n")

        file.write("\n")

        dhcpv6_in_use = False
        for intf in interfaces:
            if intf.get('configType') == 'ADDRESSED':
                interface_name = network_util.get_interface_name(settings, intf)

                file.write("config dhcp '%s'\n" % interface_name)
                if intf.get('dhcpEnabled') is True:
                    if intf.get('v4ConfigType') != 'DISABLED':
                        file.write("\toption interface '%s'\n" % interface_name)
                        file.write("\toption start '%d'\n" % calc_dhcp_range_start(intf.get('v4StaticAddress'), intf.get('v4StaticPrefix'),
                                                                                   intf.get('dhcpRangeStart')))
                        file.write("\toption limit '%d'\n" % calc_dhcp_range_limit(intf.get('dhcpRangeStart'), intf.get('dhcpRangeEnd')))

                        if intf.get('dhcpLeaseDuration') != None and intf.get('dhcpLeaseDuration') != 0:
                            file.write("\toption leasetime '%d'\n" % intf.get('dhcpLeaseDuration'))
                        else:
                            file.write("\toption leasetime '3600'\n")

                        if intf.get('dhcpGatewayOverride') != None and intf.get('dhcpGatewayOverride') != "" and intf.get('dhcpGatewayOverride') != 0:
                            file.write("\tlist dhcp_option '3,%s'\n" % intf.get('dhcpGatewayOverride'))
                        else:
                            file.write("\tlist dhcp_option '3,%s'\n" % intf.get('v4StaticAddress'))

                        if intf.get('dhcpPrefixOverride') != None and intf.get('dhcpPrefixOverride') != "" and intf.get('dhcpPrefixOverride') != 0:
                            file.write("\tlist dhcp_option '1,%s'\n" % network_util.ipv4_prefix_to_netmask(intf.get('dhcpPrefixOverride')))
                        else:
                            file.write("\tlist dhcp_option '1,%s'\n" % network_util.ipv4_prefix_to_netmask(intf.get('v4StaticPrefix')))

                        if intf.get('dhcpDNSOverride') != None and intf.get('dhcpDNSOverride') != "":
                            dns_servers = intf.get('dhcpDNSOverride')
                        else:
                            dns_servers = intf.get('v4StaticAddress')

                        file.write("\tlist dhcp_option '6,%s'\n" % dns_servers)

                        if intf.get('dhcpOptions') != None:
                            for dhcp_option in intf.get('dhcpOptions'):
                                if dhcp_option.get('enabled') is None or not dhcp_option.get('enabled'):
                                    continue
                                file.write("\tlist dhcp_option '%s'\n" % dhcp_option.get('value'))

                    if intf.get('v6ConfigType') != 'DISABLED':
                        dhcpv6_in_use = True
                        if intf.get('v6RelayEnabled'):
                            write_relay_options(file, intf.get('isWan'))
                        else:
                            file.write("\toption dhcpv6 'server'\n")
                            file.write("\toption ra 'server'\n")

                    file.write("\n")
                else:
                    file.write("\toption interface '%s'\n" % interface_name)
                    if intf.get('v6RelayEnabled'):
                        write_relay_options(file, intf.get('wan'))
                    else: 
                        file.write("\toption ignore '1'\n")
                    file.write("\n")

        if dhcpv6_in_use is True:
            file.write("config odhcpd 'odhcpd'\n")
            file.write("\toption maindhcp '0'\n")
            file.write("\toption leasefile '/tmp/hosts/odhcpd'\n")
            file.write("\toption leasetrigger '/usr/sbin/odhcpd-update'\n")
            file.write("\toption loglevel '4'\n")
            file.write("\n")

        if dns.get('staticEntries') != None:
            for entry in dns.get('staticEntries'):
                if entry.get('name') != None and entry.get('address') != None:
                    file.write("config 'domain'\n")
                    file.write("\toption name '%s'\n" % entry.get('name'))
                    file.write("\toption ip '%s'\n" % entry.get('address'))
                    file.write("\n")

        if dhcp.get('staticDhcpEntries') != None:
            for entry in dhcp.get('staticDhcpEntries'):
                if entry.get('macAddress') != None and entry.get('address') != None:
                    file.write("config 'host'\n")
                    file.write("\toption ip '%s'\n" % entry.get('address'))
                    file.write("\toption mac '%s'\n" % entry.get('macAddress'))
                    file.write("\n")

        file.flush()
        file.close()

        print("%s: Wrote %s" % (self.__class__.__name__, filename))

def write_relay_options(file, isWan):
    file.write("\toption dhcpv6 'relay'\n")
    file.write("\toption ra 'relay'\n")
    file.write("\toption ndp 'relay'\n")
    if isWan:
        file.write("\toption master '1'\n")

def calc_dhcp_range_start(ip, prefix, start):
    """calucale a good dhcp range start"""
    ip_int = int(ipaddress.IPv4Address(ip))
    netmask_int = int(ipaddress.IPv4Address(network_util.ipv4_prefix_to_netmask(prefix)))
    start_int = int(ipaddress.IPv4Address(start))
    return start_int - (ip_int & netmask_int)


def calc_dhcp_range_limit(start, end):
    """calucale a good dhcp range limit"""
    start_int = int(ipaddress.IPv4Address(start))
    end_int = int(ipaddress.IPv4Address(end))
    return end_int - start_int + 1


registrar.register_manager(DhcpManager())
