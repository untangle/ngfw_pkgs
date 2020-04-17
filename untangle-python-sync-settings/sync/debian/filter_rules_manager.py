import os
import sys
import subprocess
import datetime
import traceback
from sync.iptables_util import IptablesUtil
from sync.network_util import NetworkUtil
from sync import registrar,Manager

# This class is responsible for writing /etc/untangle/iptables-rules.d/240-filter-rules
# based on the settings object passed from sync-settings


class FilterRulesManager(Manager):
    interfaces_mark_mask = 0x0000FFFF

    iptables_filename = "/etc/untangle/iptables-rules.d/240-filter-rules"
    filename = iptables_filename
    file = None

    def initialize(self):
        registrar.register_settings_file("network", self)
        registrar.register_file(self.iptables_filename, "restart-iptables", self)

    def sync_settings(self, settings_file, prefix, delete_list):
        self.write_filter_rules_file(settings_file.settings, prefix)

    def write_filter_rule(self, table_name, filter_rule, drop_target):

        if filter_rule.get('enabled') == None or filter_rule.get('enabled') == False:
            return
        if filter_rule.get('ruleId') == None:
            return
        if filter_rule.get('blocked') == None:
            return

        if filter_rule.get('blocked'):
            target = ' -j %s ' % drop_target
        else:
            target = ' -j RETURN '

        description = "Rule #%i" % int(filter_rule['ruleId'])
        prep_commands = IptablesUtil.conditions_to_prep_commands(filter_rule['conditions'], description)
        iptables_conditions = IptablesUtil.conditions_to_iptables_string(filter_rule['conditions'], description)

        iptables_log_commands = [("${IPTABLES} -t filter -A %s " % table_name) + ipt + " -j NFLOG --nflog-prefix 'filter_blocked' " for ipt in iptables_conditions]
        iptables_commands = [("${IPTABLES} -t filter -A %s " % table_name) + ipt + target for ipt in iptables_conditions]

        self.file.write("# %s\n" % description)
        i = 0
        for cmd in prep_commands:
            self.file.write(cmd + "\n")

        for cmd in iptables_commands:
            # write a log rule before each block rule so we log every drop
            if filter_rule.get('blocked'):
                self.file.write(iptables_log_commands[i] + "\n")
            i = i+1
            self.file.write(cmd + "\n")

        if filter_rule.get('ipv6Enabled') == None or filter_rule.get('ipv6Enabled') == False:
            return

        ip6tables_commands = [("${IP6TABLES} -t filter -A %s " % table_name) + ipt + target for ipt in iptables_conditions]
        for cmd in ip6tables_commands:
            if cmd.find("--protocol ah"):
                cmd = cmd.replace("--protocol ah", "-m ah ! --ahspi 0")
            if cmd.find("--protocol icmp"):
                cmd = cmd.replace("--protocol icmp", "--protocol icmpv6")
            self.file.write(cmd + "\n")

        self.file.write("\n")

        return

    def write_access_rules(self, settings):

        if settings == None or settings.get('accessRules') == None:
            print("ERROR: Missing input filter Rules")
            return

        access_rules = settings['accessRules']

        for filter_rule in access_rules:
            try:
                self.write_filter_rule("access-rules", filter_rule, "DROP")
            except Exception as e:
                traceback.print_exc()
        return

    def write_filter_rules(self, settings):

        if settings == None or settings.get('filterRules') == None:
            print("ERROR: Missing forward filter Rules")
            return

        filter_rules = settings['filterRules']

        for filter_rule in filter_rules:
            try:
                self.write_filter_rule("filter-rules", filter_rule, "REJECT")
            except Exception as e:
                traceback.print_exc()
        return

    def write_filter_rules_file(self, settings, prefix=""):
        self.filename = prefix + self.iptables_filename
        self.file_dir = os.path.dirname(self.filename)
        if not os.path.exists(self.file_dir):
            os.makedirs(self.file_dir)

        self.file = open(self.filename, "w+")
        self.file.write("## Auto Generated\n")
        self.file.write("## DO NOT EDIT. Changes will be overwritten.\n")
        self.file.write("\n")
        self.file.write("\n")

        self.file.write("# Create (if needed) and flush access-rules chain" + "\n")
        self.file.write("${IPTABLES} -t filter -N access-rules 2>/dev/null" + "\n")
        self.file.write("${IPTABLES} -t filter -F access-rules >/dev/null 2>&1" + "\n")
        self.file.write("\n")

        self.file.write("${IP6TABLES} -t filter -N access-rules 2>/dev/null" + "\n")
        self.file.write("${IP6TABLES} -t filter -F access-rules >/dev/null 2>&1" + "\n")
        self.file.write("\n")

        self.file.write("# Create (if needed) and flush access-rules chain" + "\n")
        self.file.write("${IPTABLES} -t filter -N filter-rules 2>/dev/null" + "\n")
        self.file.write("${IPTABLES} -t filter -F filter-rules >/dev/null 2>&1" + "\n")
        self.file.write("\n")

        self.file.write("${IP6TABLES} -t filter -N filter-rules 2>/dev/null" + "\n")
        self.file.write("${IP6TABLES} -t filter -F filter-rules >/dev/null 2>&1" + "\n")
        self.file.write("\n")

        self.file.write("# Create (if needed) and flush access-rules chain" + "\n")
        self.file.write("${IPTABLES} -t filter -N block-invalid 2>/dev/null" + "\n")
        self.file.write("${IPTABLES} -t filter -F block-invalid >/dev/null 2>&1" + "\n")
        self.file.write("\n")

        self.file.write("${IP6TABLES} -t filter -N block-invalid 2>/dev/null" + "\n")
        self.file.write("${IP6TABLES} -t filter -F block-invalid >/dev/null 2>&1" + "\n")
        self.file.write("\n")

        self.file.write("# Call access-rules chain from INPUT/filter chain" + "\n")
        self.file.write("${IPTABLES} -t filter -D INPUT -m conntrack --ctstate NEW -m comment --comment \"input filter rules\" -j access-rules >/dev/null 2>&1" + "\n")
        self.file.write("${IPTABLES} -t filter -A INPUT -m conntrack --ctstate NEW -m comment --comment \"input filter rules\" -j access-rules" + "\n")
        self.file.write("\n")

        self.file.write("${IP6TABLES} -t filter -D INPUT -m conntrack --ctstate NEW -m comment --comment \"input filter rules\" -j access-rules >/dev/null 2>&1" + "\n")
        self.file.write("${IP6TABLES} -t filter -A INPUT -m conntrack --ctstate NEW -m comment --comment \"input filter rules\" -j access-rules" + "\n")
        self.file.write("\n")

        self.file.write("# Call filter-rules chain from FORWARD/filter chain" + "\n")
        self.file.write("${IPTABLES} -t filter -D FORWARD -m conntrack --ctstate NEW -m comment --comment \"forward filter rules\" -j filter-rules >/dev/null 2>&1" + "\n")
        self.file.write("${IPTABLES} -t filter -A FORWARD -m conntrack --ctstate NEW -m comment --comment \"forward filter rules\" -j filter-rules" + "\n")
        self.file.write("\n")

        self.file.write("${IP6TABLES} -t filter -D FORWARD -m conntrack --ctstate NEW -m comment --comment \"forward filter rules\" -j filter-rules >/dev/null 2>&1" + "\n")
        self.file.write("${IP6TABLES} -t filter -A FORWARD -m conntrack --ctstate NEW -m comment --comment \"forward filter rules\" -j filter-rules" + "\n")
        self.file.write("\n")

        self.file.write("# Pass all local traffic " + "\n")
        self.file.write("${IPTABLES} -t filter -D access-rules -i lo -j RETURN -m comment --comment \"Allow all local traffic\" >/dev/null 2>&1" + "\n")
        self.file.write("${IPTABLES} -t filter -I access-rules -i lo -j RETURN -m comment --comment \"Allow all local traffic\"" + "\n")
        self.file.write("\n")

        self.file.write("${IP6TABLES} -t filter -D access-rules -i lo -j RETURN -m comment --comment \"Allow all local traffic\" >/dev/null 2>&1" + "\n")
        self.file.write("${IP6TABLES} -t filter -I access-rules -i lo -j RETURN -m comment --comment \"Allow all local traffic\"" + "\n")
        self.file.write("\n")

        self.file.write("# Block INVALID packets" + "\n")
        self.file.write("${IPTABLES} -t filter -D block-invalid -m conntrack --ctstate INVALID -j DROP -m comment --comment \"Block INVALID packets\" >/dev/null 2>&1" + "\n")
        self.file.write("${IPTABLES} -t filter -I block-invalid -m conntrack --ctstate INVALID -j DROP -m comment --comment \"Block INVALID packets\" " + "\n")
        self.file.write("${IPTABLES} -t filter -D block-invalid -m conntrack --ctstate INVALID -j NFLOG --nflog-prefix \"invalid_blocked\" -m comment --comment \"nflog on invalid\" >/dev/null 2>&1\n")
        self.file.write("${IPTABLES} -t filter -I block-invalid -m conntrack --ctstate INVALID -j NFLOG --nflog-prefix \"invalid_blocked\" -m comment --comment \"nflog on invalid\"\n")
        for intfId in NetworkUtil.interface_list():
            self.file.write("${IPTABLES} -t filter -I block-invalid -m mark --mark 0x%X/0x%X -j RETURN -m comment --comment \"Allow INVALID hairpin traffic (interface %s)\"" % ((intfId+(intfId << 8)), self.interfaces_mark_mask, str(intfId)) + "\n")
        self.file.write("${IPTABLES} -t filter -I block-invalid -m mark --mark 0xfe00/0xff00 -j RETURN -m comment --comment \"Allow INVALID to local sockets (interface 0xfe)\"" + "\n")
        self.file.write("\n")
        self.file.write("# Block INVALID packets" + "\n")
        self.file.write("${IP6TABLES} -t filter -D block-invalid -m conntrack --ctstate INVALID -j DROP -m comment --comment \"Block INVALID packets\" >/dev/null 2>&1" + "\n")
        self.file.write("${IP6TABLES} -t filter -I block-invalid -m conntrack --ctstate INVALID -j DROP -m comment --comment \"Block INVALID packets\" " + "\n")
        # disabled because I don't think the nflog daemon handles IPv6 currently
        #self.file.write("${IP6TABLES} -t filter -D block-invalid -m conntrack --ctstate INVALID -j NFLOG --nflog-prefix \"invalid_blocked\" -m comment --comment \"nflog on invalid\" >/dev/null 2>&1\n");
        #self.file.write("${IP6TABLES} -t filter -I block-invalid -m conntrack --ctstate INVALID -j NFLOG --nflog-prefix \"invalid_blocked\" -m comment --comment \"nflog on invalid\"\n");
        for intfId in NetworkUtil.interface_list():
            self.file.write("${IP6TABLES} -t filter -I block-invalid -m mark --mark 0x%X/0x%X -j RETURN -m comment --comment \"Allow INVALID hairpin traffic (interface %s)\"" % ((intfId+(intfId << 8)), self.interfaces_mark_mask, str(intfId)) + "\n")
        self.file.write("${IP6TABLES} -t filter -I block-invalid -m mark --mark 0xfe00/0xff00 -j RETURN -m comment --comment \"Allow INVALID to local sockets (interface 0xfe)\"" + "\n")
        self.file.write("\n")

        if settings.get('blockInvalidPackets'):
            self.file.write("# Block INVALID packets" + "\n")
            self.file.write("${IPTABLES} -t filter -D INPUT -m conntrack --ctstate INVALID -j block-invalid -m comment --comment \"Block INVALID\" >/dev/null 2>&1" + "\n")
            self.file.write("${IPTABLES} -t filter -A INPUT -m conntrack --ctstate INVALID -j block-invalid -m comment --comment \"Block INVALID\"" + "\n")
            self.file.write("\n")

            self.file.write("# Block INVALID packets" + "\n")
            self.file.write("${IPTABLES} -t filter -D FORWARD -m conntrack --ctstate INVALID -j block-invalid -m comment --comment \"Block INVALID\" >/dev/null 2>&1" + "\n")
            self.file.write("${IPTABLES} -t filter -A FORWARD -m conntrack --ctstate INVALID -j block-invalid -m comment --comment \"Block INVALID\"" + "\n")
            self.file.write("\n")

        self.file.write("# Pass all RELATED traffic " + "\n")
        self.file.write("${IPTABLES} -t filter -D access-rules -m conntrack --ctstate RELATED -j RETURN -m comment --comment \"Allow RELATED traffic\" >/dev/null 2>&1" + "\n")
        self.file.write("${IPTABLES} -t filter -I access-rules -m conntrack --ctstate RELATED -j RETURN -m comment --comment \"Allow RELATED traffic\"" + "\n")
        self.file.write("\n")

        self.file.write("${IP6TABLES} -t filter -D access-rules -m conntrack --ctstate RELATED -j RETURN -m comment --comment \"Allow RELATED traffic\" >/dev/null 2>&1" + "\n")
        self.file.write("${IP6TABLES} -t filter -I access-rules -m conntrack --ctstate RELATED -j RETURN -m comment --comment \"Allow RELATED traffic\"" + "\n")
        self.file.write("\n")

        self.file.write("# Pass all RELATED traffic " + "\n")
        self.file.write("${IPTABLES} -t filter -D filter-rules -m conntrack --ctstate RELATED -j RETURN -m comment --comment \"Allow RELATED traffic\" >/dev/null 2>&1" + "\n")
        self.file.write("${IPTABLES} -t filter -I filter-rules -m conntrack --ctstate RELATED -j RETURN -m comment --comment \"Allow RELATED traffic\"" + "\n")
        self.file.write("\n")

        self.file.write("${IP6TABLES} -t filter -D filter-rules -m conntrack --ctstate RELATED -j RETURN -m comment --comment \"Allow RELATED traffic\" >/dev/null 2>&1" + "\n")
        self.file.write("${IP6TABLES} -t filter -I filter-rules -m conntrack --ctstate RELATED -j RETURN -m comment --comment \"Allow RELATED traffic\"" + "\n")
        self.file.write("\n")

        # This is commented out because we have explicit rules to handle admin & blockpages in the input rules.
        # self.file.write("# Pass all port forwarded traffic (for block pages & admin) " + "\n");
        # self.file.write("${IPTABLES} -t filter -D access-rules -m conntrack --ctstate DNAT -j RETURN -m comment --comment \"Allow port forwarded traffic\" >/dev/null 2>&1" + "\n");
        # self.file.write("${IPTABLES} -t filter -I access-rules -m conntrack --ctstate DNAT -j RETURN -m comment --comment \"Allow port forwarded traffic\"" + "\n");
        # self.file.write("\n");

        self.file.write("# Pass all reinjected TCP traffic " + "\n")
        self.file.write("${IPTABLES} -t filter -D access-rules -i utun -j RETURN -m comment --comment \"Allow all reinjected traffic\" >/dev/null 2>&1" + "\n")
        self.file.write("${IPTABLES} -t filter -I access-rules -i utun -j RETURN -m comment --comment \"Allow all reinjected traffic\"" + "\n")
        self.file.write("\n")

        self.file.write("${IP6TABLES} -t filter -D access-rules -i utun -j RETURN -m comment --comment \"Allow all reinjected traffic\" >/dev/null 2>&1" + "\n")
        self.file.write("${IP6TABLES} -t filter -I access-rules -i utun -j RETURN -m comment --comment \"Allow all reinjected traffic\"" + "\n")
        self.file.write("\n")

        if settings.get('blockReplayPackets'):
            self.file.write("# Block Replay packets" + "\n")
            # more info in bug #12357 #12358 #12359
            self.file.write("${IPTABLES} -t filter -D FORWARD -p tcp --tcp-flags RST RST -j CONNMARK --set-mark 0x02000000/0x02000000 -m comment --comment \"set replay bit\" >/dev/null 2>&1" + "\n")
            self.file.write("${IPTABLES} -t filter -I FORWARD -p tcp --tcp-flags RST RST -j CONNMARK --set-mark 0x02000000/0x02000000 -m comment --comment \"set replay bit\" " + "\n")
            self.file.write("${IPTABLES} -t filter -D FORWARD -p tcp --tcp-flags RST RST -m connmark --mark 0x02000000/0x02000000 -m state --state RELATED -j DROP -m comment --comment \"drop if replay\" >/dev/null 2>&1" + "\n")
            self.file.write("${IPTABLES} -t filter -I FORWARD -p tcp --tcp-flags RST RST -m connmark --mark 0x02000000/0x02000000 -m state --state RELATED -j DROP -m comment --comment \"drop if replay\" " + "\n")
            self.file.write("${IPTABLES} -t filter -D FORWARD -p icmp ! --icmp-type 8 -m state --state RELATED -j CONNMARK --set-mark 0x02000000/0x02000000 -m comment --comment \"set replay bit\" >/dev/null 2>&1" + "\n")
            self.file.write("${IPTABLES} -t filter -I FORWARD -p icmp ! --icmp-type 8 -m state --state RELATED -j CONNMARK --set-mark 0x02000000/0x02000000 -m comment --comment \"set replay bit\" " + "\n")
            self.file.write("${IPTABLES} -t filter -D FORWARD -p icmp ! --icmp-type 8 -m connmark --mark 0x02000000/0x02000000 -m state --state RELATED -j DROP -m comment --comment \"drop if replay\" >/dev/null 2>&1" + "\n")
            self.file.write("${IPTABLES} -t filter -I FORWARD -p icmp ! --icmp-type 8 -m connmark --mark 0x02000000/0x02000000 -m state --state RELATED -j DROP -m comment --comment \"drop if replay\" " + "\n")
            self.file.write("\n")
            # no need for ipv6 - this is only for ICSA compliance

        self.write_access_rules(settings)
        self.write_filter_rules(settings)

        self.file.write("\n")
        self.file.write("${IPTABLES} -t filter -D FORWARD -m conntrack --ctstate NEW -j DROP -m comment --comment \"drop sessions during restart\" >/dev/null 2>&1\n")
        self.file.write("${IPTABLES} -t filter -D INPUT   -m conntrack --ctstate NEW -j DROP -m comment --comment \"drop sessions during restart\" >/dev/null 2>&1\n")
        self.file.write("\n")

        # self.file.write("# Flush IPv6 Rules" + "\n");
        #self.file.write("${IP6TABLES} -t filter -F FORWARD -m comment --comment \"Flush IPv6 rules\" >/dev/null 2>&1" + "\n");
        # if settings.get('blockIpv6Forwarding'):
        #    self.file.write("# Block IPv6 Fowarding" + "\n");
        #    self.file.write("${IP6TABLES} -t filter -A FORWARD -j DROP -m comment --comment \"Do not allow IPv6 forwarding\" >/dev/null 2>&1" + "\n");
        #    self.file.write("\n");

        # self.file.write("# Block IPv6 Input" + "\n");
        #self.file.write("${IP6TABLES} -t filter -F INPUT -m comment --comment \"Flush IPv6 filter rules\" >/dev/null 2>&1" + "\n");
        #self.file.write("${IP6TABLES} -t filter -A INPUT -p icmpv6 -j RETURN -m comment --comment \"Allow IPv6 icmp RA, solicitions, ping etc\" >/dev/null 2>&1" + "\n");
        #self.file.write("${IP6TABLES} -t filter -A INPUT -j DROP -m comment --comment \"Do not allow IPv6 input\" >/dev/null 2>&1" + "\n");
        # self.file.write("\n");

        self.file.flush()
        self.file.close()

        print("FilterRulesManager: Wrote %s" % self.filename)

        return


registrar.register_manager(FilterRulesManager())
