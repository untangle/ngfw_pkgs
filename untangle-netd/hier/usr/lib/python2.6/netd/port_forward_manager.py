import os
import sys
import subprocess
import datetime
import traceback
from netd.iptables_util import IptablesUtil

# This class is responsible for writing /etc/untangle-netd/iptables-rules.d/210-port-forward-rules
# based on the settings object passed from sync-settings.py
class PortForwardManager:
    defaultFilename = "/etc/untangle-netd/iptables-rules.d/210-port-forward-rules"
    filename = defaultFilename
    file = None

    def write_port_forward_rule( self, port_forward_rule, verbosity=0 ):

        if 'enabled' in port_forward_rule and not port_forward_rule['enabled']:
            return
        if 'matchers' not in port_forward_rule or 'list' not in port_forward_rule['matchers']:
            return
        if 'ruleId' not in port_forward_rule:
            return

        if 'newDestination' in port_forward_rule and 'newPort' in port_forward_rule:
            target = " -j DNAT --to-destination %s:%s " % ( str(port_forward_rule['newDestination']), str(port_forward_rule['newPort']) )
        elif 'newDestination' in port_forward_rule:
            target = " -j DNAT --to-destination %s " % str(port_forward_rule['newDestination'])
        else:
            print "ERROR: invalid port forward target: %s" + str(port_forward_rule)
            return

        description = "Port Forward Rule #%i" % int(port_forward_rule['ruleId'])
        iptables_conditions = IptablesUtil.conditions_to_iptables_string( port_forward_rule['matchers']['list'], description, verbosity );

        iptables_commands = [ "${IPTABLES} -t nat -A port-forward-rules " + ipt + target for ipt in iptables_conditions ]

        self.file.write("# %s\n" % description);
        for cmd in iptables_commands:
            self.file.write(cmd + "\n")
        self.file.write("\n");

        return

    def write_port_forward_rules( self, settings, verbosity=0 ):

        if settings == None or 'portForwardRules' not in settings or 'list' not in settings['portForwardRules']:
            print "ERROR: Missing Port Forward Rules"
            return
        
        port_forward_rules = settings['portForwardRules']['list'];

        for port_forward_rule in port_forward_rules:
            try:
                self.write_port_forward_rule( port_forward_rule, verbosity );
            except Exception,e:
                traceback.print_exc(e)

    def sync_settings( self, settings, prefix="", verbosity=0 ):
        if verbosity > 1: print "PortForwardManager: sync_settings()"

        self.filename = prefix + self.defaultFilename
        self.fileDir = os.path.dirname( self.filename )
        if not os.path.exists( self.fileDir ):
            os.makedirs( self.fileDir )

        self.file = open( self.filename, "w+" )
        self.file.write("## Auto Generated on %s\n" % datetime.datetime.now());
        self.file.write("## DO NOT EDIT. Changes will be overwritten.\n");
        self.file.write("\n\n");

        self.file.write("# Create (if needed) and flush port-forward-rules chain" + "\n");
        self.file.write("${IPTABLES} -t nat -N port-forward-rules 2>/dev/null" + "\n");
        self.file.write("${IPTABLES} -t nat -F port-forward-rules >/dev/null 2>&1" + "\n" + "\n");

        self.file.write("# Call port-forward-rules chain from PREROUTING chain to forward traffic" + "\n");
        self.file.write("${IPTABLES} -t nat -D PREROUTING -m conntrack --ctstate NEW -m comment --comment \"Port Forward rules\" -j port-forward-rules >/dev/null 2>&1" + "\n");
        self.file.write("${IPTABLES} -t nat -A PREROUTING -m conntrack --ctstate NEW -m comment --comment \"Port Forward rules\" -j port-forward-rules" + "\n" + "\n");

        self.write_port_forward_rules( settings, verbosity );

        self.file.flush();
        self.file.close();

        if verbosity > 0:
            print "PortForwardManager: Wrote %s" % self.filename

        return
