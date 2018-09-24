import os
import stat
import sys
import subprocess
import datetime
import traceback
from sync import registrar
from sync import nftables_util

# This class is responsible for writing all of the tables
# from settings/firewall/tables
class TableManager:
    filename_prefix = "/etc/config/nftables-rules.d/2"

    def initialize( self ):
        registrar.register_file(self.filename_prefix + ".*", "restart-nftables-rules", self)
        pass

    def create_settings( self, settings, prefix, delete_list, filename, verbosity=0 ):
        print("%s: Initializing settings" % self.__class__.__name__)

        tables = {}
        tables['filter-rules'] = default_filter_rules_table()
        tables['port-forward'] = default_port_forward_table()
        tables['vote'] = default_vote_table()
        tables['nat-rules'] = default_nat_rules_table()
        tables['access-rules'] = default_access_rules_table()
        tables['web-filter'] = default_web_filter_table()
        tables['captive-portal'] = default_captive_portal_table()
        
        settings['firewall'] = {}
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

        file.write("\n");
        file.flush()
        file.close()

        os.chmod(filename, os.stat(filename).st_mode | stat.S_IEXEC)
        if verbosity > 0: print("TableManager: Wrote %s" % filename)
        return

    def write_files(self, settings, prefix, verbosity):
        if settings.get('firewall') == None or settings.get('firewall').get('tables') == None:
            return

        i = 0
        for table_name, table in sorted(settings.get('firewall').get('tables').items()):
            if table.get('name') == None:
                raise Exception('Invalid table: Missing name')
            if table.get('family') == None:
                raise Exception('Invalid table %s: Missing family' % table.get('name'))
            if table.get('chains') == None:
                raise Exception('Invalid table %s: Missing chains' % table.get('name'))
                
            filename = prefix + self.filename_prefix + ("%02d-%s" % (i, table.get('name')))
            self.write_file(filename, table, prefix, verbosity)
            i=i+1

    def sync_settings( self, settings, prefix, delete_list, verbosity=0 ):
        # FIXME need to delete previous 2.* files when syncing because those tables may have been remove from settings
        # delete_list.append("/etc/config/nftables-rules.d/2.*")
        # We should probably append all existing 2.* files to the delete_list and remove them when written
        self.write_files(settings, prefix, verbosity)
        pass
    
registrar.register_manager(TableManager())

