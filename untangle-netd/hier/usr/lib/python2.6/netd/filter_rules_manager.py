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

    def write_filter_rule( self, table_name, filter_rule, verbosity=0 ):

        if filter_rule.get('enabled') == None or filter_rule.get('enabled') == False:
            return
        if filter_rule.get('matchers') == None or filter_rule.get('matchers').get('list') == None:
            return
        if filter_rule.get('ruleId') == None:
            return
        if filter_rule.get('blocked') == None:
            return

        if filter_rule.get('blocked'):
            target = ' -j DROP '
        else:
            target = ' -j ACCEPT '

        description = "FILTER Rule #%i" % int(filter_rule['ruleId'])
        iptables_conditions = IptablesUtil.conditions_to_iptables_string( filter_rule['matchers']['list'], description, verbosity );

        iptables_commands = [ ("${IPTABLES} -t filter -A %s " % table_name) + ipt + target for ipt in iptables_conditions ]

        self.file.write("# %s\n" % description);
        for cmd in iptables_commands:
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
                self.write_filter_rule( "filter-rules-input", filter_rule, verbosity );
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
                self.write_filter_rule( "filter-rules-forward", filter_rule, verbosity );
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
        self.file.write("## Auto Generated on %s\n" % datetime.datetime.now());
        self.file.write("## DO NOT EDIT. Changes will be overwritten.\n");
        self.file.write("\n");
        self.file.write("\n");

        self.file.write("# Create (if needed) and flush filter-rules-input chain" + "\n");
        self.file.write("${IPTABLES} -t filter -N filter-rules-input 2>/dev/null" + "\n");
        self.file.write("${IPTABLES} -t filter -F filter-rules-input >/dev/null 2>&1" + "\n");
        self.file.write("\n");

        self.file.write("# Create (if needed) and flush filter-rules-input chain" + "\n");
        self.file.write("${IPTABLES} -t filter -N filter-rules-forward 2>/dev/null" + "\n");
        self.file.write("${IPTABLES} -t filter -F filter-rules-forward >/dev/null 2>&1" + "\n");
        self.file.write("\n");

        self.file.write("# Call filter-rules-input chain from INPUT/filter chain" + "\n");
        self.file.write("${IPTABLES} -t filter -D INPUT -m conntrack --ctstate NEW -m comment --comment \"input filter rules\" -j filter-rules-input >/dev/null 2>&1" + "\n");
        self.file.write("${IPTABLES} -t filter -A INPUT -m conntrack --ctstate NEW -m comment --comment \"input filter rules\" -j filter-rules-input" + "\n");
        self.file.write("\n");

        self.file.write("# Call filter-rules-forward chain from FORWARD/filter chain" + "\n");
        self.file.write("${IPTABLES} -t filter -D FORWARD -m conntrack --ctstate NEW -m comment --comment \"forward filter rules\" -j filter-rules-forward >/dev/null 2>&1" + "\n");
        self.file.write("${IPTABLES} -t filter -A FORWARD -m conntrack --ctstate NEW -m comment --comment \"forward filter rules\" -j filter-rules-forward" + "\n");
        self.file.write("\n");

        self.file.write("# Pass all local traffic " + "\n");
        self.file.write("${IPTABLES} -t filter -D filter-rules-input -i lo -j ACCEPT -m comment --comment \"Allow all local traffic\" >/dev/null 2>&1" + "\n");
        self.file.write("${IPTABLES} -t filter -I filter-rules-input -i lo -j ACCEPT -m comment --comment \"Allow all local traffic\"" + "\n");
        self.file.write("\n");

        self.file.write("# Pass all RELATED traffic " + "\n");
        self.file.write("${IPTABLES} -t filter -D filter-rules-input -m conntrack --ctstate RELATED -j ACCEPT -m comment --comment \"Allow RELATED traffic\" >/dev/null 2>&1" + "\n");
        self.file.write("${IPTABLES} -t filter -I filter-rules-input -m conntrack --ctstate RELATED -j ACCEPT -m comment --comment \"Allow RELATED traffic\"" + "\n");
        self.file.write("\n");

        self.file.write("# Pass all port forwarded traffic (for block pages & admin) " + "\n");
        self.file.write("${IPTABLES} -t filter -D filter-rules-input -m conntrack --ctstate DNAT -j ACCEPT -m comment --comment \"Allow port forwarded traffic\" >/dev/null 2>&1" + "\n");
        self.file.write("${IPTABLES} -t filter -I filter-rules-input -m conntrack --ctstate DNAT -j ACCEPT -m comment --comment \"Allow port forwarded traffic\"" + "\n");
        self.file.write("\n");

        self.file.write("# Pass all redirected TCP traffic " + "\n");
        self.file.write("${IPTABLES} -t filter -D filter-rules-input -i utun -j ACCEPT -m comment --comment \"Allow all redirected traffic\" >/dev/null 2>&1" + "\n");
        self.file.write("${IPTABLES} -t filter -I filter-rules-input -i utun -j ACCEPT -m comment --comment \"Allow all redirected traffic\"" + "\n");
        self.file.write("\n");

        self.write_input_filter_rules( settings, verbosity );
        self.write_forward_filter_rules( settings, verbosity );

        self.file.flush();
        self.file.close();

        if verbosity > 0:
            print "FilterRulesManager: Wrote %s" % self.filename

        return

