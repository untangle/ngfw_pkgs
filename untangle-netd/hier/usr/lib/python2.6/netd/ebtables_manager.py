import os
import sys
import subprocess
import datetime
import traceback

# This class is responsible for writing /etc/untangle-netd/iptables-rules.d/020-ebtables
# based on the settings object passed from sync-settings.py
class EbtablesManager:
    defaultFilename = "/etc/untangle-netd/iptables-rules.d/020-ebtables"
    filename = defaultFilename
    file = None

    def sync_settings( self, settings, prefix="", verbosity=0 ):
        if verbosity > 1: print "EbtablesManager: sync_settings()"

        self.filename = prefix + self.defaultFilename
        self.fileDir = os.path.dirname( self.filename )
        if not os.path.exists( self.fileDir ):
            os.makedirs( self.fileDir )

        self.file = open( self.filename, "w+" )
        self.file.write("## Auto Generated on %s\n" % datetime.datetime.now());
        self.file.write("## DO NOT EDIT. Changes will be overwritten.\n");
        self.file.write("\n\n");

        self.file.write("## Don't BROUTE DHCP" + "\n")
        self.file.write("${EBTABLES} -t broute -I BROUTING -p ipv4 --ip-protocol udp --ip-dport 67:68 -j ACCEPT" + "\n")
        self.file.write("${EBTABLES} -t broute -I BROUTING -p ipv4 --ip-protocol udp --ip-sport 67:68 -j ACCEPT" + "\n")
        self.file.write("\n");

        self.file.write("## Don't BROUTE VRRP" + "\n")
        self.file.write("${EBTABLES} -t broute -I BROUTING -p ipv4 --ip-protocol vrrp -j ACCEPT" + "\n")
        self.file.write("\n");

        # Bypass routing protocols
        # http://www.iana.org/assignments/multicast-addresses/multicast-addresses.xhtml
        self.file.write("## Don't BROUTE RIP and other routing protocols" + "\n")
        self.file.write("${EBTABLES} -t broute -I BROUTING -p ipv4 --ip-destination 224.0.0.0/24 -j ACCEPT" + "\n")
        self.file.write("\n");

        # Bypass multicast
        self.file.write("## Don't BROUTE multicast" + "\n")
        self.file.write("${EBTABLES} -t broute -I BROUTING -p ipv4 --ip-destination 239.0.0.0/24 -j ACCEPT" + "\n")
        self.file.write("\n");
        
        self.file.write("## Broute everything else" + "\n")
        self.file.write("## ACCEPT here means to BROUTE the packet - BROUTE all IPv4 (http://ebtables.sourceforge.net/examples/basic.html#ex_redirect) " + "\n")
        self.file.write("${EBTABLES} -t broute -A BROUTING -p ipv4 -j redirect --redirect-target ACCEPT" + "\n" )
        self.file.write("\n");

        self.file.flush();
        self.file.close();

        if verbosity > 0:
            print "EbtablesManager: Wrote %s" % self.filename

        return

