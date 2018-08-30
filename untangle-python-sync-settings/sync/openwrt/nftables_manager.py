import os
import stat
import sys
import subprocess
import datetime
import traceback
from sync import registrar

# This class is responsible for writing FIXME
# based on the settings object passed from sync-settings
class NftablesManager:
    filename = "/etc/config/nftables-rules.d/001-skeleton"

    def initialize(self):
        registrar.register_file(self.filename, "restart-nftables-rules", self)
        pass

    def create_settings(self, settings, prefix, delete_list, filename, verbosity=0):
        pass

    def write_file(self, settings, prefix, verbosity):
        filename = prefix + self.filename
        file_dir = os.path.dirname( filename )
        if not os.path.exists( file_dir ):
            os.makedirs( file_dir )

        file = open( filename, "w+" )
        file.write("#!/bin/sh");
        file.write("\n\n");

        file.write("## Auto Generated\n");
        file.write("## DO NOT EDIT. Changes will be overwritten.\n");
        file.write("\n\n");
        
        file.write(r"""
nft flush ruleset

# prerouting skeleton
nft add table inet prerouting
nft add table ip   prerouting
nft add table ip6  prerouting
nft add chain inet prerouting prerouting-set-marks "{ type filter hook prerouting priority -150 ; }"
nft add chain inet prerouting prerouting-packetd "{ type filter hook prerouting priority -145 ; }"
nft add chain inet prerouting prerouting-qos "{ type filter hook prerouting priority -140 ; }"
nft add chain inet prerouting prerouting-route "{ type filter hook prerouting priority -135 ; }"
nft add chain ip   prerouting prerouting-nat "{ type nat hook prerouting priority -100 ; }"
nft add chain ip6  prerouting prerouting-nat "{ type nat hook prerouting priority -100 ; }"

nft add chain inet prerouting restore-interface-marks
nft add chain inet prerouting restore-priority-mark
nft add chain inet prerouting mark-src-interface
nft add chain inet prerouting check-interface-marks
nft add rule inet prerouting prerouting-set-marks jump restore-interface-marks
nft add rule inet prerouting prerouting-set-marks jump restore-priority-mark
nft add rule inet prerouting prerouting-set-marks jump mark-src-interface
nft add rule inet prerouting prerouting-set-marks jump check-interface-marks

nft add chain inet prerouting prioritization-qos
nft add chain inet prerouting qos-imq
nft add rule inet prerouting prerouting-qos jump prioritization-qos
nft add rule inet prerouting prerouting-qos jump qos-imq

nft add chain ip  prerouting port-forward-rules
nft add chain ip6 prerouting port-forward-rules
nft add chain ip  prerouting upnp-rules
nft add chain ip6 prerouting upnp-rules
nft add chain ip  prerouting web-filter-rules-sys
nft add chain ip6 prerouting web-filter-rules-sys
nft add chain ip  prerouting web-filter-rules
nft add chain ip6 prerouting web-filter-rules
nft add chain ip  prerouting captive-portal-rules
nft add chain ip6 prerouting captive-portal-rules
nft add rule ip  prerouting prerouting-nat jump port-forward-rules
nft add rule ip6 prerouting prerouting-nat jump port-forward-rules
nft add rule ip  prerouting prerouting-nat jump upnp-rules
nft add rule ip6 prerouting prerouting-nat jump upnp-rules
nft add rule ip  prerouting prerouting-nat jump web-filter-rules-sys
nft add rule ip6 prerouting prerouting-nat jump web-filter-rules-sys
nft add rule ip  prerouting prerouting-nat jump web-filter-rules
nft add rule ip6 prerouting prerouting-nat jump web-filter-rules
nft add rule ip  prerouting prerouting-nat jump captive-portal-rules
nft add rule ip6 prerouting prerouting-nat jump captive-portal-rules

# postrouting skeleton
nft add table inet postrouting
nft add table ip   postrouting
nft add chain ip   postrouting postrouting-nat "{ type nat hook postrouting priority 100 ; }"
nft add chain inet postrouting postrouting-set-marks "{ type filter hook postrouting priority 110 ; }"
nft add chain inet postrouting postrouting-qos "{ type filter hook postrouting priority 120 ; }"

nft add chain ip  postrouting nat-rules-sys
nft add chain ip  postrouting nat-rules
nft add chain inet postrouting restore-priority-mark
nft add chain inet postrouting mark-dst-interface
nft add chain inet postrouting prioritization-rules
nft add rule ip  postrouting postrouting-nat jump nat-rules-sys
nft add rule ip  postrouting postrouting-nat jump nat-rules
nft add rule inet postrouting postrouting-set-marks jump restore-priority-mark
nft add rule inet postrouting postrouting-set-marks jump mark-dst-interface
nft add rule inet postrouting postrouting-qos jump prioritization-rules

# forward skeleton
nft add table inet forward
nft add chain inet forward forward-set-marks "{ type filter hook forward priority -150 ; }"
nft add chain inet forward forward-filter "{ type filter hook forward priority 0 ; }"

# FIXME - these should be moved to default settings in forward-filter
# Leaving them here for now
nft add chain inet forward filter-rules-sys
nft add chain inet forward filter-rules-nat
nft add chain inet forward filter-rules-new
nft add chain inet forward filter-rules-early
nft add chain inet forward filter-rules-all
nft add rule inet forward forward-filter jump filter-rules-sys
nft add rule inet forward forward-filter jump filter-rules-nat
nft add rule inet forward forward-filter jump filter-rules-new
nft add rule inet forward forward-filter jump filter-rules-early
nft add rule inet forward forward-filter jump filter-rules-all

# input skeleton
nft add table inet input
nft add chain inet input input-packetd "{ type filter hook input priority -150 ; }"
nft add chain inet input input-filter "{ type filter hook input priority 0 ; }"
nft add chain inet input access-rules-sys
nft add chain inet input access-rules
nft add rule inet input input-filter jump access-rules-sys
nft add rule inet input input-filter jump access-rules

# output skeleton
nft add table inet output
nft add table ip   output
nft add table ip6  output
nft add chain inet output output-packetd "{ type filter hook output priority -150 ; }"
nft add chain ip   output output-route "{ type route hook output priority -150 ; }"
nft add chain ip6  output output-route "{ type route hook output priority -150 ; }"

nft add chain ip  output route-vote-rules
nft add chain ip6 output route-vote-rules
nft add rule ip  output output-route jump route-vote-rules
nft add rule ip6 output output-route jump route-vote-rules


exit 0
        """)

        file.write("\n");
        file.flush()
        file.close()

        os.chmod(filename, os.stat(filename).st_mode | stat.S_IEXEC)
        if verbosity > 0: print("NftablesManager: Wrote %s" % filename)
        return
        
    def sync_settings( self, settings, prefix, delete_list, verbosity=0 ):
        self.write_file(settings, prefix, verbosity)
        pass
        
registrar.register_manager(NftablesManager())
