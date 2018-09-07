import os
import stat
import sys
import subprocess
import datetime
import traceback
from sync import registrar

# This class is responsible for writing FIXME
# based on the settings object passed from sync-settings
class FilterRulesManager:
    filter_rules_filename = "/etc/config/nftables-rules.d/100-filter-rules"

    def initialize( self ):
        registrar.register_file(self.filter_rules_filename, "restart-nftables-rules", self)
        pass

    def create_settings( self, settings, prefix, delete_list, filename, verbosity=0 ):
        print("%s: Initializing settings" % self.__class__.__name__)
        forward_inet_table = {
            "name": "filter-rules",
            "family": "inet",
            "chains": [{
                "name": "filter-rules",
                "description": "The base filter-rules chain",
                "base": True,
                "type": "filter",
                "hook": "forward",
                "priority": 0,
                "rules": [{
                    "enabled": True,
                    "description": "Call new session filter rules",
                    "ruleId": 2,
                    "conditions": [],
                    "action": {
                        "action": "JUMP",
                        "chain": "forward-filter-new"
                    }
                },{
                    "enabled": True,
                    "description": "Call early-session session filter rules",
                    "ruleId": 2,
                    "conditions": [],
                    "action": {
                        "action": "JUMP",
                        "chain": "forward-filter-early"
                    }
                },{
                    "enabled": True,
                    "description": "Call deep-session (all packets) session filter rules",
                    "ruleId": 2,
                    "conditions": [],
                    "action": {
                        "action": "JUMP",
                        "chain": "forward-filter-all"
                    }
                }],
                "editable": False
            },{
                "name": "filter-rules-new",
                "description": "The chain to process the first packet of each session (new sessions)",
                "default": True,
                "rules": []
            },{
                "name": "filter-rules-early",
                "description": "The chain to process the first few packets of each session (early in session)",
                "rules": []
            },{
                "name": "filter-rules-all",
                "description": "The chain to process the all packets",
                "rules": []
            }]
        }
        tables = settings['firewall']['tables']
        tables.append(forward_inet_table)
        settings['firewall']['tables'] = tables

    def sync_settings( self, settings, prefix, delete_list, verbosity=0 ):
        pass
    
registrar.register_manager(FilterRulesManager())
