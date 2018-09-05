import os
import stat
import sys
import subprocess
import datetime
import traceback
from sync import registrar

# This class is responsible for writing /etc/config/nftables-rules.d/001-skeleton
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
# TODO marks table should be managed in an interface_manager
nft flush table inet marks 2>/dev/null || true
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
nft flush table inet qos 2>/dev/null || true
nft add table inet qos
nft add chain inet qos qos-imq "{ type filter hook prerouting priority -130 ; }"

# TODO upnp table should be managed in upnp_manager
nft flush table ip upnp 2>/dev/null || true
nft add table ip upnp
nft add chain ip upnp prerouting-upnp "{ type nat hook prerouting priority -100 ; }"

# TODO port-forwards tables should be created/managed elsewhere - it is a user table
nft flush table ip   port-forwards 2>/dev/null || true
nft flush table ip6  port-forwards 2>/dev/null || true
nft add table ip  port-forwards
nft add table ip6 port-forwards
nft add chain ip  port-forwards port-forward-rules "{ type nat hook prerouting priority -105 ; }"
nft add chain ip6 port-forwards port-forward-rules "{ type nat hook prerouting priority -105 ; }"

# TODO web-filter table should be created/managed elsewhere - it is a user table
nft flush table ip  web-filter 2>/dev/null || true
nft flush table ip6 web-filter 2>/dev/null || true
nft add table ip  web-filter
nft add table ip6 web-filter
nft add chain ip  web-filter web-filter-rules "{ type nat hook prerouting priority -95  ; }"
nft add chain ip6 web-filter web-filter-rules "{ type nat hook prerouting priority -95  ; }"

# TODO captive-portal table should be created/managerd elsewhere - it is a user table
nft flush table ip  captive-portal 2>/dev/null || true
nft flush table ip6 captive-portal 2>/dev/null || true
nft add table ip  captive-portal
nft add table ip6 captive-portal
nft add chain ip  captive-portal captive-portal-rules "{ type nat hook prerouting priority -90  ; }"
nft add chain ip6 captive-portal captive-portal-rules "{ type nat hook prerouting priority -90  ; }"

# TODO shaping table should be created/managed elsewhere - it is a user table
nft flush table inet shaping 2>/dev/null || true
nft add table inet shaping
nft add chain inet shaping prerouting-shaping-rules "{ type filter hook prerouting priority -140 ; }"
nft add chain inet shaping output-shaping-rules "{ type filter hook output priority -130 ; }"
nft add chain inet shaping shaping-rules
nft add rule inet shaping prerouting-shaping-rules jump shaping-rules
nft add rule inet shaping output-shaping-rules jump shaping-rules

# TODO vote table should be created/managed elsewhere - it is a user table
nft flush table inet vote 2>/dev/null || true
nft flush table ip   vote 2>/dev/null || true
nft flush table ip6  vote 2>/dev/null || true
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
nft flush table inet filter-rules-sys 2>/dev/null || true
nft add table inet filter-rules-sys
nft add chain inet filter-rules-sys filter-rules-nat "{ type filter hook forward priority -5 ; }"

# TODO - filter-rules table should be created/managed elsewhere - it is a user table
nft flush table inet filter-rules 2>/dev/null || true
nft add table inet filter-rules
nft add chain inet filter-rules filter-rules "{ type filter hook forward priority 0 ; }"
nft add chain inet filter-rules filter-rules-new
nft add chain inet filter-rules filter-rules-early
nft add chain inet filter-rules filter-rules-all
nft add rule inet filter-rules filter-rules ct state new jump filter-rules-new 
nft add rule inet filter-rules filter-rules jump filter-rules-early
nft add rule inet filter-rules filter-rules jump filter-rules-all

# TODO - nat-rules-sys table should be managed in nat_manager
nft flush table ip nat-rules-sys 2>/dev/null || true
nft add table ip nat-rules-sys
nft add chain ip nat-rules-sys nat-rules-sys "{ type nat hook postrouting priority 95 ; }"

# TODO - nat-rules table should be created/managed in elsewhere - it is a user table
nft flush table ip nat-rules 2>/dev/null || true
nft add table ip nat-rules
nft add chain ip nat-rules nat-rules "{ type nat hook postrouting priority 100 ; }"

# TODO access-rules table should be created in access_rule_manager
nft flush table inet access-rules-sys 2>/dev/null || true
nft add table inet access-rules-sys
nft add chain inet access-rules-sys access-rules-sys "{ type filter hook input priority -5 ; }"

# TODO access-rules table should be created/managed elsewhere - it is a user table
nft flush table inet access-rules 2>/dev/null || true
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
