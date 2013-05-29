import os
import sys
import subprocess
import datetime
import traceback
from netd.iptables_util import IptablesUtil

# This class is responsible for writing /etc/untangle-netd/iptables-rules.d/230-port-forward-rules
# based on the settings object passed from sync-settings.py
class PortForwardManager:
    defaultFilename = "/etc/untangle-netd/iptables-rules.d/230-port-forward-rules"
    adminFilename = "/etc/untangle-netd/iptables-rules.d/250-admin-port-rules"
    srcInterfaceMarkMask = 0x00ff
    filename = defaultFilename
    file = None

    # We shouldn't port forward administration and block pages ports
    # write a rule to protect this traffic
    def write_admin_ignore_rules( self, settings, verbosity=0 ):
        try :
            from uvm.settings_reader import get_uvm_settings_item
            https_port = get_uvm_settings_item('system','httpsPort')
            inside_http_enabled = get_uvm_settings_item('system','insideHttpEnabled')
            outside_https_enabled = get_uvm_settings_item('system','outsideHttpsEnabled')
        except Exception,e:
            traceback.print_exc(e)

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

    def write_port_forwards( self, settings, prefix="", verbosity=0):

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

        self.write_admin_ignore_rules( settings, verbosity );
        self.write_port_forward_rules( settings, verbosity );

        self.file.flush();
        self.file.close();

        if verbosity > 0:
            print "PortForwardManager: Wrote %s" % self.filename

    def write_admin_port_rules( self, settings, prefix="", verbosity=0):

        self.filename = prefix + self.adminFilename
        self.fileDir = os.path.dirname( self.filename )
        if not os.path.exists( self.fileDir ):
            os.makedirs( self.fileDir )

        self.file = open( self.filename, "w+" )
        self.file.write("## Auto Generated on %s\n" % datetime.datetime.now());
        self.file.write("## DO NOT EDIT. Changes will be overwritten.\n");
        self.file.write("\n\n");

        https_port = settings.get('httpsPort')
        outside_https_enabled = settings.get('outsideHttpsEnabled')

        # write rules to protect blockpage ports
        # This is one rule for each non-WAN allowing it to reach port 80 of the internal IP on the main address of that interface only.
        for interface_settings in settings.get('interfaces').get('list'):
            # only non-WAN interfaces
            if interface_settings.get('configType') == 'ADDRESSED' and interface_settings.get('isWan'):
                continue
            self.file.write("# don't allow port forwarding of port 80 of primary IP on non-WAN interface %i.\n" % interface_settings.get('interfaceId'))
            self.file.write("ADDR=\"`ip addr show %s | awk '/^ *inet.*scope global/ { interface = $2 ; sub( \"/.*\", \"\", interface ) ; print interface ; exit }'`\"\n" % interface_settings.get('symbolicDev'))
            self.file.write("if [ ! -z \"${ADDR}\" ] ; then" + "\n")
            self.file.write("\t${IPTABLES} -t nat -I port-forward-rules -p tcp -m mark --mark 0x%04X/0x%04X --destination ${ADDR} --destination-port 80 -j REDIRECT --to-ports 80 -m comment --comment \"Reserve port 80 on ${ADDR} for blockpages\"" % (interface_settings.get('interfaceId'), self.srcInterfaceMarkMask) + "\n")
            self.file.write("fi" + "\n")
        self.file.write("\n");

        # write rules to protect admin ports
        # this a set of rules for each interface allowing it to reach HTTPS on the primary IP of any interfaces
        for source_intf in settings.get('interfaces').get('list'):
            if source_intf.get('configType') == 'ADDRESSED' and source_intf.get('isWan') and not outside_https_enabled:
                continue
            for intf in settings.get('interfaces').get('list'):
                if intf.get('configType') != 'ADDRESSED':
                    continue
                self.file.write("# forward HTTPS admin from intf %i to local apache process\n" % source_intf.get('interfaceId'))
                self.file.write("ADDR=\"`ip addr show %s | awk '/^ *inet.*scope global/ { interface = $2 ; sub( \"/.*\", \"\", interface ) ; print interface ; exit }'`\"\n" % intf.get('symbolicDev'))
                self.file.write("if [ ! -z \"${ADDR}\" ] ; then" + "\n")
                self.file.write("\t${IPTABLES} -t nat -I port-forward-rules -p tcp  -m mark --mark 0x%04X/0x%04X --destination ${ADDR} --destination-port %i -j REDIRECT --to-ports 443 -m comment --comment \"Redirect admin traffic to port 443\"" % (source_intf.get('interfaceId'), self.srcInterfaceMarkMask, https_port) + "\n")
                self.file.write("fi" + "\n")
                self.file.write("\n");


        self.file.write("\n\n");
        self.file.flush();
        self.file.close();

        if verbosity > 0:
            print "PortForwardManager: Wrote %s" % self.filename

    def sync_settings( self, settings, prefix="", verbosity=0 ):
        if verbosity > 1: print "PortForwardManager: sync_settings()"

        self.write_port_forwards( settings, prefix, verbosity);
        self.write_admin_port_rules( settings, prefix, verbosity);

        return
