"""nat_manager manages the nat tables and settings"""
# pylint: disable=unused-argument
import os
import stat
from sync import registrar

# This class is responsible for writing FIXME
# based on the settings object passed from sync-settings


class NatManager:
    """NatManager manages the nat tables and settings"""
    nat_rules_sys_filename = "/etc/config/nftables-rules.d/100-nat"

    def initialize(self):
        """initialize this module"""
        registrar.register_file(self.nat_rules_sys_filename, "restart-nftables-rules", self)

    def sanitize_settings(self, settings):
        """sanitizes settings"""
        pass

    def validate_settings(self, settings):
        """validates settings"""
        pass

    def create_settings(self, settings, prefix, delete_list, filename):
        """creates settings"""
        pass

    def sync_settings(self, settings, prefix, delete_list):
        """syncs settings"""
        self.write_nat_rules_sys_file(settings, prefix)

    def write_nat_rules_sys_file(self, settings, prefix):
        "write the nat rules file"
        filename = prefix + self.nat_rules_sys_filename
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        file = open(filename, "w+")
        file.write("#!/bin/sh")
        file.write("\n\n")

        file.write("## Auto Generated\n")
        file.write("## DO NOT EDIT. Changes will be overwritten.\n")
        file.write("\n\n")

        file.write(r"""
nft delete table ip  nat-sys 2>/dev/null || true
nft delete table ip6 nat-sys 2>/dev/null || true
nft add table ip  nat-sys
nft add table ip6 nat-sys

nft add chain ip nat-sys postrouting-nat "{ type nat hook postrouting priority 100 ; }"
nft add chain ip nat-sys prerouting-nat  "{ type nat hook prerouting priority -50 ; }"
nft add chain ip6 nat-sys postrouting-nat "{ type nat hook postrouting priority 100 ; }"
nft add chain ip6 nat-sys prerouting-nat  "{ type nat hook prerouting priority -50 ; }"

nft add chain ip nat-sys miniupnpd
nft add chain ip nat-sys nat-rules-sys

nft add rule ip nat-sys postrouting-nat oifname lo accept
nft add rule ip nat-sys postrouting-nat iifname lo accept
nft add rule ip nat-sys postrouting-nat jump nat-rules-sys

nft add rule ip nat-sys prerouting-nat jump miniupnpd

nft add chain ip nat-sys filter-rules-nat "{ type filter hook forward priority -5 ; }"


""")

        interfaces = settings.get('network').get('interfaces')
        for intf in interfaces:
            if intf.get('configType') == 'DISABLED':
                continue
            if intf.get('natEgress'):
                # FIXME - this should be a rule based on mark instead of netfilterDev
                # The mark rules don't exist yet, so just write the NAT rules using netfilterDev for now
                file.write("# NAT Egress traffic to interface %i\n" % intf.get('interfaceId'))
                file.write("nft add rule ip nat-sys nat-rules-sys oifname %s masquerade\n" % intf.get('netfilterDev'))
            if intf.get('natIngress'):
                # FIXME - this should be a rule based on mark instead of netfilterDev
                # The mark rules don't exist yet, so just write the NAT rules using netfilterDev for now
                file.write("# NAT Ingress traffic from interface %i\n" % intf.get('interfaceId'))
                file.write("nft add rule ip nat-sys nat-rules-sys iifname %s masquerade\n" % intf.get('netfilterDev'))

        file.write("\n")
        file.flush()
        file.close()

        os.chmod(filename, os.stat(filename).st_mode | stat.S_IEXEC)
        print("NatManager: Wrote %s" % filename)
        return

registrar.register_manager(NatManager())
