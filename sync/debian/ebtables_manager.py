import os
import sys
import subprocess
import datetime
import traceback
from sync import registrar,Manager

# This class is responsible for writing /etc/untangle/iptables-rules.d/020-ebtables
# based on the settings object passed from sync-settings


class EbtablesManager(Manager):
    iptables_filename = "/etc/untangle/iptables-rules.d/020-ebtables"
    filename = iptables_filename
    file = None

    def initialize(self):
        registrar.register_settings_file("network", self)
        registrar.register_file(self.iptables_filename, "restart-iptables", self)

    def validate_settings(self, settings):
        pass

    def sync_settings(self, settings, prefix, delete_list):
        self.write_file(settings, prefix)

    def write_file(self, settings, prefix=""):
        self.filename = prefix + self.iptables_filename
        self.file_dir = os.path.dirname(self.filename)
        if not os.path.exists(self.file_dir):
            os.makedirs(self.file_dir)

        self.file = open(self.filename, "w+")
        self.file.write("## Auto Generated\n")
        self.file.write("## DO NOT EDIT. Changes will be overwritten.\n")
        self.file.write("\n\n")

        self.file.write("## Don't BROUTE DHCP" + "\n")
        self.file.write("${EBTABLES} -t broute -I BROUTING -p ipv4 --ip-protocol udp --ip-dport 67:68 -j ACCEPT" + "\n")
        self.file.write("${EBTABLES} -t broute -I BROUTING -p ipv4 --ip-protocol udp --ip-sport 67:68 -j ACCEPT" + "\n")
        self.file.write("\n")

        self.file.write("## Don't BROUTE VRRP" + "\n")
        self.file.write("${EBTABLES} -t broute -I BROUTING -p ipv4 --ip-protocol vrrp -j ACCEPT" + "\n")
        self.file.write("\n")

        # Bypass multicast
        # http://www.iana.org/assignments/multicast-addresses/multicast-addresses.xhtml
        self.file.write("## Don't BROUTE RIP and other routing protocols" + "\n")
        self.file.write("${EBTABLES} -t broute -I BROUTING -p ipv4 --ip-destination 224.0.0.0/4 -j ACCEPT" + "\n")
        self.file.write("\n")

        self.file.write("## Broute everything else" + "\n")
        self.file.write("## DROP here means to BROUTE the packet - BROUTE all IPv4 (http://ebtables.sourceforge.net/examples/basic.html#ex_redirect) " + "\n")
        self.file.write("${EBTABLES} -t broute -A BROUTING -p ipv4 -j redirect --redirect-target DROP" + "\n")
        self.file.write("\n")

        self.file.flush()
        self.file.close()

        print("EbtablesManager: Wrote %s" % self.filename)

        return


registrar.register_manager(EbtablesManager())
