import os
import stat
import sys
import subprocess
import datetime
import traceback
import re
from sync.network_util import NetworkUtil
from sync import registrar,Manager

# This class is responsible for writing:
# /etc/untangle/post-network-hook.d/200-vrrp
# based on the settings object passed from sync-settings


class VrrpManager(Manager):
    keepalived_conf_filename = "/etc/keepalived/keepalived.conf"
    post_network_hook_filename = "/etc/untangle/post-network-hook.d/200-vrrp"
    iptables_hook_filename = "/etc/untangle/iptables-rules.d/241-vrrp-rules"
    vrrp_enabled = False

    def initialize(self):
        registrar.register_settings_file("network", self)
        registrar.register_file(self.keepalived_conf_filename, "restart-keepalived", self)
        registrar.register_file(self.post_network_hook_filename, "restart-networking", self)
        registrar.register_file(self.iptables_hook_filename, "restart-iptables", self)

    def sync_settings(self, settings_file, prefix, delete_list):
        self.write_keepalivd_conf(settings_file.settings, prefix)
        self.write_post_network_hook(settings_file.settings, prefix)
        self.write_iptables_hook(settings_file.settings, prefix)

    def get_vrrp_interfaces(self, settings):
        vrrp_interfaces = []
        for interface_settings in settings['interfaces']:
            if interface_settings.get('vrrpEnabled'):
                if interface_settings.get('configType') != 'ADDRESSED':
                    continue
                if not interface_settings.get('vrrpId') or not interface_settings.get('vrrpPriority'):
                    print("Missing VRRP Config: %s, %s" % (interface_settings.get('vrrpId'), interface_settings.get('vrrpPriority')))
                    continue
                if not interface_settings.get('vrrpAliases') or not interface_settings.get('vrrpAliases'):
                    print("Missing VRRP Aliases: %s" % (str(interface_settings.get('vrrpAliases'))))
                    continue
                if len(interface_settings.get('vrrpAliases')) < 1:
                    print("Missing VRRP Aliases (0 length): %i" % (len(interface_settings.get('vrrpAliases'))))
                    continue
                vrrp_interfaces.append(interface_settings)

        return vrrp_interfaces

    def write_keepalivd_conf(self, settings, prefix=""):
        filename = prefix + self.keepalived_conf_filename
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        vrrp_interfaces = self.get_vrrp_interfaces(settings)

        file = open(filename, "w+")
        file.write("! Auto Generated\n")
        file.write("! DO NOT EDIT. Changes will be overwritten.\n")
        file.write("\n\n")

        if len(vrrp_interfaces) < 1:
            file.flush()
            file.close()
            print("VrrpManager: Wrote %s" % filename)
            return

        file.write(r"""
global_defs {
}
""")
        file.write("\n\n")

        file.write("vrrp_sync_group VRRPGROUP {" + "\n")
        file.write("\tgroup {" + "\n")
        for intf in vrrp_interfaces:
            file.write("\t\tVI_" + str(intf.get('interfaceId')) + "\n")
        file.write("\t}" + "\n")
        file.write("}" + "\n")
        file.write("\n\n")

        for intf in vrrp_interfaces:
            main_list = intf.get('vrrpAliases')

            file.write("vrrp_instance VI_" + str(intf.get('interfaceId')) + " {" + "\n")
            file.write("\tstate MASTER" + "\n")
            # file.write("\tdont_track_primary" + "\n") # http://s.co.tt/2014/06/06/fix-for-keepalived-router-enters-fault-state-on-link-down/
            file.write("\tinterface %s" % str(intf.get('symbolicDev')) + "\n")
            file.write("\tlvs_sync_daemon_interface %s" % str(intf.get('symbolicDev')) + "\n")
            file.write("\tvirtual_router_id %s" % str(intf.get('vrrpId')) + "\n")
            file.write("\tpriority %s" % str(intf.get('vrrpPriority')) + "\n")
            file.write("\tadvert_int 1" + "\n")

            file.write("\tvirtual_ipaddress {" + "\n")
            for alias in main_list:
                file.write("\t\t%s/%s" % (str(alias.get('staticAddress')), str(alias.get('staticPrefix'))) + "\n")
            file.write("\t}" + "\n")

            file.write("}" + "\n")
            file.write("\n\n")
        file.write("\n\n")

        file.flush()
        file.close()
        print("VrrpManager: Wrote %s" % filename)
        return

    def write_post_network_hook(self, settings, prefix=""):
        filename = prefix + self.post_network_hook_filename
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        file = open(filename, "w+")
        file.write("#!/bin/dash")
        file.write("\n\n")

        file.write("## Auto Generated\n")
        file.write("## DO NOT EDIT. Changes will be overwritten.\n")
        file.write("\n\n")

        file.write(r"""
if [ ! -z "`pidof keepalived`" ] ; then
    killall keepalived
    sleep 5
    killall -9 keepalived
fi
""")
        file.write("\n\n")

        vrrp_interfaces = self.get_vrrp_interfaces(settings)
        if len(vrrp_interfaces) > 0:
            self.vrrp_enabled = True
        else:
            self.vrrp_enabled = False

        if self.vrrp_enabled:
            file.write("if lsmod | grep -q ip_vs ; then" + "\n")
            file.write("\ttrue # do nothing" + "\n")
            file.write("else" + "\n")
            file.write("\techo Loading ip_vs kernel module..." + "\n")
            file.write("\tmodprobe ip_vs" + "\n")
            file.write("fi" + "\n")
            file.write("\n")

            file.write("/usr/sbin/keepalived --vrrp -f /etc/keepalived/keepalived.conf --dump-conf --log-console --log-detail" + "\n")
        else:
            file.write("if lsmod | grep -q ip_vs ; then" + "\n")
            file.write("\techo Unloading ip_vs kernel module..." + "\n")
            file.write("\tmodprobe -r ip_vs" + "\n")
            file.write("else" + "\n")
            file.write("\ttrue # do nothing" + "\n")
            file.write("fi" + "\n")
            file.write("\n")

        file.write("\n\n")

        file.flush()
        file.close()

        os.chmod(filename, os.stat(filename).st_mode | stat.S_IEXEC)
        print("VrrpManager: Wrote %s" % filename)

        return

    def write_iptables_hook(self, settings, prefix=""):
        filename = prefix + self.iptables_hook_filename
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        file = open(filename, "w+")
        file.write("#!/bin/dash")
        file.write("\n\n")

        file.write("## Auto Generated\n")
        file.write("## DO NOT EDIT. Changes will be overwritten.\n")
        file.write("\n\n")

        if self.vrrp_enabled:
            file.write("${IPTABLES} -t filter -I access-rules -p vrrp -m comment --comment \"Allow VRRP\" -j RETURN" + "\n")

        file.flush()
        file.close()

        os.chmod(filename, os.stat(filename).st_mode | stat.S_IEXEC)
        print("VrrpManager: Wrote %s" % filename)

        return


registrar.register_manager(VrrpManager())
