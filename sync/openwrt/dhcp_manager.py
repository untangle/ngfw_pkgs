import os
import stat
import sys
import subprocess
import datetime
import traceback
import re
import ipaddress
from sync import registrar
from sync import network_util

# This class is responsible for writing /etc/config/dhcp
# based on the settings object passed from sync-settings


class DhcpManager:
    dhcp_filename = "/etc/config/dhcp"

    def initialize(self):
        registrar.register_file(self.dhcp_filename, "restart-dhcp", self)

    def sanitize_settings(self, settings):
        pass

    def validate_settings(self, settings):
        pass

    def create_settings(self, settings, prefix, delete_list, filename):
        print("%s: Initializing settings" % self.__class__.__name__)
        settings['dns'] = {}
        settings['dns']['localServers'] = []
        settings['dns']['staticEntries'] = []

        settings['dhcp'] = {}
        settings['dhcp']['dhcpAuthoritative'] = True
        settings['dhcp']['staticDhcpEntries'] = []

    def sync_settings(self, settings, prefix, delete_list):
        print("%s: Syncing settings" % self.__class__.__name__)
        self.write_dhcp_file(settings, prefix)

    def write_dhcp_file(self, settings, prefix=""):
        filename = prefix + self.dhcp_filename
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        system = settings.get('system')
        dns = settings.get('dns')
        dhcp = settings.get('dhcp')

        self.network_file = open(filename, "w+")
        file = self.network_file
        file.write("## Auto Generated\n")
        file.write("## DO NOT EDIT. Changes will be overwritten.\n")
        file.write("\n")
        file.write("config dnsmasq\n")

        interfaces = settings['network']['interfaces']
        for intf in interfaces:
            if intf.get('configType') == 'ADDRESSED' and intf.get('wan') == True and intf.get('v4ConfigType') == 'STATIC':
                if intf.get('v4StaticDNS1') != None:
                    file.write("\tlist server '%s'\n" % intf.get('v4StaticDNS1'))
                if intf.get('v4StaticDNS2') != None:
                    file.write("\tlist server '%s'\n" % intf.get('v4StaticDNS2'))

            if intf.get('configType') == 'ADDRESSED' and intf.get('wan') == True and intf.get('v4ConfigType') == 'PPPOE' and intf.get('v4PPPoEUsePeerDNS') == False:
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
        if dhcp.get('dhcpAuthoritative') == True:
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
                if intf.get('dhcpEnabled') == True:
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
                            DNSServers = intf.get('dhcpDNSOverride')
                        else:
                            DNSServers = intf.get('v4StaticAddress')

                        file.write("\tlist dhcp_option '6,%s'\n" % DNSServers)

                        if intf.get('dhcpOptions') != None:
                            for dhcpOption in intf.get('dhcpOptions'):
                                if dhcpOption.get('enabled') == None or not dhcpOption.get('enabled'):
                                    continue
                                file.write("\tlist dhcp_option '%s'\n" % dhcpOption.get('value'))

                    if intf.get('v6ConfigType') != 'DISABLED':
                        dhcpv6_in_use = True
                        file.write("\toption dhcpv6 'server'\n")
                        file.write("\toption ra 'server'\n")

                    file.write("\n")
                else:
                    file.write("\toption interface '%s'\n" % interface_name)
                    file.write("\toption ignore '1'\n")
                    file.write("\n")

        if dhcpv6_in_use == True:
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


def calc_dhcp_range_start(ip, prefix, start):
    ip_int = int(ipaddress.IPv4Address(ip))
    netmask_int = int(ipaddress.IPv4Address(network_util.ipv4_prefix_to_netmask(prefix)))
    start_int = int(ipaddress.IPv4Address(start))
    return start_int - (ip_int & netmask_int)


def calc_dhcp_range_limit(start, end):
    start_int = int(ipaddress.IPv4Address(start))
    end_int = int(ipaddress.IPv4Address(end))
    return end_int - start_int + 1


registrar.register_manager(DhcpManager())
