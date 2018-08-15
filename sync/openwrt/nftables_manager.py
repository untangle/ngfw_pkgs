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
nft add table ip prerouting-nat
nft add chain inet prerouting prerouting-set-marks "{ type filter hook prerouting priority -150 ; }"
# nft add chain inet prerouting packetd-queue "{ type nat hook prerouting priority -145 ; }"
nft add chain inet prerouting prerouting-qos "{ type filter hook prerouting priority -140 ; }"
nft add chain inet prerouting route-vote-rules "{ type filter hook prerouting priority -135 ; }"
nft add chain ip prerouting-nat port-forward-rules "{ type nat hook prerouting priority -100 ; }"
nft add chain ip prerouting-nat upnp-rules "{ type nat hook prerouting priority -99 ; }"

# postrouting skeleton
nft add table inet postrouting
nft add table ip postrouting-nat
nft add table ip postrouting-route
nft add table ip6 postrouting-route
nft add chain inet postrouting postrouting-qos "{ type filter hook postrouting priority -140 ; }"
nft add chain ip postrouting-nat postrouting-nat "{ type nat hook postrouting priority -100 ; }"
nft add chain ip postrouting-nat nat-rules "{ type nat hook postrouting priority -99 ; }"

# forward skeleton
nft add table inet forward
nft add chain inet forward forward-set-marks "{ type filter hook postrouting priority -150 ; }"
nft add chain inet forward filter-rules "{ type filter hook postrouting priority 0 ; }"

# FIXME - these should be moved to default settings in filter-rules
# Leaving them here for now
nft add chain inet forward filter-rules-nat
nft add chain inet forward filter-rules-new
nft add chain inet forward filter-rules-early
nft add chain inet forward filter-rules-all
nft add rule inet forward filter-rules jump filter-rules-nat
nft add rule inet forward filter-rules jump filter-rules-new
nft add rule inet forward filter-rules jump filter-rules-early
nft add rule inet forward filter-rules jump filter-rules-all

# input skeleton
nft add table inet input
# nft add chain inet input packetd-input "{ type filter hook input priority -150 ; }"
nft add chain inet input access-rules "{ type filter hook input priority 0 ; }"

# output skeleton
nft add table inet output
nft add table ip output-route
nft add table ip6 output-route
# nft add chain inet output packetd-output "{ type filter hook output priority -150 ; }"
nft add chain ip  output route-vote-rules "{ type route hook output priority -150 ; }"
nft add chain ip6 output route-vote-rules "{ type route hook output priority -150 ; }"

exit 0
        """)
        
    def sync_settings( self, settings, prefix, delete_list, verbosity=0 ):
        self.write_file(settings, prefix, verbosity)
        pass
        
registrar.register_manager(NftablesManager())
