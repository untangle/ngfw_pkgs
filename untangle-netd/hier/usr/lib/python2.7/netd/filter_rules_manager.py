import os
import sys
import subprocess
import datetime
import traceback
from netd.iptables_util import IptablesUtil
from netd.network_util import NetworkUtil

# This class is responsible for writing /etc/untangle-netd/iptables-rules.d/240-filter-rules
# based on the settings object passed from sync-settings.py
class FilterRulesManager:
    interfacesMarkMask = 0x0000FFFF

    defaultFilename = "/etc/untangle-netd/iptables-rules.d/240-filter-rules"
    filename = defaultFilename
    file = None

    def write_filter_rule( self, table_name, filter_rule, drop_target, verbosity=0 ):

        if filter_rule.get('enabled') == None or filter_rule.get('enabled') == False:
            return
        if filter_rule.get('conditions') == None or filter_rule.get('conditions').get('list') == None:
            return
        if filter_rule.get('ruleId') == None:
            return
        if filter_rule.get('blocked') == None:
            return

        if filter_rule.get('blocked'):
            target = ' -j %s ' % drop_target
        else:
            target = ' -j RETURN '

        description = "Filter Rule #%i" % int(filter_rule['ruleId'])
        iptables_conditions = IptablesUtil.conditions_to_iptables_string( filter_rule['conditions']['list'], description, verbosity );

        iptables_log_commands = [ ("${IPTABLES} -t filter -A %s " % table_name) + ipt + " -j NFLOG --nflog-prefix 'filter_blocked' " for ipt in iptables_conditions ]
        iptables_commands = [ ("${IPTABLES} -t filter -A %s " % table_name) + ipt + target for ipt in iptables_conditions ]

        self.file.write("# %s\n" % description);
        i = 0
        for cmd in iptables_commands:
            # write a log rule before each block rule so we log every drop
            if filter_rule.get('blocked'):
                self.file.write(iptables_log_commands[i] + "\n")
            i=i+1

            self.file.write(cmd + "\n")

        if filter_rule.get('ipv6Enabled') == None or filter_rule.get('ipv6Enabled') == False:
            return

        ip6tables_commands = [ ("${IP6TABLES} -t filter -A %s " % table_name) + ipt + target for ipt in iptables_conditions ]
        for cmd in ip6tables_commands:
            if cmd.find("--protocol ah") : 
                cmd = cmd.replace("--protocol ah", "-m ah ! --ahspi 0");
            if cmd.find("--protocol icmp") : 
                cmd = cmd.replace("--protocol icmp", "--protocol icmpv6");
            self.file.write(cmd + "\n")

        self.file.write("\n");

        return

    def write_input_filter_rules( self, settings, verbosity=0 ):

        if settings == None or settings.get('inputFilterRules') == None or settings.get('inputFilterRules').get('list') == None:
            print "ERROR: Missing input filter Rules"
            return

        input_filter_rules = settings['inputFilterRules']['list'];

        for filter_rule in input_filter_rules:
            try:
                self.write_filter_rule( "filter-rules-input", filter_rule, "DROP", verbosity );
            except Exception,e:
                traceback.print_exc(e)
        return

    def write_forward_filter_rules( self, settings, verbosity=0 ):

        if settings == None or settings.get('forwardFilterRules') == None or settings.get('forwardFilterRules').get('list') == None:
            print "ERROR: Missing forward filter Rules"
            return
        
        forward_filter_rules = settings['forwardFilterRules']['list'];

        for filter_rule in forward_filter_rules:
            try:
                self.write_filter_rule( "filter-rules-forward", filter_rule, "REJECT", verbosity );
            except Exception,e:
                traceback.print_exc(e)
        return

    def sync_settings( self, settings, prefix="", verbosity=0 ):
        if verbosity > 1: print "FilterRulesManager: sync_settings()"

        self.filename = prefix + self.defaultFilename
        self.fileDir = os.path.dirname( self.filename )
        if not os.path.exists( self.fileDir ):
            os.makedirs( self.fileDir )

        self.file = open( self.filename, "w+" )
        self.file.write("## Auto Generated\n");
        self.file.write("## DO NOT EDIT. Changes will be overwritten.\n");
        self.file.write("\n");
        self.file.write("\n");

        self.file.write("# Create (if needed) and flush filter-rules-input chain" + "\n");
        self.file.write("${IPTABLES} -t filter -N filter-rules-input 2>/dev/null" + "\n");
        self.file.write("${IPTABLES} -t filter -F filter-rules-input >/dev/null 2>&1" + "\n");
        self.file.write("\n");

        self.file.write("${IP6TABLES} -t filter -N filter-rules-input 2>/dev/null" + "\n");
        self.file.write("${IP6TABLES} -t filter -F filter-rules-input >/dev/null 2>&1" + "\n");
        self.file.write("\n");

        self.file.write("# Create (if needed) and flush filter-rules-input chain" + "\n");
        self.file.write("${IPTABLES} -t filter -N filter-rules-forward 2>/dev/null" + "\n");
        self.file.write("${IPTABLES} -t filter -F filter-rules-forward >/dev/null 2>&1" + "\n");
        self.file.write("\n");

        self.file.write("${IP6TABLES} -t filter -N filter-rules-forward 2>/dev/null" + "\n");
        self.file.write("${IP6TABLES} -t filter -F filter-rules-forward >/dev/null 2>&1" + "\n");
        self.file.write("\n");

        self.file.write("# Create (if needed) and flush filter-rules-input chain" + "\n");
        self.file.write("${IPTABLES} -t filter -N block-invalid 2>/dev/null" + "\n");
        self.file.write("${IPTABLES} -t filter -F block-invalid >/dev/null 2>&1" + "\n");
        self.file.write("\n");

        self.file.write("${IP6TABLES} -t filter -N block-invalid 2>/dev/null" + "\n");
        self.file.write("${IP6TABLES} -t filter -F block-invalid >/dev/null 2>&1" + "\n");
        self.file.write("\n");

        self.file.write("# Call filter-rules-input chain from INPUT/filter chain" + "\n");
        self.file.write("${IPTABLES} -t filter -D INPUT -m conntrack --ctstate NEW -m comment --comment \"input filter rules\" -j filter-rules-input >/dev/null 2>&1" + "\n");
        self.file.write("${IPTABLES} -t filter -A INPUT -m conntrack --ctstate NEW -m comment --comment \"input filter rules\" -j filter-rules-input" + "\n");
        self.file.write("\n");

        self.file.write("${IP6TABLES} -t filter -D INPUT -m conntrack --ctstate NEW -m comment --comment \"input filter rules\" -j filter-rules-input >/dev/null 2>&1" + "\n");
        self.file.write("${IP6TABLES} -t filter -A INPUT -m conntrack --ctstate NEW -m comment --comment \"input filter rules\" -j filter-rules-input" + "\n");
        self.file.write("\n");

        self.file.write("# Call filter-rules-forward chain from FORWARD/filter chain" + "\n");
        self.file.write("${IPTABLES} -t filter -D FORWARD -m conntrack --ctstate NEW -m comment --comment \"forward filter rules\" -j filter-rules-forward >/dev/null 2>&1" + "\n");
        self.file.write("${IPTABLES} -t filter -A FORWARD -m conntrack --ctstate NEW -m comment --comment \"forward filter rules\" -j filter-rules-forward" + "\n");
        self.file.write("\n");

        self.file.write("${IP6TABLES} -t filter -D FORWARD -m conntrack --ctstate NEW -m comment --comment \"forward filter rules\" -j filter-rules-forward >/dev/null 2>&1" + "\n");
        self.file.write("${IP6TABLES} -t filter -A FORWARD -m conntrack --ctstate NEW -m comment --comment \"forward filter rules\" -j filter-rules-forward" + "\n");
        self.file.write("\n");

        self.file.write("# Pass all local traffic " + "\n");
        self.file.write("${IPTABLES} -t filter -D filter-rules-input -i lo -j RETURN -m comment --comment \"Allow all local traffic\" >/dev/null 2>&1" + "\n");
        self.file.write("${IPTABLES} -t filter -I filter-rules-input -i lo -j RETURN -m comment --comment \"Allow all local traffic\"" + "\n");
        self.file.write("\n");

        self.file.write("${IP6TABLES} -t filter -D filter-rules-input -i lo -j RETURN -m comment --comment \"Allow all local traffic\" >/dev/null 2>&1" + "\n");
        self.file.write("${IP6TABLES} -t filter -I filter-rules-input -i lo -j RETURN -m comment --comment \"Allow all local traffic\"" + "\n");
        self.file.write("\n");

        self.file.write("# Block INVALID packets" + "\n");
        self.file.write("${IPTABLES} -t filter -D block-invalid -m conntrack --ctstate INVALID -j DROP -m comment --comment \"Block INVALID packets\" >/dev/null 2>&1" + "\n");
        self.file.write("${IPTABLES} -t filter -I block-invalid -m conntrack --ctstate INVALID -j DROP -m comment --comment \"Block INVALID packets\" " + "\n");
        self.file.write("${IPTABLES} -t filter -D block-invalid -m conntrack --ctstate INVALID -j NFLOG --nflog-prefix \"invalid_blocked\" -m comment --comment \"nflog on invalid\" >/dev/null 2>&1\n");
        self.file.write("${IPTABLES} -t filter -I block-invalid -m conntrack --ctstate INVALID -j NFLOG --nflog-prefix \"invalid_blocked\" -m comment --comment \"nflog on invalid\"\n");
        for intfId in NetworkUtil.interface_list():
            self.file.write("${IPTABLES} -t filter -I block-invalid -m mark --mark 0x%X/0x%X -j RETURN -m comment --comment \"Allow INVALID hairpin traffic (interface %s)\"" % ( (intfId+(intfId<<8)), self.interfacesMarkMask, str(intfId)) + "\n");
        self.file.write("${IPTABLES} -t filter -I block-invalid -m mark --mark 0xfe00/0xff00 -j RETURN -m comment --comment \"Allow INVALID to local sockets (interface 0xfe)\"" + "\n");
        self.file.write("\n");
        self.file.write("# Block INVALID packets" + "\n");
        self.file.write("${IP6TABLES} -t filter -D block-invalid -m conntrack --ctstate INVALID -j DROP -m comment --comment \"Block INVALID packets\" >/dev/null 2>&1" + "\n");
        self.file.write("${IP6TABLES} -t filter -I block-invalid -m conntrack --ctstate INVALID -j DROP -m comment --comment \"Block INVALID packets\" " + "\n");
        # disabled because I don't think the nflog daemon handles IPv6 currently
        #self.file.write("${IP6TABLES} -t filter -D block-invalid -m conntrack --ctstate INVALID -j NFLOG --nflog-prefix \"invalid_blocked\" -m comment --comment \"nflog on invalid\" >/dev/null 2>&1\n");
        #self.file.write("${IP6TABLES} -t filter -I block-invalid -m conntrack --ctstate INVALID -j NFLOG --nflog-prefix \"invalid_blocked\" -m comment --comment \"nflog on invalid\"\n");
        for intfId in NetworkUtil.interface_list():
            self.file.write("${IP6TABLES} -t filter -I block-invalid -m mark --mark 0x%X/0x%X -j RETURN -m comment --comment \"Allow INVALID hairpin traffic (interface %s)\"" % ( (intfId+(intfId<<8)), self.interfacesMarkMask, str(intfId)) + "\n");
        self.file.write("${IP6TABLES} -t filter -I block-invalid -m mark --mark 0xfe00/0xff00 -j RETURN -m comment --comment \"Allow INVALID to local sockets (interface 0xfe)\"" + "\n");
        self.file.write("\n");

        if settings.get('blockInvalidPackets'):
            self.file.write("# Block INVALID packets" + "\n");
            self.file.write("${IPTABLES} -t filter -D INPUT -m conntrack --ctstate INVALID -j block-invalid -m comment --comment \"Block INVALID\" >/dev/null 2>&1" + "\n");
            self.file.write("${IPTABLES} -t filter -A INPUT -m conntrack --ctstate INVALID -j block-invalid -m comment --comment \"Block INVALID\"" + "\n");
            self.file.write("\n");

            self.file.write("# Block INVALID packets" + "\n");
            self.file.write("${IPTABLES} -t filter -D FORWARD -m conntrack --ctstate INVALID -j block-invalid -m comment --comment \"Block INVALID\" >/dev/null 2>&1" + "\n");
            self.file.write("${IPTABLES} -t filter -A FORWARD -m conntrack --ctstate INVALID -j block-invalid -m comment --comment \"Block INVALID\"" + "\n");
            self.file.write("\n");

        self.file.write("# Pass all RELATED traffic " + "\n");
        self.file.write("${IPTABLES} -t filter -D filter-rules-input -m conntrack --ctstate RELATED -j RETURN -m comment --comment \"Allow RELATED traffic\" >/dev/null 2>&1" + "\n");
        self.file.write("${IPTABLES} -t filter -I filter-rules-input -m conntrack --ctstate RELATED -j RETURN -m comment --comment \"Allow RELATED traffic\"" + "\n");
        self.file.write("\n");

        self.file.write("${IP6TABLES} -t filter -D filter-rules-input -m conntrack --ctstate RELATED -j RETURN -m comment --comment \"Allow RELATED traffic\" >/dev/null 2>&1" + "\n");
        self.file.write("${IP6TABLES} -t filter -I filter-rules-input -m conntrack --ctstate RELATED -j RETURN -m comment --comment \"Allow RELATED traffic\"" + "\n");
        self.file.write("\n");

        self.file.write("# Pass all RELATED traffic " + "\n");
        self.file.write("${IPTABLES} -t filter -D filter-rules-forward -m conntrack --ctstate RELATED -j RETURN -m comment --comment \"Allow RELATED traffic\" >/dev/null 2>&1" + "\n");
        self.file.write("${IPTABLES} -t filter -I filter-rules-forward -m conntrack --ctstate RELATED -j RETURN -m comment --comment \"Allow RELATED traffic\"" + "\n");
        self.file.write("\n");

        self.file.write("${IP6TABLES} -t filter -D filter-rules-forward -m conntrack --ctstate RELATED -j RETURN -m comment --comment \"Allow RELATED traffic\" >/dev/null 2>&1" + "\n");
        self.file.write("${IP6TABLES} -t filter -I filter-rules-forward -m conntrack --ctstate RELATED -j RETURN -m comment --comment \"Allow RELATED traffic\"" + "\n");
        self.file.write("\n");

        # This is commented out because we have explicit rules to handle admin & blockpages in the input rules.
        # self.file.write("# Pass all port forwarded traffic (for block pages & admin) " + "\n");
        # self.file.write("${IPTABLES} -t filter -D filter-rules-input -m conntrack --ctstate DNAT -j RETURN -m comment --comment \"Allow port forwarded traffic\" >/dev/null 2>&1" + "\n");
        # self.file.write("${IPTABLES} -t filter -I filter-rules-input -m conntrack --ctstate DNAT -j RETURN -m comment --comment \"Allow port forwarded traffic\"" + "\n");
        # self.file.write("\n");

        self.file.write("# Pass all reinjected TCP traffic " + "\n");
        self.file.write("${IPTABLES} -t filter -D filter-rules-input -i utun -j RETURN -m comment --comment \"Allow all reinjected traffic\" >/dev/null 2>&1" + "\n");
        self.file.write("${IPTABLES} -t filter -I filter-rules-input -i utun -j RETURN -m comment --comment \"Allow all reinjected traffic\"" + "\n");
        self.file.write("\n");

        self.file.write("${IP6TABLES} -t filter -D filter-rules-input -i utun -j RETURN -m comment --comment \"Allow all reinjected traffic\" >/dev/null 2>&1" + "\n");
        self.file.write("${IP6TABLES} -t filter -I filter-rules-input -i utun -j RETURN -m comment --comment \"Allow all reinjected traffic\"" + "\n");
        self.file.write("\n");

        if settings.get('blockReplayPackets'):
            self.file.write("# Block Replay packets" + "\n");
            # more info in bug #12357 #12358 #12359
            self.file.write("${IPTABLES} -t filter -D FORWARD -p tcp --tcp-flags RST RST -j CONNMARK --set-mark 0x02000000/0x02000000 -m comment --comment \"set replay bit\" >/dev/null 2>&1" + "\n")
            self.file.write("${IPTABLES} -t filter -I FORWARD -p tcp --tcp-flags RST RST -j CONNMARK --set-mark 0x02000000/0x02000000 -m comment --comment \"set replay bit\" " + "\n")
            self.file.write("${IPTABLES} -t filter -D FORWARD -p tcp --tcp-flags RST RST -m connmark --mark 0x02000000/0x02000000 -m state --state RELATED -j DROP -m comment --comment \"drop if replay\" >/dev/null 2>&1" + "\n")
            self.file.write("${IPTABLES} -t filter -I FORWARD -p tcp --tcp-flags RST RST -m connmark --mark 0x02000000/0x02000000 -m state --state RELATED -j DROP -m comment --comment \"drop if replay\" " + "\n")
            self.file.write("${IPTABLES} -t filter -D FORWARD -p icmp ! --icmp-type 8 -m state --state RELATED -j CONNMARK --set-mark 0x02000000/0x02000000 -m comment --comment \"set replay bit\" >/dev/null 2>&1" + "\n")
            self.file.write("${IPTABLES} -t filter -I FORWARD -p icmp ! --icmp-type 8 -m state --state RELATED -j CONNMARK --set-mark 0x02000000/0x02000000 -m comment --comment \"set replay bit\" " + "\n")
            self.file.write("${IPTABLES} -t filter -D FORWARD -p icmp ! --icmp-type 8 -m connmark --mark 0x02000000/0x02000000 -m state --state RELATED -j DROP -m comment --comment \"drop if replay\" >/dev/null 2>&1" + "\n")
            self.file.write("${IPTABLES} -t filter -I FORWARD -p icmp ! --icmp-type 8 -m connmark --mark 0x02000000/0x02000000 -m state --state RELATED -j DROP -m comment --comment \"drop if replay\" " + "\n")
            self.file.write("\n");
            # no need for ipv6 - this is only for ICSA compliance

        self.write_input_filter_rules( settings, verbosity );
        self.write_forward_filter_rules( settings, verbosity );

        self.file.write("\n");
        self.file.write("${IPTABLES} -t filter -D FORWARD -m conntrack --ctstate NEW -j DROP -m comment --comment \"drop sessions during restart\" >/dev/null 2>&1\n");
        self.file.write("${IPTABLES} -t filter -D INPUT   -m conntrack --ctstate NEW -j DROP -m comment --comment \"drop sessions during restart\" >/dev/null 2>&1\n");
        self.file.write("\n");

        #self.file.write("# Flush IPv6 Rules" + "\n");
        #self.file.write("${IP6TABLES} -t filter -F FORWARD -m comment --comment \"Flush IPv6 rules\" >/dev/null 2>&1" + "\n");
        #if settings.get('blockIpv6Forwarding'):
        #    self.file.write("# Block IPv6 Fowarding" + "\n");
        #    self.file.write("${IP6TABLES} -t filter -A FORWARD -j DROP -m comment --comment \"Do not allow IPv6 forwarding\" >/dev/null 2>&1" + "\n");
        #    self.file.write("\n");

        #self.file.write("# Block IPv6 Input" + "\n");
        #self.file.write("${IP6TABLES} -t filter -F INPUT -m comment --comment \"Flush IPv6 filter rules\" >/dev/null 2>&1" + "\n");
        #self.file.write("${IP6TABLES} -t filter -A INPUT -p icmpv6 -j RETURN -m comment --comment \"Allow IPv6 icmp RA, solicitions, ping etc\" >/dev/null 2>&1" + "\n");
        #self.file.write("${IP6TABLES} -t filter -A INPUT -j DROP -m comment --comment \"Do not allow IPv6 input\" >/dev/null 2>&1" + "\n");
        #self.file.write("\n");
            
        self.file.flush();
        self.file.close();

        if verbosity > 0:
            print "FilterRulesManager: Wrote %s" % self.filename

        return

