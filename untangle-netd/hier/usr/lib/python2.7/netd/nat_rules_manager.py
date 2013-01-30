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

    def write_ingress_nat_rules( self, src_intf, interfaces ):
        if not 'interfaceId' in src_intf or not 'name' in src_intf:
            print "ERROR: Missing settings on interface!"
            return;

        for dst_intf in interfaces:
            # ignore bad interfaces
            if not 'interfaceId' in dst_intf or not 'name' in dst_intf:
                print "ERROR: Missing settings on intf!"
                continue;

            # skip self
            if dst_intf['interfaceId'] == src_intf['interfaceId']:
                continue;

            # ignore interfaces bridged with interface
            if dst_intf['config'] == 'bridged' and dst_intf['bridgedTo'] == src_intf['interfaceId']:
                continue;
            
            self.file.write("# NAT ingress traffic coming from \"%s\"" % src_intf['name'] + "\n");
            self.file.write("${IPTABLES} -t nat -A nat-rules -m connmark --mark 0x%0.4X -m comment --comment \"NAT traffic, %i -> %i (ingress setting)\" -j MASQUERADE" % 
                            ( ((dst_intf['interfaceId'] << 8) + src_intf['interfaceId']),
                              src_intf['interfaceId'],
                              dst_intf['interfaceId'] ))
            self.file.write("\n\n");

            # FIXME put this is a chain!!
            self.file.write("# block traffic to NATd interface \"%s\" (except port forwarded/DNAT traffic)" % src_intf['name'] + "\n");
            self.file.write("${IPTABLES} -t filter -A FORWARD -m connmark --mark 0x%0.4X -m conntrack ! --ctstate DNAT -m comment --comment \"Block traffic to NATd interace, %i -> %i (ingress setting)\" -j REJECT" % 
                            ( ((src_intf['interfaceId'] << 8) + dst_intf['interfaceId']),
                              dst_intf['interfaceId'],
                              src_intf['interfaceId'] ))
            self.file.write("\n\n");

        return

    def write_egress_nat_rules( self, dst_intf, interfaces ):
        if not 'interfaceId' in dst_intf or not 'name' in dst_intf:
            print "ERROR: Missing settings on interface!"
            return;

        for src_intf in interfaces:
            # ignore bad interfaces
            if not 'interfaceId' in src_intf or not 'name' in src_intf:
                print "ERROR: Missing settings on intf!"
                continue;

            # skip self
            if src_intf['interfaceId'] == dst_intf['interfaceId']:
                continue;

            # ignore interfaces bridged with interface
            if src_intf['config'] == 'bridged' and src_intf['bridgedTo'] == dst_intf['interfaceId']:
                continue;
            
            self.file.write("# NAT egress traffic exiting \"%s\"" % dst_intf['name'] + "\n");
            self.file.write("${IPTABLES} -t nat -A nat-rules -m connmark --mark 0x%0.4X -m comment --comment \"NAT traffic, %i -> %i (egress setting)\" -j MASQUERADE" % 
                            ( ((dst_intf['interfaceId'] << 8) + src_intf['interfaceId']),
                              src_intf['interfaceId'],
                              dst_intf['interfaceId'] ))
            self.file.write("\n\n");

            self.file.write("# block traffic from NATd interface \"%s\" (except port forwarded/DNAT traffic)" % dst_intf['name'] + "\n");
            self.file.write("${IPTABLES} -t filter -A FORWARD -m connmark --mark 0x%0.4X -m conntrack ! --ctstate DNAT -m comment --comment \"Block traffic to NATd interace, %i -> %i (egress setting)\" -j REJECT" % 
                            ( ((src_intf['interfaceId'] << 8) + dst_intf['interfaceId']),
                              dst_intf['interfaceId'],
                              src_intf['interfaceId'] ))
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
