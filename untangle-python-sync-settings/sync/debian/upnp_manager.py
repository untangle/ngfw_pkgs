import os
import stat
import sys
import subprocess
import datetime
import traceback
import re
from shutil import move
from sync.network_util import NetworkUtil
from sync import registrar,Manager

# This class is responsible for writing
# based on the settings object passed from sync-settings


class UpnpManager(Manager):
    upnp_daemon_conf_filename = "/etc/miniupnpd/miniupnpd.conf"
    restart_hook_filename = "/etc/untangle/post-network-hook.d/990-restart-upnp"
    iptables_filename = "/etc/untangle/iptables-rules.d/741-upnp"
    iptables_init_filename = "/etc/miniupnpd/iptables_init.sh"
    ip6tables_init_filename = "/etc/miniupnpd/ip6tables_init.sh"

    iptables_chain = "upnp-rules"

    def initialize(self):
        registrar.register_settings_file("network", self)
        registrar.register_file(self.upnp_daemon_conf_filename, "restart-miniupnpd", self)
        registrar.register_file(self.restart_hook_filename, "restart-miniupnpd", self)
        registrar.register_file(self.iptables_filename, "restart-iptables", self)
        registrar.register_file(self.iptables_init_filename, "restart-miniupnpd", self)
        registrar.register_file(self.ip6tables_init_filename, "restart-miniupnpd", self)

    def sync_settings(self, settings_file, prefix, delete_list):
        self.write_upnp_daemon_conf(settings_file.settings, prefix)
        self.write_restart_upnp_daemon_hook(settings_file.settings, prefix)
        self.write_iptables_hook(settings_file.settings, prefix)
        self.write_iptables_init_files(settings_file.settings, prefix)

    def write_upnp_daemon_conf(self, settings, prefix=""):
        """
        Create UPnP configuration file
        """
        filename = prefix + self.upnp_daemon_conf_filename
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        file = open(filename, "w+")
        file.write("## Auto Generated\n")
        file.write("## DO NOT EDIT. Changes will be overwritten.\n")

        wan_interfaces = []
        lan_interfaces = []
        for intf in settings['interfaces']:
            if intf.get('disabled'):
                continue
            if intf.get('isWan'):
                wan_interfaces.append(intf.get('symbolicDev'))
            else:
                lan_interfaces.append(intf.get('symbolicDev'))
        file.write("# Server options\n")
        # WAN interface
        for intf in wan_interfaces:
            file.write("ext_ifname=%s\n" % intf)
        # LAN interface
        for intf in lan_interfaces:
            file.write("listening_ip=%s\n" % intf)
        # LXC interface
        file.write("listening_ip=br.lxc\n")

        if settings.get('upnpSettings') == None or settings['upnpSettings'].get('upnpEnabled') is False:
            file.flush()
            file.close()
            os.chmod(filename, os.stat(filename).st_mode | stat.S_IEXEC)
            print("UpnpManager: Wrote %s" % filename)
            return

        file.write("port=%d\n" % settings['upnpSettings'].get('listenPort'))
        file.write("enable_natpmp=yes\n")
        file.write("enable_upnp=yes\n")
        # Secure mode
        file.write("secure_mode=%s\n" % ("yes" if settings['upnpSettings'].get('secureMode') is True else "no"))
        # file.write("lease_file=/var/lib/misc/upnp.leases\n")
        file.write("system_uptime=yes\n")

        file.write("upnp_forward_chain=%s\n" % (self.iptables_chain))
        file.write("upnp_nat_chain=%s\n" % (self.iptables_chain))

        file.write("\n# Client notifications\n")
        file.write("uuid=b014febc-1170-4421-9f04-852de5742a80\n")
        file.write("serial=12345678\n")
        file.write("model_number=1\n")

        file.write("\n# Rules\n")
        # Rules
        for rule in settings['upnpSettings']['upnpRules']:
            if rule.get('enabled') is False:
                continue
            upnp_rule_action = "allow" if rule.get('allow') else "deny"
            upnp_rule_external_ports = "0-65535"
            upnp_rule_internal_address = "0.0.0.0/0"
            upnp_rule_internal_ports = "0-65535"
            for condition in rule['conditions']:
                if condition.get('conditionType') == "DST_PORT":
                    upnp_rule_external_ports = condition.get('value')
                elif condition.get('conditionType') == "SRC_ADDR":
                    upnp_rule_internal_address = condition.get('value')
                elif condition.get('conditionType') == "SRC_PORT":
                    upnp_rule_internal_ports = condition.get('value')
            upnp_rule = " ".join([upnp_rule_action, upnp_rule_external_ports, upnp_rule_internal_address, upnp_rule_internal_ports])
            file.write("%s\n" % upnp_rule)

        # Write custom advanced options
        if settings['upnpSettings'].get('cystomOptions') != None:
            file.write("\# Custom  options\n")
            file.write("%s\b" % (settings['upnpSettings'].get('cystomOptions')))
            file.write("\n")

        file.write("\n")
        file.flush()
        file.close()

        print("UpnpManager: Wrote %s" % filename)
        return

    def write_restart_upnp_daemon_hook(self, settings, prefix=""):
        """
        Create network process extension to restart or stop daemon
        """
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

        if settings.get('upnpSettings') == None or settings['upnpSettings'].get('upnpEnabled') is False:
            file.write(r"""
UPNPD_PID="`pidof miniupnpd`"

# Stop miniupnpd if running
if [ ! -z "$UPNPD_PID" ] ; then
    systemctl --no-block stop miniupnpd
    #/etc/untangle/iptables-rules.d/741-upnp
fi
""")
        else:
            file.write(r"""
UPNPD_PID="`pidof miniupnpd`"

# Restart miniupnpd if it isnt found
# Or if miniupnpd.conf orhas been written since miniupnpd was started
if [ -z "$UPNPD_PID" ] ; then
    systemctl --no-block restart miniupnpd
# use not older than (instead of newer than) because it compares seconds and we want an equal value to still do a restart
elif [ ! /etc/miniupnpd/miniupnpd.conf -ot /proc/$UPNPD_PID ] ; then
    systemctl --no-block restart miniupnpd
fi
""")

        file.write("\n")
        file.flush()
        file.close()

        os.chmod(filename, os.stat(filename).st_mode | stat.S_IEXEC)
        print("UpnpManager: Wrote %s" % filename)
        return

    def write_iptables_hook(self, settings, prefix=""):
        """
        Create iptables configuraton for daemon
        """
        filename = prefix + self.iptables_filename
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
IPTABLES=${IPTABLES:-iptables}
CHAIN=%s

