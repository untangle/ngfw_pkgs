"""This class is responsible for writing the nat-sys chain"""
# pylint: disable=unused-argument
import os
import stat
from sync import registrar
from sync import board_util

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

        # docker runs in the same kernel as the host, most hosts kernel do not yet support multiple NAT hooks
        # docker needs the iptables NAT hooks so we can't insert nft nat rules or it will break iptables NAT
        if board_util.is_docker():
            file.write("#!/bin/sh")
            file.write("\n\n")

            file.write("## Auto Generated\n")
            file.write("## DO NOT EDIT. Changes will be overwritten.\n")
            file.write("\n")
            file.write("iptables -t nat -A POSTROUTING -j MASQUERADE" + "\n")
            file.flush()
            file.close()
            os.chmod(filename, os.stat(filename).st_mode | stat.S_IEXEC)
            print("NatManager: Wrote %s" % filename)
            return

        file.write("#!/usr/bin/nft_debug -f")
        file.write("\n\n")

        file.write("## Auto Generated\n")
        file.write("## DO NOT EDIT. Changes will be overwritten.\n")
        file.write("\n\n")
        file.write(r"""
add table ip  nat-sys
flush table ip  nat-sys
add table ip6 nat-sys
flush table ip6 nat-sys

add chain ip nat-sys postrouting-nat { type nat hook postrouting priority 100 ; }
add chain ip nat-sys prerouting-nat  { type nat hook prerouting priority -50 ; }
add chain ip6 nat-sys postrouting-nat { type nat hook postrouting priority 100 ; }
add chain ip6 nat-sys prerouting-nat  { type nat hook prerouting priority -50 ; }

add chain ip nat-sys miniupnpd
add chain ip nat-sys nat-rules-sys

add rule ip nat-sys postrouting-nat oifname lo accept
add rule ip nat-sys postrouting-nat iifname lo accept
add rule ip nat-sys postrouting-nat jump nat-rules-sys

add rule ip nat-sys prerouting-nat jump miniupnpd


""")

        interfaces = settings.get('network').get('interfaces')
        for intf in interfaces:
            if not intf.get('enabled'):
                continue
            if intf.get('natEgress'):
                # FIXME - this should be a rule based on mark instead of netfilterDev
                # The mark rules don't exist yet, so just write the NAT rules using netfilterDev for now
                file.write("# NAT Egress traffic to interface %i\n" % intf.get('interfaceId'))
                file.write("add rule ip nat-sys nat-rules-sys oifname %s masquerade\n" % intf.get('netfilterDev'))
            if intf.get('natIngress'):
                # FIXME - this should be a rule based on mark instead of netfilterDev
                # The mark rules don't exist yet, so just write the NAT rules using netfilterDev for now
                file.write("# NAT Ingress traffic from interface %i\n" % intf.get('interfaceId'))
                file.write("add rule ip nat-sys nat-rules-sys iifname %s masquerade\n" % intf.get('netfilterDev'))

        file.write("\n")
        file.flush()
        file.close()

        os.chmod(filename, os.stat(filename).st_mode | stat.S_IEXEC)
        print("NatManager: Wrote %s" % filename)
        return

registrar.register_manager(NatManager())
