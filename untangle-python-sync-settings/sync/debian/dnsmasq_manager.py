import os
import stat
import sys
import subprocess
import datetime
import traceback
import re
from sync.network_util import NetworkUtil
from sync import registrar, Manager

# This class is responsible for writing
# based on the settings object passed from sync-settings


class DnsMasqManager(Manager):
    dnsmasq_hosts_filename = "/etc/hosts.dnsmasq"
    dnsmasq_conf_filename = "/etc/dnsmasq.conf"
    restart_hook_filename = "/etc/untangle/post-network-hook.d/990-restart-dnsmasq"
    dhcp_statics_filename = "/etc/dnsmasq.d/dhcp-static"

    def initialize(self):
        registrar.register_settings_file("network", self)
        # dnsmasq settings, requires dnsmasq restart
        registrar.register_file(self.dnsmasq_hosts_filename, "restart-dnsmasq", self)
        registrar.register_file(self.dnsmasq_conf_filename, "restart-dnsmasq", self)
        registrar.register_file(self.dhcp_statics_filename, "restart-dnsmasq", self)
        # Just a restart script, no need to restart if changed
        registrar.register_file(self.restart_hook_filename, None, self)

    def sync_settings(self, settings_file, prefix, delete_list):
        self.write_dnsmasq_hosts(settings_file.settings, prefix)
        self.write_dhcp_statics_file(settings_file.settings, prefix)
        self.write_dnsmasq_conf(settings_file.settings, prefix)
        self.write_restart_dnsmasq_hook(settings_file.settings, prefix)
        return

    def write_dnsmasq_hosts(self, settings, prefix):
        filename = prefix + self.dnsmasq_hosts_filename
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        file = open(filename, "w+")
        file.write("## Auto Generated\n")
        file.write("## DO NOT EDIT. Changes will be overwritten.\n")
        file.write("\n\n")

        file.write("# user-defined static entries \n")
        if (settings.get('dnsSettings') != None and
                settings.get('dnsSettings').get('staticEntries') != None):
            for entry in settings.get('dnsSettings').get('staticEntries'):
                if entry.get('name') != None and entry.get('address') != None:
                    file.write("%s\t%s" % (entry.get('address'), entry.get('name')) + "\n")
            file.write("\n")

        file.write("\n")

        file.flush()
        file.close()

        print("DnsMasqManager: Wrote %s" % filename)
        return

    def write_dnsmasq_conf(self, settings, prefix=""):
        filename = prefix + self.dnsmasq_conf_filename
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        file = open(filename, "w+")
        file.write("## Auto Generated\n")
        file.write("## DO NOT EDIT. Changes will be overwritten.\n")
        file.write("\n\n")

        for intf in settings['interfaces']:
            # If its a static WAN then write the uplink DNS values
            if intf.get('configType') == 'ADDRESSED' and intf.get('isWan') == True and intf.get('v4ConfigType') == 'STATIC':
                if intf.get('v4StaticDns1') != None:
                    file.write("# Interface %s DNS 1" % str(intf.get('interfaceId')) + "\n")
                    file.write("server=%s # uplink.%s" % (intf.get('v4StaticDns1'), str(intf.get('interfaceId'))) + "\n")
                    file.write("\n")
                if intf.get('v4StaticDns2') != None:
                    file.write("# Interface %s DNS 2" % str(intf.get('interfaceId')) + "\n")
                    file.write("server=%s # uplink.%s" % (intf.get('v4StaticDns2'), str(intf.get('interfaceId'))) + "\n")
                    file.write("\n")
            # If its a PPPoE WAN then write the uplink DNS values if UserPeerDns is disabled
            if intf.get('configType') == 'ADDRESSED' and intf.get('isWan') == True and intf.get('v4ConfigType') == 'PPPOE' and intf.get('v4PPPoEUsePeerDns') == False:
                if intf.get('v4PPPoEDns1') != None:
                    file.write("# Interface %s DNS 1" % str(intf.get('interfaceId')) + "\n")
                    file.write("server=%s # uplink.%s" % (intf.get('v4PPPoEDns1'), str(intf.get('interfaceId'))) + "\n")
                    file.write("\n")
                if intf.get('v4PPPoEDns2') != None:
                    file.write("# Interface %s DNS 2" % str(intf.get('interfaceId')) + "\n")
                    file.write("server=%s # uplink.%s" % (intf.get('v4PPPoEDns2'), str(intf.get('interfaceId'))) + "\n")
                    file.write("\n")
            # If its a dhcp WAN then write the some comments for clarity
            if intf.get('configType') == 'ADDRESSED' and intf.get('isWan') == True and intf.get('v4ConfigType') == 'AUTO':
                file.write("# Interface %s DNS" % str(intf.get('interfaceId')) + "\n")
                file.write("# stored in /etc/dnsmasq.d/dhcp-upstream-dns-servers" + "\n")
                file.write("\n")

        # Set globla options
        file.write("# Global DNS options\n")
        file.write("interface=* # specified so local-service option is disabled\n")
        file.write("localise-queries\n")
        file.write("expand-hosts\n")
        # dont read /etc/hosts - this will result in returning 127.0.0.1 for some queries
        file.write("no-hosts\n")
        file.write("addn-hosts=/etc/hosts.dnsmasq\n")
        # use a dedicated file for the interface specific feature where dnsmasq returns the
        # most appropriate IP based on the interface address where the query was received
        file.write("addn-hosts=/etc/hosts.untangle\n")
        file.write("\n")

        # Set global DHCP options
        file.write("# Global DHCP options\n")
        if (settings.get('dhcpAuthoritative') == True):
            file.write("dhcp-authoritative\n")
        file.write("dhcp-lease-max=5000\n")  # should this be configurable?
        file.write("dns-forward-max=512\n")
        file.write("\n")

        # Enable DHCP on internal NICs (where configured)
        for intf in settings['interfaces']:
            if intf.get('configType') == 'ADDRESSED' and intf.get('isWan') == False:
                if intf.get('dhcpEnabled') == True:
                    leaseTime = 3600
                    if intf.get('dhcpLeaseDuration') != None and intf.get('dhcpLeaseDuration') != "":
                        try:
                            leaseTime = int(intf.get('dhcpLeaseDuration'))
                        except Exception as e:
                            pass

                    # Use symbolicDev so the whole bridge is served if its a bridge
                    file.write("# Interface %s (%s) DHCP" % (str(intf.get('interfaceId')), intf.get('symbolicDev')) + "\n")
                    file.write("dhcp-range=tag:%s,%s,%s,%i" % (intf.get('symbolicDev'), str(intf.get('dhcpRangeStart')), str(intf.get('dhcpRangeEnd')), leaseTime) + "\n")

                    # set gateway option
                    # If the override value is specified, set it, otherwise use static address (ourselves) as gateway
                    if intf.get('dhcpGatewayOverride') != None and intf.get('dhcpGatewayOverride') != "":
                        file.write("dhcp-option=tag:%s,3,%s # gateway" % (intf.get('symbolicDev'), str(intf.get('dhcpGatewayOverride'))) + "\n")
                    else:
                        file.write("dhcp-option=tag:%s,3,%s # gateway" % (intf.get('symbolicDev'), str(intf.get('v4StaticAddress'))) + "\n")

                    # set netmask option
                    # If the override value is specified, set it, otherwise use static netmask
                    if intf.get('dhcpNetmaskOverride') != None and intf.get('dhcpNetmaskOverride') != "":
                        file.write("dhcp-option=tag:%s,1,%s # netmask" % (intf.get('symbolicDev'), str(intf.get('dhcpNetmaskOverride'))) + "\n")
                    else:
                        file.write("dhcp-option=tag:%s,1,%s # netmask" % (intf.get('symbolicDev'), str(intf.get('v4StaticNetmask'))) + "\n")

                    # set dns option
                    # If the override value is specified, set it, otherwise use static address (ourselves) as DNS
                    if intf.get('dhcpDnsOverride') != None and intf.get('dhcpDnsOverride') != "":
                        file.write("dhcp-option=tag:%s,6,%s # dns" % (intf.get('symbolicDev'), str(intf.get('dhcpDnsOverride'))) + "\n")
                    else:
                        file.write("dhcp-option=tag:%s,6,%s # dns" % (intf.get('symbolicDev'), str(intf.get('v4StaticAddress'))) + "\n")

                    # write custom DHCP options
                    if intf.get('dhcpOptions') != None:
                        for dhcpOption in intf.get('dhcpOptions'):
                            if dhcpOption.get('enabled') == None or not dhcpOption.get('enabled'):
                                continue
                            file.write("dhcp-option=tag:%s,%s # custom dhcp option" % (intf.get('symbolicDev'), dhcpOption.get('value')) + "\n")

                    file.write("\n")

        # Write domain
        if settings.get('domainName') != None:
            file.write("# domain\n")
            file.write("domain=%s" % (settings.get('domainName')) + "\n")
            file.write("\n")

        # Local DNS servers
        file.write("# Local DNS servers\n")
        if (settings.get('dnsSettings') != None and
                settings.get('dnsSettings').get('localServers') != None):
            for localServer in settings.get('dnsSettings').get('localServers'):
                if localServer.get('domain') != None and localServer.get('localServer') != None:
                    file.write("local=/%s/%s" % (localServer['domain'], localServer['localServer']) + "\n")
            file.write("\n")

        # Write custom advanced options
        if settings.get('dnsmasqOptions') != None:
            file.write("# Custom dnsmasq options\n")
            file.write("%s" % (settings.get('dnsmasqOptions')) + "\n")
            file.write("\n")

        file.write("\n")
        file.flush()
        file.close()

        print("DnsMasqManager: Wrote %s" % filename)
        return

    def write_dhcp_statics_file(self, settings, prefix=""):
        filename = prefix + self.dhcp_statics_filename
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        file = open(filename, "w+")

        # Static DHCP Entries
        file.write("# Static DHCP entries\n")
        if (settings.get('staticDhcpEntries') != None):
            for staticDhcpEntry in settings.get('staticDhcpEntries'):
                if staticDhcpEntry.get('macAddress') != None and staticDhcpEntry.get('address') != None:
                    file.write("dhcp-host=%s,%s" % (staticDhcpEntry.get('macAddress'), staticDhcpEntry.get('address')) + "\n")
            file.write("\n")

        file.write("\n")
        file.flush()
        file.close()

        print("DnsMasqManager: Wrote %s" % filename)
        return

    def write_restart_dnsmasq_hook(self, settings, prefix=""):
        filename = prefix + self.restart_hook_filename
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        file = open(filename, "w+")
        file.write("#!/bin/dash")
        file.write("\n\n")

        file.write("## Auto Generated\n")
        file.write("## DO NOT EDIT. Changes will be overwritten.\n")
        file.write("\n")

        file.write(r"""
DNSMASQ_PID="`pidof dnsmasq`"

# Restart dnsmasq if it isnt found
# Or if dnsmasq.conf or hosts.dnsmasq has been written since dnsmasq was started
if [ -z "$DNSMASQ_PID" ] ; then
    systemctl --no-block restart dnsmasq
# use not older than (instead of newer than) because it compares seconds and we want an equal value to still do a restart
elif [ ! /etc/dnsmasq.conf -ot /proc/$DNSMASQ_PID ] ; then
    systemctl --no-block restart dnsmasq
# use not older than (instead of newer than) because it compares seconds and we want an equal value to still do a restart
elif [ ! /etc/hosts.dnsmasq -ot /proc/$DNSMASQ_PID ] ; then
    systemctl --no-block restart dnsmasq
fi
""")

        file.write("\n")
        file.flush()
        file.close()

        os.chmod(filename, os.stat(filename).st_mode | stat.S_IEXEC)
        print("DnsMasqManager: Wrote %s" % filename)
        return


registrar.register_manager(DnsMasqManager())
