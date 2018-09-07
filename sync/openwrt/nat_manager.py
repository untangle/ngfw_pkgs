import os
import stat
import sys
import subprocess
import datetime
import traceback
from sync import registrar

# This class is responsible for writing FIXME
# based on the settings object passed from sync-settings
class NatManager:
    nat_rules_sys_filename = "/etc/config/nftables-rules.d/010-nat-rules-sys"

    def initialize(self):
        registrar.register_file(self.nat_rules_sys_filename, "restart-nftables-rules", self)
        pass
    
    def create_settings(self, settings, prefix, delete_list, filename, verbosity=0):
        pass

    def write_nat_rules_sys_file(self, settings, prefix, verbosity):
        filename = prefix + self.nat_rules_sys_filename
        file_dir = os.path.dirname( filename )
        if not os.path.exists( file_dir ):
            os.makedirs( file_dir )

        file = open( filename, "w+" )
        file.write("#!/bin/sh");
        file.write("\n\n");

        file.write("## Auto Generated\n");
        file.write("## DO NOT EDIT. Changes will be overwritten.\n");
        file.write("\n\n");
        
        try:
            file.write(r"""
nft add table ip nat
nft flush table ip nat
nft add chain ip nat nat-postrouting "{ type nat hook postrouting priority 100 ; }"
nft add chain ip nat nat-prerouting  "{ type nat hook prerouting priority -50 ; }"

nft add chain ip nat port-forward-rules-sys
nft add chain ip nat miniupnpd
nft add chain ip nat nat-rules-sys

nft add rule ip nat nat-postrouting oifname lo accept
nft add rule ip nat nat-postrouting iifname lo accept
nft add rule ip nat nat-postrouting jump nat-rules-sys

nft add rule ip nat nat-prerouting jump miniupnpd
nft add rule ip nat nat-prerouting jump port-forward-rule-sys

""")

            interfaces = settings.get('network').get('interfaces')
            for intf in interfaces:
                if intf.get('natEgress'):
                    # FIXME - this should be a rule based on mark instead of netfilterDev
                    # The mark rules don't exist yet, so just write the NAT rules using netfilterDev for now
                    file.write("# NAT Egress traffic to interface %i\n" % intf.get('interfaceId'))
                    file.write("nft add rule ip nat nat-rules-sys oifname %s masquerade\n" % intf.get('netfilterDev'))
                if intf.get('natIngress'):
                    # FIXME - this should be a rule based on mark instead of netfilterDev
                    # The mark rules don't exist yet, so just write the NAT rules using netfilterDev for now
                    file.write("# NAT Ingress traffic from interface %i\n" % intf.get('interfaceId'))
                    file.write("nft add rule ip nat nat-rules-sys iifname %s masquerade\n" % intf.get('netfilterDev'))
                    
            file.write("\n");
        except:
            print("ERROR:")
            traceback.print_exception()
        finally:
            file.flush()
            file.close()

        os.chmod(filename, os.stat(filename).st_mode | stat.S_IEXEC)
        if verbosity > 0: print("NatManager: Wrote %s" % filename)
        return

    def sync_settings( self, settings, prefix, delete_list, verbosity=0 ):
        self.write_nat_rules_sys_file(settings, prefix, verbosity)
        pass
    
registrar.register_manager(NatManager())
