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
    nat_rules_filename     = "/etc/config/nftables-rules.d/011-nat-rules"

    def initialize(self):
        registrar.register_file(self.nat_rules_sys_filename, "restart-nftables-rules", self)
        registrar.register_file(self.nat_rules_filename,     "restart-nftables-rules", self)
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
# Do not NAT loopback traffic
nft add rule ip nat nat-rules-sys oifname lo accept
nft add rule ip nat nat-rules-sys iifname lo accept
""")

            interfaces = settings.get('network').get('interfaces')
            for intf in interfaces:
                if intf.get('natEgress'):
                    # FIXME - this should be a rule based on mark instead of netfilterDev
                    # The mark rules don't exist yet, so just write the NAT rules using netfilterDev for now
                    file.write("# NAT Egress traffic to interface %i\n" % intf.get('interfaceId'))
                    file.write("nft add rule ip postrouting nat-rules-sys oifname %s masquerade\n" % intf.get('netfilterDev'))
                if intf.get('natIngress'):
                    # FIXME - this should be a rule based on mark instead of netfilterDev
                    # The mark rules don't exist yet, so just write the NAT rules using netfilterDev for now
                    file.write("# NAT Ingress traffic from interface %i\n" % intf.get('interfaceId'))
                    file.write("nft add rule ip postrouting nat-rules-sys iifname %s masquerade\n" % intf.get('netfilterDev'))
                    
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

    def write_nat_rules_file(self, settings, prefix, verbosity):
        filename = prefix + self.nat_rules_filename
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
# FIXME
""")
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
        self.write_nat_rules_file(settings, prefix, verbosity)
        pass
    
registrar.register_manager(NatManager())
