import os
import stat
import sys
import subprocess
import datetime
import traceback
from sync import registrar
from sync import nftables_util

# This class is responsible for writing FIXME
# based on the settings object passed from sync-settings
class RulesManager:
    filename_prefix = "/etc/config/nftables-rules.d/2"

    def initialize( self ):
        registrar.register_file(self.filename_prefix + ".*", "restart-nftables-rules", self)
        pass

    def create_settings( self, settings, prefix, delete_list, filename, verbosity=0 ):
        print("%s: Initializing settings" % self.__class__.__name__)
        tables = settings['firewall']['tables']
        tables['filter-rules'] = default_filter_rules_table()
        settings['firewall']['tables'] = tables

    def write_file(self, filename, table_settings, prefix, verbosity):
        file_dir = os.path.dirname( filename )
        if not os.path.exists( file_dir ):
            os.makedirs( file_dir )

        file = open( filename, "w+" )
        file.write("#!/bin/sh");
        file.write("\n\n");

        file.write("## Auto Generated\n");
        file.write("## DO NOT EDIT. Changes will be overwritten.\n");
        file.write("\n\n");

        file.write(nftables_util.table_all_cmds(table_settings) + "\n")

        # IMPLEMENT ME
        
        file.write("\n");
        file.flush()
        file.close()

        os.chmod(filename, os.stat(filename).st_mode | stat.S_IEXEC)
        if verbosity > 0: print("RulesManager: Wrote %s" % filename)
        return

    def write_files(self, settings, prefix, verbosity):
        if settings.get('firewall') == None or settings.get('firewall').get('tables') == None:
            return

        i = 0
        for table_name, table in settings.get('firewall').get('tables').items():
            if table.get('name') == None:
                raise Exception('Invalid table: Missing name')
            if table.get('family') == None:
                raise Exception('Invalid table %s: Missing family' % table.get('name'))
            if table.get('chains') == None:
                raise Exception('Invalid table %s: Missing chains' % table.get('name'))
                
            filename = prefix + self.filename_prefix + ("%02d-%s" % (i, table.get('name')))
            self.write_file(filename, table, prefix, verbosity)

    def sync_settings( self, settings, prefix, delete_list, verbosity=0 ):
        # FIXME need to delete previous 2.* files when syncing because those tables may have been remove from settings
        # delete_list.append("/etc/config/nftables-rules.d/2.*")
        # We should probably append all existing 2.* files to the delete_list and remove them when written
        self.write_files(settings, prefix, verbosity)
        pass
    
registrar.register_manager(RulesManager())

def default_filter_rules_table():
    return {
        "name": "filter-rules",
        "family": "inet",
        "chains": {
            "filter-rules": {
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
                        "chain": "filter-rules-new"
                    }
                },{
                    "enabled": True,
                    "description": "Call early-session session filter rules",
                    "ruleId": 2,
                    "conditions": [],
                    "action": {
                        "action": "JUMP",
                        "chain": "filter-rules-early"
                    }
                },{
                    "enabled": True,
                    "description": "Call deep-session (all packets) session filter rules",
                    "ruleId": 2,
                    "conditions": [],
                    "action": {
                        "action": "JUMP",
                        "chain": "filter-rules-all"
                    }
                }],
                "editable": False
            },
            "filter-rules-new": {
                "name": "filter-rules-new",
                "description": "The chain to process the first packet of each session (new sessions)",
                "default": True,
                "rules": [{
                    "ruleId": 1,
                    "description": "An example rule of blocking TCP sessions to 1.2.3.4 port 1234",
                    "enabled": False,
                    "conditions": [{
                        "type": "IP_PROTOCOL",
                        "op": "IS",
                        "value": "tcp"
                    },{
                        "type": "SERVER_ADDRESS",
                        "op": "IS",
                        "value": "1.2.3.4"
                    },{
                        "type": "SERVER_PORT",
                        "op": "IS",
                        "value": "1234"
                    }],
                    "action": {
                        "type": "REJECT"
                    }
                },{
                    "ruleId": 2,
                    "description": "An example rule of blocking TCP port 21 (FTP) from 192.168.1.100",
                    "enabled": False,
                    "conditions": [{
                        "type": "IP_PROTOCOL",
                        "op": "IS",
                        "value": "tcp"
                    },{
                        "type": "CLIENT_ADDRESS",
                        "op": "IS",
                        "value": "192.168.1.100"
                    },{
                        "type": "SERVER_PORT",
                        "op": "IS",
                        "value": "21"
                    }],
                    "action": {
                        "type": "REJECT"
                    }
                }]
            },
            "filter-rules-early": {
                "name": "filter-rules-early",
                "description": "The chain to process the first few packets of each session (early in session)",
                "rules": []
            },
            "filter-rules-all": {
                "name": "filter-rules-all",
                "description": "The chain to process the all packets",
                "rules": []
            }
        }
    }