def default_filter_rules_table():
    return {
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
                "ruleId": 1,
                "conditions": [],
                "action": {
                    "type": "JUMP",
                    "chain": "filter-rules-new"
                }
            },{
                "enabled": True,
                "description": "Call early-session session filter rules",
                "ruleId": 2,
                "conditions": [],
                "action": {
                    "type": "JUMP",
                    "chain": "filter-rules-early"
                }
            },{
                "enabled": True,
                "description": "Call deep-session (all packets) session filter rules",
                "ruleId": 3,
                "conditions": [],
                "action": {
                    "type": "JUMP",
                    "chain": "filter-rules-all"
                }
            }]
        },{
            "name": "filter-rules-new",
            "description": "The chain to process the first packet of each session (new sessions)",
            "default": True,
            "rules": [{
                "ruleId": 1,
                "description": "Example: A rule of blocking TCP sessions to 1.2.3.4 port 1234",
                "enabled": False,
                "conditions": [{
                    "type": "IP_PROTOCOL",
                    "op": "==",
                    "value": "tcp"
                },{
                    "type": "SERVER_ADDRESS",
                    "op": "==",
                    "value": "1.2.3.4"
                },{
                    "type": "SERVER_PORT",
                    "op": "==",
                    "value": "1234"
                }],
                "action": {
                    "type": "REJECT"
                }
            },{
                "ruleId": 2,
                "description": "Example: A rule of blocking TCP port 21 (FTP) from 192.168.1.100",
                "enabled": False,
                "conditions": [{
                    "type": "IP_PROTOCOL",
                    "op": "==",
                    "value": "tcp"
                },{
                    "type": "CLIENT_ADDRESS",
                    "op": "==",
                    "value": "192.168.1.100"
                },{
                    "type": "SERVER_PORT",
                    "op": "==",
                    "value": "21"
                }],
                "action": {
                    "type": "REJECT"
                }
            }]
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

def default_port_forward_table():
    return {
        "name": "port-forward",
        "family": "ip,ip6",
        "chains": [{
            "name": "port-forward-rules",
            "description": "The base port-forwards chain",
            "base": True,
            "type": "nat",
            "hook": "prerouting",
            "priority": 100,
            "default": True,
            "rules": [{
                "enabled": False,
                "description": "Example: Forward 1.2.3.4 to 1.2.3.5",
                "ruleId": 1,
                "conditions": [{
                    "type": "DESTINATION_ADDRESS",
                    "op": "==",
                    "value": "1.2.3.4"
                }],
                "action": {
                    "type": "DNAT",
                    "dnat_address": "1.2.3.5"
                }
            }]
        }]
    }

def default_vote_table():
    return {
        "name": "vote",
        "family": "ip,ip6,inet",
        "chains": [{
            "name": "prerouting-route-vote-rules",
            "description": "The prerouting route vote rules",
            "base": True,
            "type": "filter",
            "hook": "prerouting",
            "priority": -130,
            "rules": [{
                "enabled": True,
                "description": "Call route-vote-rules",
                "ruleId": 1,
                "conditions": [],
                "action": {
                    "type": "JUMP",
                    "chain": "route-vote-rules"
                }
            }],
        },{
            "name": "output-route-vote-rules",
            "description": "The prerouting route vote rules",
            "base": True,
            "type": "route",
            "hook": "output",
            "priority": -140,
            "rules": [{
                "enabled": True,
                "description": "Call route-vote-rules",
                "ruleId": 1,
                "conditions": [],
                "action": {
                    "type": "JUMP",
                    "chain": "route-vote-rules"
                }
            }],
        },{
            "name": "route-vote-rules",
            "description": "The main route vote rules chain",
            "default": True,
            "rules": []
        }]
    }

def default_nat_rules_table():
    return {
        "name": "nat-rules",
        "family": "ip,ip6",
        "chains": [{
            "name": "nat-rules",
            "description": "The nat-rules chain",
            "base": True,
            "type": "nat",
            "hook": "postrouting",
            "priority": 95,
            "rules": [{
                "enabled": True,
                "description": "Example: NAT TCP port 25 to 1.2.3.4",
                "ruleId": 1,
                "conditions": [{
                    "type": "IP_PROTOCOL",
                    "op": "==",
                    "value": "tcp"
                },{
                    "type": "SERVER_PORT",
                    "op": "==",
                    "value": "1234"
                }],
                "action": {
                    "type": "SNAT",
                    "snat_address": "1.2.3.4"
                }
            },{
                "enabled": True,
                "description": "Example: NAT client 192.168.1.100 to 1.2.3.4",
                "ruleId": 1,
                "conditions": [{
                    "type": "SOURCE_ADDRESS",
                    "op": "==",
                    "value": "192.168.1.100"
                }],
                "action": {
                    "type": "SNAT",
                    "snat_address": "1.2.3.4"
                }
            },{
                "enabled": True,
                "description": "Example: NAT client 192.168.1.200 to Auto",
                "ruleId": 1,
                "conditions": [{
                    "type": "SOURCE_ADDRESS",
                    "op": "==",
                    "value": "192.168.1.200"
                }],
                "action": {
                    "type": "MASQUERADE"
                }
            }],
        }]
    }


def default_access_rules_table():
    return {
        "name": "access-rules",
        "family": "inet",
        "chains": [{
            "name": "access-rules",
            "description": "The base access-rules chain",
            "base": True,
            "type": "filter",
            "hook": "input",
            "priority": 0,
            "rules": [{
                "enabled": True,
                "description": "Allow established sessions",
                "ruleId": 1,
                "conditions": [{
                    "type": "CT_STATE",
                    "op": "==",
                    "value": "established"
                }],
                "action": {
                    "type": "ACCEPT"
                }
            },{
                "enabled": True,
                "description": "Allow related sessions",
                "ruleId": 2,
                "conditions": [{
                    "type": "CT_STATE",
                    "op": "==",
                    "value": "related"
                }],
                "action": {
                    "type": "ACCEPT"
                }
            },{
                "enabled": True,
                "description": "Block invalid packets",
                "ruleId": 2,
                "conditions": [{
                    "type": "CT_STATE",
                    "op": "==",
                    "value": "invalid"
                }],
                "action": {
                    "type": "DROP"
                }
            }]
        }]
    }


def default_web_filter_table():
    return {
        "name": "web-filter",
        "family": "ip,ip6",
        "chains": [{
            "name": "web-filter-rules",
            "description": "The base web-filter-rules chain",
            "base": True,
            "type": "nat",
            "hook": "prerouting",
            "priority": -105,
            "rules": []
        }]
    }

def default_captive_portal_table():
    return {
        "name": "captive-portal",
        "family": "ip,ip6",
        "chains": [{
            "name": "captive-portal-rules",
            "description": "The base captive-portal-rules chain",
            "base": True,
            "type": "nat",
            "hook": "prerouting",
            "priority": -110,
            "rules": []
        }]
    }
