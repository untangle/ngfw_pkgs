import os
import stat
import sys
import subprocess
import datetime
import traceback
from sync import registrar
from sync import nftables_util

# This class is responsible for writing /etc/config/nftables-rules.d/001-skeleton
# based on the settings object passed from sync-settings
class NftablesManager:
    filename = "/etc/config/nftables-rules.d/001-skeleton"

    def initialize(self):
        registrar.register_file(self.filename, "restart-nftables-rules", self)
        pass

    def create_settings(self, settings, prefix, delete_list, filename, verbosity=0):
        print("%s: Initializing settings" % self.__class__.__name__)
        settings['firewall'] = {}
        settings['firewall']['tables'] = {}
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
# TODO marks table should be managed in an interface_manager
nft delete table inet marks 2>/dev/null || true
nft add table inet marks
nft add chain inet marks prerouting-set-marks "{ type filter hook prerouting priority -150 ; }"
nft add chain inet marks forward-set-marks "{ type filter hook forward priority -150 ; }"
nft add chain inet marks postrouting-set-marks "{ type filter hook postrouting priority 110 ; }"
nft add chain inet marks output-set-marks "{ type filter hook output priority 110 ; }"
nft add chain inet marks restore-interface-marks
nft add chain inet marks restore-priority-mark
nft add chain inet marks mark-src-interface
nft add chain inet marks mark-dst-interface
nft add chain inet marks check-src-interface-mark
nft add chain inet marks check-dst-interface-mark
nft add rule inet marks prerouting-set-marks jump restore-interface-marks
nft add rule inet marks prerouting-set-marks jump restore-priority-mark
nft add rule inet marks prerouting-set-marks ct state new jump mark-src-interface
nft add rule inet marks prerouting-set-marks jump check-src-interface-mark
nft add rule inet marks forward-set-marks ct state new jump mark-dst-interface
nft add rule inet marks postrouting-set-marks ct state new jump mark-dst-interface
nft add rule inet marks postrouting-set-marks jump check-dst-interface-mark
nft add rule inet marks output-set-marks jump restore-interface-marks
nft add rule inet marks output-set-marks jump restore-priority-mark

# TODO qos table should be managed in qos_manager
nft delete table inet qos 2>/dev/null || true
nft add table inet qos
nft add chain inet qos qos-imq "{ type filter hook prerouting priority -130 ; }"

# TODO port-forwards tables should be created/managed elsewhere - it is a user table
nft delete table inet port-forwards 2>/dev/null || true
nft add table inet port-forwards
nft add chain inet port-forwards port-forward-rules "{ type filter hook prerouting priority -105 ; }"

# TODO web-filter table should be created/managed elsewhere - it is a user table
nft delete table inet web-filter 2>/dev/null || true
nft add table inet web-filter
nft add chain inet web-filter web-filter-rules "{ type filter hook prerouting priority -95  ; }"

# TODO captive-portal table should be created/managerd elsewhere - it is a user table
nft delete table inet captive-portal 2>/dev/null || true
nft add table inet captive-portal
nft add chain inet captive-portal captive-portal-rules "{ type filter hook prerouting priority -90  ; }"

# TODO shaping table should be created/managed elsewhere - it is a user table
nft delete table inet shaping 2>/dev/null || true
nft add table inet shaping
nft add chain inet shaping prerouting-shaping-rules "{ type filter hook prerouting priority -140 ; }"
nft add chain inet shaping output-shaping-rules "{ type filter hook output priority -130 ; }"
nft add chain inet shaping shaping-rules
nft add rule inet shaping prerouting-shaping-rules jump shaping-rules
nft add rule inet shaping output-shaping-rules jump shaping-rules

# TODO vote table should be created/managed elsewhere - it is a user table
nft delete table inet vote 2>/dev/null || true
nft delete table ip   vote 2>/dev/null || true
nft delete table ip6  vote 2>/dev/null || true
nft add table inet vote
nft add table ip   vote
nft add table ip6  vote
nft add chain inet vote prerouting-route-vote-rules "{ type filter hook prerouting priority -130 ; }"
nft add chain ip   vote output-route-vote-rules  "{ type route hook output priority -140 ; }"
nft add chain ip6  vote output-route-vote-rules  "{ type route hook output priority -140 ; }"
nft add chain inet vote route-vote-rules
nft add chain ip   vote route-vote-rules
nft add chain ip6  vote route-vote-rules
nft add rule inet vote prerouting-route-vote-rules jump route-vote-rules
nft add rule ip  vote output-route-vote-rules jump route-vote-rules
nft add rule ip6 vote output-route-vote-rules jump route-vote-rules

# TODO filter-rules-sys should be managed in filter_rule_manager
nft delete table inet filter-rules-sys 2>/dev/null || true
nft add table inet filter-rules-sys
nft add chain inet filter-rules-sys filter-rules-sys "{ type filter hook forward priority -5 ; }"

# TODO - nat-rules table should be created/managed in elsewhere - it is a user table
nft delete table inet nat-rules 2>/dev/null || true
nft add table inet nat-rules
nft add chain inet nat-rules nat-rules "{ type filter hook postrouting priority 100 ; }"

# TODO access-rules table should be created in access_rule_manager
nft delete table inet access-rules-sys 2>/dev/null || true
nft add table inet access-rules-sys
nft add chain inet access-rules-sys access-rules-sys "{ type filter hook input priority -5 ; }"

# TODO access-rules table should be created/managed elsewhere - it is a user table
nft delete table inet access-rules 2>/dev/null || true
nft add table inet access-rules
nft add chain inet access-rules access-rules "{ type filter hook input priority 0 ; }"

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