flush_upnp_iptables_rules()
{
    # Clean the nat tables
    ${IPTABLES} -t nat -F ${CHAIN} >/dev/null 2>&1
    ${IPTABLES} -t nat -D PREROUTING -m addrtype --dst-type local -j ${CHAIN} >/dev/null 2>&1
    ${IPTABLES} -t nat -X ${CHAIN} >/dev/null 2>&1

    # Clean the filter tables
    ${IPTABLES} -t filter -F ${CHAIN} >/dev/null 2>&1
    # Just create it, don't worry about jump.
    ${IPTABLES} -t filter -X ${CHAIN} >/dev/null 2>&1
}

insert_upnp_iptables_rules()
{
    # Initialize the PREROUTING chain first
    ${IPTABLES} -t nat -N ${CHAIN}
    ${IPTABLES} -t nat -A PREROUTING -m addrtype --dst-type local -j ${CHAIN}
    ${IPTABLES} -t nat -F ${CHAIN}

    # then do the FORWARD chain
    ${IPTABLES} -t filter -N ${CHAIN}
    # Just create the chain, don't worry about jump
    ${IPTABLES} -t filter -F ${CHAIN}
}

flush_upnp_iptables_rules

insert_upnp_iptables_rules

""" % (self.iptables_chain))

        file.write("\n")
        file.flush()
        file.close()

        os.chmod(filename, os.stat(filename).st_mode | stat.S_IEXEC)
        print("UpnpManager: Wrote %s" % filename)
        return

    def write_iptables_init_files(self, settings, prefix=""):
        """
        Overwrite miniupnpd package scripts
        The miniupnp packaging calls these scripts in the postinst
        We must overwrite them so they don't fail with an error
        """
        filename = prefix + self.iptables_init_filename
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)
        file = open(filename, "w+")
        file.write("#!/bin/sh\n")
        file.write("exit 0\n")
        file.flush()
        file.close()
        os.chmod(filename, os.stat(filename).st_mode | stat.S_IEXEC)
        print("UpnpManager: Wrote %s" % filename)

        filename = prefix + self.ip6tables_init_filename
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)
        file = open(filename, "w+")
        file.write("#!/bin/sh\n")
        file.write("exit 0\n")
        file.flush()
        file.close()
        os.chmod(filename, os.stat(filename).st_mode | stat.S_IEXEC)
        print("UpnpManager: Wrote %s" % filename)
        return


registrar.register_manager(UpnpManager())
