import os
import sys
import subprocess
import datetime
import traceback
from sync.iptables_util import IptablesUtil
from sync import registrar,Manager

# This class is responsible for writing /etc/untangle/iptables-rules.d/230-port-forward-rules
# based on the settings object passed from sync-settings


class PortForwardManager(Manager):
    iptables_filename = "/etc/untangle/iptables-rules.d/230-port-forward-rules"
    admin_filename = "/etc/untangle/iptables-rules.d/250-admin-port-rules"
    src_interface_mark_mask = 0x00ff
    filename = iptables_filename
    file = None

    def initialize(self):
        registrar.register_settings_file("network", self)
        registrar.register_file(self.iptables_filename, "restart-iptables", self)
        registrar.register_file(self.admin_filename, "restart-iptables", self)

    def sync_settings(self, settings_file, prefix, delete_list):
        self.write_port_forwards(settings_file.settings, prefix)
        self.write_admin_port_rules(settings_file.settings, prefix)

    def write_port_forward_rule(self, port_forward_rule):
        if 'enabled' in port_forward_rule and not port_forward_rule['enabled']:
            return
        if 'conditions' not in port_forward_rule:
            return
        if 'ruleId' not in port_forward_rule:
            return

        if 'newDestination' in port_forward_rule and 'newPort' in port_forward_rule:
            target = " -j DNAT --to-destination %s:%s " % (str(port_forward_rule['newDestination']), str(port_forward_rule['newPort']))
        elif 'newDestination' in port_forward_rule:
            target = " -j DNAT --to-destination %s " % str(port_forward_rule['newDestination'])
        else:
            print("ERROR: invalid port forward target: %s" + str(port_forward_rule))
            return

        description = "Port Forward Rule #%i" % int(port_forward_rule['ruleId'])
        commands = IptablesUtil.conditions_to_prep_commands(port_forward_rule['conditions'], description)
        iptables_conditions = IptablesUtil.conditions_to_iptables_string(port_forward_rule['conditions'], description)
        commands += ["${IPTABLES} -t nat -A port-forward-rules " + ipt + target for ipt in iptables_conditions]

        self.file.write("# %s\n" % description)
        for cmd in commands:
            self.file.write(cmd + "\n")
        self.file.write("\n")

        return

    def write_port_forward_rules(self, settings):
        if settings == None or 'portForwardRules' not in settings:
            print("ERROR: Missing Port Forward Rules")
            return

        port_forward_rules = settings['portForwardRules']

        for port_forward_rule in port_forward_rules:
            try:
                self.write_port_forward_rule(port_forward_rule)
            except Exception as e:
                traceback.print_exc()

    def write_port_forwards(self, settings, prefix=""):
        self.filename = prefix + self.iptables_filename
        self.file_dir = os.path.dirname(self.filename)
        if not os.path.exists(self.file_dir):
            os.makedirs(self.file_dir)

        self.file = open(self.filename, "w+")
        self.file.write("## Auto Generated\n")
        self.file.write("## DO NOT EDIT. Changes will be overwritten.\n")
        self.file.write("\n\n")

        # self.file.write("# enable hairpin mode for hairpin port forwards (bug #11899)" + "\n");
        # self.file.write("/usr/bin/find /sys/devices -type f -name hairpin_mode | while read file ; do echo 1 > $file ; done" + "\n" + "\n")

        self.file.write("# Create (if needed) and flush port-forward-rules chain" + "\n")
        self.file.write("${IPTABLES} -t nat -N port-forward-rules 2>/dev/null" + "\n")
        self.file.write("${IPTABLES} -t nat -F port-forward-rules >/dev/null 2>&1" + "\n" + "\n")

        self.file.write("# Call port-forward-rules chain from PREROUTING chain to forward traffic" + "\n")
        self.file.write("${IPTABLES} -t nat -D PREROUTING -m comment --comment \"Port Forward rules\" -j port-forward-rules >/dev/null 2>&1" + "\n")
        self.file.write("${IPTABLES} -t nat -A PREROUTING -m comment --comment \"Port Forward rules\" -j port-forward-rules" + "\n" + "\n")

        self.write_port_forward_rules(settings)

        self.file.flush()
        self.file.close()

        print("PortForwardManager: Wrote %s" % self.filename)

    def write_admin_port_rules(self, settings, prefix=""):
        self.filename = prefix + self.admin_filename
        self.file_dir = os.path.dirname(self.filename)
        if not os.path.exists(self.file_dir):
            os.makedirs(self.file_dir)

        self.file = open(self.filename, "w+")
        self.file.write("## Auto Generated\n")
        self.file.write("## DO NOT EDIT. Changes will be overwritten.\n")
        self.file.write("\n\n")

        https_port = settings.get('httpsPort')
        if not https_port:
            https_port = 443
        http_port = settings.get('httpPort')
        if not http_port:
            http_port = 80

        # write rules to protect (by redirecting) https port for all primary addresses
        # add rule to block at the end. If that point is reached then it hasn't been protected or port forwarded
        # The block rule exists so that when the port is changed from the default the original port won't still work
        for intf in settings.get('interfaces'):
            if intf.get('configType') == 'ADDRESSED':
                self.file.write("# forward HTTPS admin from intf %i to local apache process\n" % intf.get('interfaceId'))
                self.file.write("ADDR=\"`ip addr show %s | awk '/^ *inet.*scope global/ { interface = $2 ; sub( \"/.*\", \"\", interface ) ; print interface ; exit }'`\"\n" % intf.get('symbolicDev'))
                self.file.write("if [ ! -z \"${ADDR}\" ] ; then" + "\n")
                self.file.write("\t${IPTABLES} -t nat -I port-forward-rules -p tcp --destination ${ADDR} --destination-port %i -j DNAT --to-destination ${ADDR}:443 -m comment --comment \"Send ${ADDR}:%i to Apache\"" % (https_port, https_port) + "\n")
                # NGFW-13160 Enable admin GUI on alias IP addresses
                for alias in intf.get('v4Aliases'):
                    addr = alias.get('staticAddress')
                    if addr != None:
                        self.file.write("\t${IPTABLES} -t nat -A port-forward-rules -p tcp --destination %s --destination-port %i -j DNAT --to-destination %s:443 -m comment --comment \"Send %s:%i to Apache\"" % (addr, https_port, addr, addr, https_port) + "\n")
                self.file.write("fi" + "\n")
                self.file.write("\n")

        self.file.write("# If its local and port 443 and hasnt already been handled in this chain, block it\n")
        self.file.write("${IPTABLES} -t nat -A port-forward-rules -p tcp -m addrtype --dst-type local --destination-port 443 -j REDIRECT --to-ports 0 -m comment --comment \"Drop local HTTPS traffic that hasn't been handled earlier in chain\"" + "\n")
        self.file.write("\n")

        # write rules to protect http port for all non-WAN primary addresses
        # add rule to block at the end. If that point is reached then it hasn't been protected or port forwarded
        # The block rule exists so that when the port is changed from the default the original port won't still work
        for intf in settings.get('interfaces'):
            if intf.get('configType') == 'ADDRESSED' and not intf.get('isWan'):
                self.file.write("# don't allow port forwarding of http port of primary IP on non-WAN interface %i.\n" % intf.get('interfaceId'))
                self.file.write("ADDR=\"`ip addr show %s | awk '/^ *inet.*scope global/ { interface = $2 ; sub( \"/.*\", \"\", interface ) ; print interface ; exit }'`\"\n" % intf.get('symbolicDev'))
                self.file.write("if [ ! -z \"${ADDR}\" ] ; then" + "\n")
                self.file.write("\t${IPTABLES} -t nat -I port-forward-rules -p tcp --destination ${ADDR} --destination-port %i -j DNAT --to-destination ${ADDR}:80 -m comment --comment \"Send ${ADDR}:%i to Apache\"" % (http_port, http_port) + "\n")
                # NGFW-13160 Enable admin GUI on alias IP addresses
                for alias in intf.get('v4Aliases'):
                    addr = alias.get('staticAddress')
                    if addr != None:
                        self.file.write("\t${IPTABLES} -t nat -A port-forward-rules -p tcp --destination %s --destination-port %i -j DNAT --to-destination %s:80 -m comment --comment \"Send %s:%i to Apache\"" % (addr, http_port, addr, addr, http_port) + "\n")
                self.file.write("fi" + "\n")
                self.file.write("\n")

        self.file.write("# If its local and port 80 and hasnt already been handled in this chain, block it\n")
        self.file.write("${IPTABLES} -t nat -A port-forward-rules -p tcp -m addrtype --dst-type local --destination-port 80 -j REDIRECT --to-ports 0 -m comment --comment \"Drop local HTTP traffic that hasn't been handled earlier in chain\"" + "\n")
        self.file.write("\n")

        # write a rule to protect http port for primary address when coming from a bridged interface
        # add rule to block at the end. If that point is reached then it hasn't been protected or port forwarded
        # The block rule exists so that when the port is changed from the default the original port won't still work
        # This is for bridged cases. If the primary IP of external is 1.2.3.4 we want to reserve 1.2.3.4:80 for http, but ONLY from the inside so that port forwards work externally.
        for intf in settings.get('interfaces'):
            if intf.get('configType') == 'ADDRESSED' and intf.get('isWan'):
                # now find all interfaces bridged to this WAN
                for sub_intf in settings.get('interfaces'):
                    if sub_intf.get('configType') == 'BRIDGED' and sub_intf.get('bridgedTo') == intf.get('interfaceId'):
                        self.file.write("# don't allow port forwarding of http port of primary IP of WAN from bridged interface %i.\n" % sub_intf.get('interfaceId'))
                        self.file.write("ADDR=\"`ip addr show %s | awk '/^ *inet.*scope global/ { interface = $2 ; sub( \"/.*\", \"\", interface ) ; print interface ; exit }'`\"\n" % intf.get('symbolicDev'))
                        self.file.write("if [ ! -z \"${ADDR}\" ] ; then" + "\n")
                        self.file.write("\t${IPTABLES} -t nat -I port-forward-rules -p tcp -m mark --mark 0x%04X/0x%04X --destination ${ADDR} --destination-port %i -j DNAT --to-destination ${ADDR}:80 -m comment --comment \"Reserve port 80 on ${ADDR} for blockpages\"" % (sub_intf.get('interfaceId'), self.src_interface_mark_mask, http_port) + "\n")
                        self.file.write("\t${IPTABLES} -t nat -A port-forward-rules -p tcp -m mark --mark 0x%04X/0x%04X --destination ${ADDR} --destination-port 80 -j REDIRECT --to-ports 0 -m comment --comment \"Drop local HTTP traffic that hasn't been handled earlier in chain\"" % (sub_intf.get('interfaceId'), self.src_interface_mark_mask) + "\n")
                        self.file.write("fi" + "\n")
                        self.file.write("\n")

        self.file.write("\n\n")
        self.file.flush()
        self.file.close()

        print("PortForwardManager: Wrote %s" % self.filename)


registrar.register_manager(PortForwardManager())
