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
    filename = "/etc/config/nftables-rules.d/010-initialize"

    def initialize(self):
        registrar.register_file(self.filename, "restart-networking", self)
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
nft add chain inet prerouting prerouting-set-marks "{ type filter hook prerouting priority -150 ; }"
# nft add chain inet prerouting packetd-queue "{ type nat hook prerouting priority -145 ; }"
nft add chain inet prerouting prerouting-qos "{ type filter hook prerouting priority -140 ; }"
nft add chain inet prerouting prerouting-route "{ type filter hook prerouting priority -135 ; }"
nft add chain ip   prerouting prerouting-nat "{ type nat hook prerouting priority -100 ; }"

# postrouting skeleton
nft add table inet postrouting
nft add table ip   postrouting
nft add chain ip   postrouting postrouting-nat "{ type nat hook postrouting priority 100 ; }"
nft add chain inet postrouting postrouting-set-marks "{ type filter hook postrouting priority 110 ; }"
nft add chain inet postrouting postrouting-qos "{ type filter hook postrouting priority 120 ; }"

# forward skeleton
nft add table inet forward
nft add chain inet forward forward-set-marks "{ type filter hook postrouting priority -150 ; }"
nft add chain inet forward forward-filter "{ type filter hook postrouting priority 0 ; }"

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
# nft add chain inet input packetd-input "{ type filter hook input priority -150 ; }"
nft add chain inet input input-filter "{ type filter hook input priority 0 ; }"
nft add chain inet input access-rules-sys
nft add chain inet input access-rules
nft add rule inet input input-filter jump access-rules-sys
nft add rule inet input input-filter jump access-rules

# output skeleton
nft add table inet output
nft add table ip   output
nft add table ip6  output
# nft add chain inet output packetd-output "{ type filter hook output priority -150 ; }"
nft add chain ip   output output-route "{ type route hook output priority -150 ; }"
nft add chain ip6  output output-route "{ type route hook output priority -150 ; }"

exit 0
        """)
        
    def sync_settings( self, settings, prefix, delete_list, verbosity=0 ):
        self.write_file(settings, prefix, verbosity)
        pass
        
registrar.register_manager(NftablesManager())
