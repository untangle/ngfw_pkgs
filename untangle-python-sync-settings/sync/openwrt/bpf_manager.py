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

    accepted_chain_types = {
        'filter': 0,
    }

    accepted_hook_types = {
        'input': 0, 
        'output': 1,
        'forward': 2,
    }

    accepted_rule_condition_ops = {
        '==': 0,
    }

    accepted_rule_condition_payload_types = {  
        'DESTINATION_PORT': 0,
        'SOURCE_PORT': 1,
    }

    accepted_rule_condition_network_types = {
        '6': 1
    }

    accepted_rule_condition_transport_types = {
        '6': 1,
    }

    rule_type =  {
	    'IMR_ALU_EQ_IMM32': 0,
        'IMR_DROP_ALL': 1
    }

    verdict = {
        'NONE': 0,	
        'NEXT': 1,
        'ACCEPT': 2,
        'DROP': 3
    }

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

    def condition_expression_single(self, conditions):
        """determines if conditions make a valid rule"""
        good_rule = 0
        bpf_condition = {}
        for condition in conditions:     
            #Protocol 
            if condition['type'] == 'IP_PROTOCOL' and condition['op'] == '==' and condition['value'] in self.accepted_rule_condition_network_types.keys():
                bpf_condition['network_layer'] = self.accepted_rule_condition_network_types[condition['value']]
                bpf_condition['transport_layer'] = self.accepted_rule_condition_transport_types[condition['value']]
                if bpf_condition['network_layer'] and bpf_condition['transport_layer']:
                    good_rule += 1
            #Payload/alu
            elif condition['type'] in self.accepted_rule_condition_payload_types.keys():
                if condition['op'] in self.accepted_rule_condition_ops.keys():
                    good_rule += 1 
                    bpf_condition['op'] = self.accepted_rule_condition_ops[condition['op']]
                    bpf_condition['payload'] = self.accepted_rule_condition_payload_types[condition['type']]
                    bpf_condition['immediate'] = int(condition['value'])
            #source_interface - future 
            elif condition['type'] == 'SOURCE_INTERFACE_TYPE':
                good_rule += 1
                bpf_condition['src-interface'] = int(condition['value'])

        #if each conditions is valid, good_rule will be equal to length of conditions and hence return a condition
        if good_rule == len(conditions):
            return bpf_condition
        return None

    def rule_expression(self, rule, ruleIdSeq):
        """determines if rule is a valid rule"""
        good_rule_bool = False
        bpf_condition = None
        rule_type = self.rule_type['IMR_ALU_EQ_IMM32'] #default is ALU_EQ_IMM32
        if len(rule['conditions']) == 0 and rule['action']['type'] == "DROP" and rule['ruleId'] == ruleIdSeq:
            good_rule_bool = True
            rule_type = self.rule_type['IMR_DROP_ALL']
            bpf_condition = {'drop': 'all'}
        elif len(rule['conditions']) == 1: #exclude CT_STATE for now from ordering considerations
            if rule['conditions'][0]['type'] == 'CT_STATE':
                good_rule_bool = True
            # don't need to stop for lo acceptances
            if rule['conditions'][0]['type'] == 'SOURCE_INTERFACE_NAME' and rule['conditions'][0]['value'] == 'lo': 
                good_rule_bool = True
        elif len(rule['conditions']) == 3 or len(rule['conditions']) == 2: #single payload/alu 
            bpf_condition = self.condition_expression_single(rule['conditions'])
        
        #good_rule_bool is set if rules that are valid but not written out 
        #bpf_condition is written to as not None if the rule is valid 
        if good_rule_bool or bpf_condition:
            good_rule_bool = False
            bpf_rule = {}
            bpf_rule['type'] = rule_type
            bpf_rule['action'] = self.verdict[rule['action']['type']]
            bpf_rule['conditions'] = bpf_condition
            bpf_rule['id'] = rule['ruleId']
            return bpf_rule

        return None

    def chain_expression(self, chain):
        """determines if chains is a valid chain"""
        bpf_rules = []
        for rule in chain['rules']:
            bpf_rule_temp = None
            if rule['enabled']: 
                if rule['action']['type'] in self.verdict.keys():
                    bpf_rule_temp = self.rule_expression(rule, chain['ruleIdSeq'])
                    #if not a null rule, then append 
                    if bpf_rule_temp:
                        #conditions has to have non-zero length to be valid and written out
                        if bpf_rule_temp['conditions']:
                            bpf_rules.append(bpf_rule_temp)
                    #when run across a rule that is not valid, stop filtering to preserve order
                    else:
                        break
                #when run across a rule that is not valid, stop filtering to preserve order
                else:
                    break
                
        #return rules if there are more than one rule 
        if len(bpf_rules) > 0:
            return bpf_rules 

        return None

    def table_expression(self, table):
        """determines if table is a valid table"""
        json_str = ''
        bpf_struct = {}
        for chain in table['chains']:
            bpf_rules = None
            if 'hook' in chain.keys() and chain['hook'] in self.accepted_hook_types.keys():
                bpf_rules = self.chain_expression(chain)
                #if any rules are valid, write them out
                if bpf_rules:
                    bpf_struct['family-name'] = table['family']
                    bpf_struct['table-name'] = table['name']
                    bpf_struct['firewall-hook'] = chain['hook']
                    bpf_struct['chain-name'] = chain['name']
                    bpf_struct['rules'] = bpf_rules 
                    json_str = json_str + json.dumps(bpf_struct, indent=4) +','

        return json_str

    def write_bpf_file(self, settings, prefix=""):
        """writes prefix/etc/config/bpf"""
        filename = prefix + self.bpf_filename
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)
        
        firewall_tables = settings['firewall']['tables']

        file = open(filename, "w+")
        file.write("\n")

        #loop through tables 
        json_str='['
        for table_name in firewall_tables:
            table = firewall_tables[table_name]
            if 'chain_type' in table.keys() and table['chain_type'] in self.accepted_chain_types.keys():
                json_str = json_str + self.table_expression(table)

        #write out json_str
        if len(json_str) > 1:
            json_str = json_str[:-1]
        json_str += ']'      
        file.write(json_str)

        file.flush()
        file.close()

        print("%s: Wrote %s" % (self.__class__.__name__, filename))


registrar.register_manager(BpfManager())
