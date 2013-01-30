import os
import sys
import subprocess
import datetime
import traceback

# This class is responsible for writing /etc/netd/iptables-rules.d/200-nat-rules
# based on the settings object passed from sync-settings.py
class NatRulesManager:
    defaultFilename = "/etc/netd/iptables-rules.d/200-nat-rules"
    filename = defaultFilename
    file = None

    def write_ingress_nat_rules( self, intf, interfaces ):
        if not 'interfaceId' in intf or not 'name' in intf:
            print "ERROR: Missing settings on interface!"
            return;

        for other_intf in interfaces:
            # ignore bad interfaces
            if not 'interfaceId' in other_intf or not 'name' in other_intf:
                print "ERROR: Missing settings on intf!"
                continue;

            # skip self
            if other_intf['interfaceId'] == intf['interfaceId']:
                continue;

            # ignore interfaces bridged with interface
            if other_intf['config'] == 'bridged' and other_intf['bridgedTo'] == intf['interfaceId']:
                continue;
            
            self.file.write("# NAT ingress traffic coming from \"%s\"" % intf['name'] + "\n");
            self.file.write("${IPTABLES} -t nat -A nat-rules -m connmark --mark 0x%0.4X/0xffff -m comment --comment \"NAT traffic, %i -> %i (ingress setting)\" -j MASQUERADE" % 
                            ( ((other_intf['interfaceId'] << 8) + intf['interfaceId']),
                              intf['interfaceId'],
                              other_intf['interfaceId'] ))
            self.file.write("\n\n");

            # FIXME put this in a special chain
            self.file.write("# block traffic to NATd interface \"%s\" (except port forwarded/DNAT traffic)" % intf['name'] + "\n");
            self.file.write("${IPTABLES} -t filter -A FORWARD -m connmark --mark 0x%0.4X/0xffff -m conntrack ! --ctstate DNAT -m comment --comment \"Block traffic to NATd interace, %i -> %i (ingress setting)\" -j REJECT" % 
                            ( ((intf['interfaceId'] << 8) + other_intf['interfaceId']),
                              other_intf['interfaceId'],
                              intf['interfaceId'] ))
            self.file.write("\n\n");

        return

    def write_egress_nat_rules( self, intf, interfaces ):
        if not 'interfaceId' in intf or not 'name' in intf:
            print "ERROR: Missing settings on interface!"
            return;

        for other_intf in interfaces:
            # ignore bad interfaces
            if not 'interfaceId' in other_intf or not 'name' in other_intf:
                print "ERROR: Missing settings on intf!"
                continue;

            # skip self
            if other_intf['interfaceId'] == intf['interfaceId']:
                continue;

            # ignore interfaces bridged with interface
            if other_intf['config'] == 'bridged' and other_intf['bridgedTo'] == intf['interfaceId']:
                continue;
            
            self.file.write("# NAT egress traffic exiting \"%s\"" % intf['name'] + "\n");
            self.file.write("${IPTABLES} -t nat -A nat-rules -m connmark --mark 0x%0.4X/0xffff -m comment --comment \"NAT traffic, %i -> %i (egress setting)\" -j MASQUERADE" % 
                            ( ((intf['interfaceId'] << 8) + other_intf['interfaceId']),
                              other_intf['interfaceId'],
                              intf['interfaceId'] ))
            self.file.write("\n\n");

            # FIXME put this in a special chain
            self.file.write("# block traffic from NATd interface \"%s\" (except port forwarded/DNAT traffic)" % intf['name'] + "\n");
            self.file.write("${IPTABLES} -t filter -A FORWARD -m connmark --mark 0x%0.4X/0xffff -m conntrack ! --ctstate DNAT -m comment --comment \"Block traffic to NATd interace, %i -> %i (egress setting)\" -j REJECT" % 
                            ( ((other_intf['interfaceId'] << 8) + intf['interfaceId']),
                              intf['interfaceId'],
                              other_intf['interfaceId'] ))
            self.file.write("\n\n");

        return

    def write_interface_nat_options( self, settings, verbosity=0 ):

        if settings == None or settings['interfaces'] == None or settings['interfaces']['list'] == None:
            print "ERROR: Missisg interfaces settings!"
            return

        interfaces = settings['interfaces']['list']
        for interface_settings in interfaces:

            if 'v4NatEgressTraffic' in interface_settings and interface_settings['v4NatEgressTraffic']:
                self.write_egress_nat_rules( interface_settings, interfaces )

            if 'v4NatIngressTraffic' in interface_settings and interface_settings['v4NatIngressTraffic']:
                self.write_ingress_nat_rules( interface_settings, interfaces )

        return

    def sync_settings( self, settings, prefix="", verbosity=0 ):
        if verbosity > 1: print "NatRulesManager: sync_settings()"

        self.filename = prefix + self.defaultFilename
        self.fileDir = os.path.dirname( self.filename )
        if not os.path.exists( self.fileDir ):
            os.makedirs( self.fileDir )

        self.file = open( self.filename, "w+" )
        self.file.write("## Auto Generated on %s\n" % datetime.datetime.now());
        self.file.write("## DO NOT EDIT. Changes will be overwritten.\n");
        self.file.write("\n\n");

        self.file.write("# Create chain if it does not exist" + "\n");
        self.file.write("${IPTABLES} -t nat -N nat-rules 2>/dev/null" + "\n" + "\n");

        self.file.write("# Flush chain if it exists" + "\n");
        self.file.write("${IPTABLES} -t nat -F nat-rules >/dev/null 2>&1" + "\n" + "\n");

        self.write_interface_nat_options( settings, verbosity )

        self.file.flush()
        self.file.close()

        if verbosity > 0:
            print "NatRulesManager: Wrote %s" % self.filename

        return
