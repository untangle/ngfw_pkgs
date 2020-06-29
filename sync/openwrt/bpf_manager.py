"""This class is responsible for writing bpf programs and attaching them to right hooks"""
# pylint: disable=unused-argument
import os 
import json
import shutil
from sync import registrar, Manager
from collections import OrderedDict

class BpfManager(Manager):    
    """
    Comments on class 
    """
    bpf_filename = "/etc/config/bpf.json"
    accepted_chain_types = ['filter']
    accepted_hook_types = ['input', 'output', 'forward']
    accepted_rule_condition_ops = ['==']
    accepted_rule_condition_types = ['DESTINATION_PORT', 'SOURCE_PORT']

    def initialize(self):
        """Initialize this module"""
        registrar.register_settings_file("settings", self)
        registrar.register_file(self.bpf_filename, None, self)

    #def sanitize_settings(self, settings_file):
    #    """
    #    Perform santiization on settings meant to be written back.
    #    """
    #    pass

    #def validate_settings(self, settings_file):
    #    """
    #    Perform validation of settings
    #    """
    #    pass

    def create_settings(self, settings_file, prefix, delete_list, filepath):
        """creates settings"""
        print("%s: Initializing settings" % self.__class__.__name__)

    def sync_settings(self, settings_file, prefix, delete_list):
        """syncs settings"""
        print ("%s: Syncing settings" % self.__class__.__name__)
        self.write_bpf_file(settings_file.settings, prefix)

    def write_bpf_file(self, settings, prefix=""):
        """writes prefix/etc/config/bpf"""
        filename = prefix + self.bpf_filename
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)
        
        firewall_tables = settings['firewall']['tables']

        file = open(filename, "w+")
        file.write("\n")

        json_str='['
        for table_name in firewall_tables:
            table = firewall_tables[table_name]
            if 'chain_type' in table.keys() and table['chain_type'] in self.accepted_chain_types:
                bpf_struct = {}
                bpf_struct['family-name'] = table['family']
                bpf_struct['table-name'] = table_name
                bpf_rules = []
                for chain in table['chains']:
                    if 'hook' in chain.keys():
                        if chain['hook'] in self.accepted_hook_types:
                            bpf_struct['firewall-hook'] = chain['hook']
                            bpf_struct['chain-name'] = chain['name']
        
                            bpf_rules = []
                            for rule in chain['rules']:
                                good_rule = False
                                if rule['enabled']:
                                    if len(rule['conditions']) == 0 and rule['action']['type'] == "DROP":
                                        bpf_rules.append(rule)
                                    else:
                                        for condition in rule['conditions']:
                                            if condition['op'] in self.accepted_rule_condition_ops:
                                                if condition['type'] in self.accepted_rule_condition_types:
                                                    good_rule = True
                                if good_rule:
                                    bpf_rule = {}
                                    bpf_rule['action'] = rule['action']
                                    bpf_rule['conditions'] = rule['conditions']
                                    bpf_rules.append(bpf_rule)

                            if len(bpf_rules) > 0:
                                bpf_struct['rules'] = bpf_rules
                                json_str = json_str + json.dumps(bpf_struct, indent=4) + ','
        json_str = json_str[:-1]
        json_str += ']'      
        file.write(json_str)

        file.flush()
        file.close()

        print("%s: Wrote %s" % (self.__class__.__name__, filename))


registrar.register_manager(BpfManager())
