import os
import sys
import subprocess
import datetime
import traceback
from sync.iptables_util import IptablesUtil
from sync.network_util import NetworkUtil
from sync import registrar,Manager

# This class is responsible for writing /etc/untangle/iptables-rules.d/210-bypass-rules
# based on the settings object passed from sync-settings


class BypassRuleManager(Manager):
    bypass_mark_mask = 0x01000000
    interfaces_mark_mask = 0x0000FFFF

    bypass_rules_filename = "/etc/untangle/iptables-rules.d/210-bypass-rules"
    filename = bypass_rules_filename
    file = None

    def initialize(self):
        registrar.register_settings_file("network", self)
        registrar.register_file(self.bypass_rules_filename, "restart-iptables", self)

    def sync_settings(self, settings_file, prefix, delete_list):
        self.write_files(settings_file.settings, prefix)

    def write_bypass_rule(self, bypass_rule):
        if 'enabled' in bypass_rule and not bypass_rule['enabled']:
            return
        if 'conditions' not in bypass_rule:
            return
        if 'ruleId' not in bypass_rule:
            return

        bypass = None
        if 'bypass' in bypass_rule and bypass_rule['bypass']:
            target = " --goto set-bypass-mark "
        elif 'bypass' in bypass_rule and not bypass_rule['bypass']:
            target = " -j RETURN "
        else:
            print("ERROR: invalid bypass target: %s" + str(bypass_rule))
            return

        description = "Bypass Rule #%i" % int(bypass_rule['ruleId'])
        commands = IptablesUtil.conditions_to_prep_commands(bypass_rule['conditions'], description)
        iptables_conditions = IptablesUtil.conditions_to_iptables_string(bypass_rule['conditions'], description)
        commands += ["${IPTABLES} -t filter -A bypass-rules " + ipt + target for ipt in iptables_conditions]

        self.file.write("# %s\n" % description)
        for cmd in commands:
            self.file.write(cmd + "\n")
        self.file.write("\n")

        return

    def write_bypass_rules(self, settings):
        if settings == None or 'bypassRules' not in settings:
            print("ERROR: Missing Bypass Rules")
            return

        bypass_rules = settings['bypassRules']

        self.file.write("# Implicit Bypass Rules (loopback)" + "\n")
        self.file.write("${IPTABLES} -t filter -A bypass-rules -i lo --goto set-bypass-mark -m comment --comment \"Bypass loopback traffic\"" + "\n")
        self.file.write("${IPTABLES} -t filter -A bypass-rules -o lo --goto set-bypass-mark -m comment --comment \"Bypass loopback traffic\"" + "\n")
        self.file.write("\n")

        # If its RELATED, it must be RELATED to an already bypassed session, so bypass it also
        self.file.write("# Implicit Bypass Rules (RELATED)" + "\n")
        self.file.write("${IPTABLES} -t filter -A bypass-rules -m conntrack --ctstate RELATED --goto set-bypass-mark -m comment --comment \"Bypass RELATED sessions\"" + "\n")
        self.file.write("\n")

        # We bypass DHCP reply traffic, because the host doesn't technically have an address yet, so our destination interface lookup will fail.
        # This assures its just sent across the bridge in normal fashion
        self.file.write("# Implicit Bypass Rules (DHCP)" + "\n")
        self.file.write("${IPTABLES} -t filter -A bypass-rules -p udp --source-port 67:68 --destination-port 67:68 --goto set-bypass-mark -m comment --comment \"Bypass DHCP traffic\"" + "\n")
        self.file.write("\n")

        # We bypass routing protocols
        # http://www.iana.org/assignments/multicast-addresses/multicast-addresses.xhtml
        self.file.write("# Implicit Bypass Rules (multicast)" + "\n")
        self.file.write("${IPTABLES} -t filter -A bypass-rules --destination 224.0.0.0/4 --goto set-bypass-mark -m comment --comment \"Bypass 224 traffic\"" + "\n")
        self.file.write("\n")

        # We bypass 'hairpin' traffic because end-pointing it at layer 7 wouldn't work because two sessions would have identical tuples
        self.file.write("# Implicit Bypass Rules (hairpin)" + "\n")
        for intfId in NetworkUtil.interface_list():
            self.file.write("${IPTABLES} -t filter -A bypass-rules -m mark --mark 0x%X/0x%X --goto set-bypass-mark -m comment --comment \"Bypass hairpin traffic (interface %s)\"" % ((intfId+(intfId << 8)), self.interfaces_mark_mask, str(intfId)) + "\n")
        self.file.write("\n")

        # Add the user bypass rules
        for bypass_rule in bypass_rules:
            try:
                self.write_bypass_rule(bypass_rule)
            except Exception as e:
                traceback.print_exc()

    def write_restore_bypass_mark(self, settings):
        self.file.write("# Restore the bypass mark from connmark" + "\n")
        self.file.write("${IPTABLES} -t mangle -A restore-bypass-mark -j CONNMARK --restore-mark --mask 0x%X -m comment --comment \"Restore the bypass mark from conntrack\"" % self.bypass_mark_mask + "\n")
        self.file.write("${IPTABLES} -t mangle -A restore-bypass-mark -i lo -j MARK --or-mark 0x%X -m comment --comment \"Always bypass loopback traffic\"" % self.bypass_mark_mask + "\n")
        self.file.write("\n")

        return

    def write_set_bypass_mark(self, settings):
        self.file.write("# Set the bypass mark on both packet and session" + "\n")
        self.file.write("${IPTABLES} -t filter -A set-bypass-mark -j MARK --or-mark 0x%X -m comment --comment \"Set the bypass mark on this packet\"" % self.bypass_mark_mask + "\n")
        self.file.write("${IPTABLES} -t filter -A set-bypass-mark -j CONNMARK --or-mark 0x%X -m comment --comment \"Set the bypass mark on this session\"" % self.bypass_mark_mask + "\n")
        self.file.write("\n")

        return

    def write_files(self, settings, prefix=""):
        self.filename = prefix + self.bypass_rules_filename
        self.file_dir = os.path.dirname(self.filename)
        if not os.path.exists(self.file_dir):
            os.makedirs(self.file_dir)

        self.file = open(self.filename, "w+")
        self.file.write("## Auto Generated\n")
        self.file.write("## DO NOT EDIT. Changes will be overwritten.\n")
        self.file.write("\n\n")

        self.file.write("# Create (if needed) and flush bypass-rules, set-bypass-mark, restore-bypass-mark chain" + "\n")
        self.file.write("${IPTABLES} -t mangle -N restore-bypass-mark 2>/dev/null" + "\n")
        self.file.write("${IPTABLES} -t mangle -F restore-bypass-mark >/dev/null 2>&1" + "\n")
        self.file.write("${IPTABLES} -t filter -N bypass-rules 2>/dev/null" + "\n")
        self.file.write("${IPTABLES} -t filter -F bypass-rules >/dev/null 2>&1" + "\n")
        self.file.write("${IPTABLES} -t filter -N set-bypass-mark 2>/dev/null" + "\n")
        self.file.write("${IPTABLES} -t filter -F set-bypass-mark >/dev/null 2>&1" + "\n")
        self.file.write("\n")

        self.file.write("# Call restore-interface-marks then mark-src-intf from prerouting-set-marks chain in mangle" + "\n")
        self.file.write("${IPTABLES} -t mangle -D prerouting-set-marks -m comment --comment \"Restore bypass mark (0x01000000) from connmark\" -j restore-bypass-mark >/dev/null 2>&1" + "\n")
        self.file.write("${IPTABLES} -t mangle -A prerouting-set-marks -m comment --comment \"Restore bypass mark (0x01000000) from connmark\" -j restore-bypass-mark" + "\n")
        self.file.write("\n")

        self.file.write("# Call bypass-rules chain from PREROUTING chain to forward traffic" + "\n")
        self.file.write("${IPTABLES} -t filter -D FORWARD -m conntrack --ctstate NEW -m comment --comment \"Bypass rules\" -j bypass-rules >/dev/null 2>&1" + "\n")
        self.file.write("${IPTABLES} -t filter -A FORWARD -m conntrack --ctstate NEW -m comment --comment \"Bypass rules\" -j bypass-rules" + "\n")
        self.file.write("\n")

        self.file.write("# Bypass all packets and sessions to the local server" + "\n")
        self.file.write("${IPTABLES} -A input-set-marks -t mangle ! -i utun -m conntrack --ctstate NEW -j MARK --or-mark 0x%X -m comment --comment \"Set bypass bit on all local inbound packets\"" % self.bypass_mark_mask + "\n")
        self.file.write("${IPTABLES} -A input-set-marks -t mangle ! -i utun -m conntrack --ctstate NEW -j CONNMARK --or-mark 0x%X -m comment --comment \"Set bypass bit on all local inbound sessions\"" % self.bypass_mark_mask + "\n")
        self.file.write("\n")

        self.file.write("# Bypass all packets and sessions from the local server" + "\n")
        self.file.write("${IPTABLES} -A output-set-marks -t mangle -j MARK --or-mark 0x%X -m comment --comment \"Set bypass bit on all local outbound packets\"" % self.bypass_mark_mask + "\n")
        self.file.write("${IPTABLES} -A output-set-marks -t mangle -m conntrack --ctstate NEW -j CONNMARK --or-mark 0x%X -m comment --comment \"Set bypass bit on all local outbound sessions\"" % self.bypass_mark_mask + "\n")
        self.file.write("\n")

        self.write_restore_bypass_mark(settings)
        self.write_set_bypass_mark(settings)
        self.write_bypass_rules(settings)

        self.file.flush()
        self.file.close()

        print("BypassRulesManager: Wrote %s" % self.filename)

        return


registrar.register_manager(BypassRuleManager())
