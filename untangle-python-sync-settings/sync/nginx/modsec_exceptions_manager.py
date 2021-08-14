"""This class is responsible for writing out the IP Block/Allow lists"""
import os
from sync import registrar, Manager

class ModsecExceptionsManager(Manager):
    modsec_exceptions_conf="/etc/modsecurity.d/untangle-modsec-exceptions.conf"
    # 1000 - 1999 are reserved for exception IDs
    start_id=1000
    max_id=1999
    
    condition_op_map = {
        "REQUEST_URI": {
            "BEGINS_WITH": "@beginsWith",
            "ENDS_WITH": "@endsWith",
            "EQUALS": "@streq",
            "CONTAINS": "@contains"
        },
        "REQUEST_METHOD": {
            "EQUALS": "@streq"
        },
        "SERVER_PORT": {
            "EQUALS": "@eq"
        },
        "REMOTE_ADDR": {
            "EQUALS": "@ipMatch"
        }
    }

    action_map = {
        "DISABLE_RULE_ID": "ctl:ruleRemoveById"
    }
    
    def initialize(self):
        """initialize this module"""
        registrar.register_settings_file("settings", self)
        registrar.register_file(self.modsec_exceptions_conf, "restart-nginx", self)

    def create_settings(self, settings_file, prefix, delete_list, filename):
        """creates settings"""
        print("%s: Initializing settings" % self.__class__.__name__)
        settings_file.settings['exceptions'] = []

    def sanitize_settings(self, settings_file):
        """sanitizes settings for ip lists"""
        print("%s: Sanitizing settings" % self.__class__.__name__)     

        if 'exceptions' not in settings_file.settings:
            settings_file.settings['exceptions'] = []

    def sync_settings(self, settings_file, prefix, delete_list):
        """sync settings"""
        self.write_exceptions_to_conf(settings_file.settings, prefix)

   
    def write_exceptions_to_conf(self, settings, prefix):
        """
        write modsec exceptions to conf file
        without chaining:
            SecRule REMOTE_ADDR "@ipMatch 172.22.0.1"\
                "id:4,\
                phase:2,\
                pass,\
                log,\
                msg:'test',\
                tag:'Untangle-Waf-Manual-Exception',\
                t:none,\
                ctl:ruleRemoveById=941100,\
                ctl:ruleRemoveById=941120,\
                ctl:ruleRemoveById=941160"

        with chaining:
            SecRule REQUEST_URI "@streq /vulnerabilities/xss_r/?name=%3Cb+onmouseover%3Dalert%28%27Wufff%21%27%29%3Eclick+me%21%3C%2Fb%3E"\
                "id:4,\
                phase:2,\
                pass,\
                log,\
                msg:'test',\
                tag:'Untangle-Waf-Manual-Exception',\
                t:urlDecode,\
                chain"
                SecRule REMOTE_ADDR "@ipMatch 172.22.0.1"\
                    "t:none,\
                    ctl:ruleRemoveById=941100,\
                    ctl:ruleRemoveById=941120,\
                    ctl:ruleRemoveById=941160"
        """
        filename = prefix + self.modsec_exceptions_conf
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        file = open(filename, "w+")

        file.write("## Auto Generated\n")
        file.write("## DO NOT EDIT. Changes will be overwritten.\n")

        num_exceptions = len(settings['exceptions'])
        try:
            for exception_index in range(num_exceptions):
                exception = settings['exceptions'][exception_index]
                if exception['enabled'] == True:
                    num_conditions = len(exception['conditions'])
                    description = exception['description']
                    for i in range(num_conditions):
                        condition = exception['conditions'][i]
                        type = condition['type']
                        type_operators = self.condition_op_map[type]
                        operator = type_operators[condition['operator']]
                        value = self.get_condition_value(condition)
                        transform_function = self.get_condition_transform(type) 
                        # if index is 0, write the initial rule info
                        if i == 0:
                            id = self.start_id + exception_index
                            if id > self.max_id:
                                raise ValueError("Cannot have more than 1000 exceptions")
                            file.write(f'\n\nSecRule {type} "{operator} {value}"\\\n')
                            file.write(f'\t"id:{id},\\\n')
                            file.write('\tphase:2,\\\n')
                            file.write('\tpass,\\\n')
                            file.write('\tlog,\\\n')
                            file.write(f'\tmsg:\'{description}\',\\\n')
                            file.write('\ttag:\'Untangle-Waf-Manual-Exception\',\\\n')                        
                            file.write(f'\tt:{transform_function},\\\n')
                            # if more than one condition exists, add chain
                            if (num_conditions > 1):
                                file.write('\tchain"\n')
                            # otherwise, write the actions out
                            else:                            
                                self.write_exception_actions(file, 1, exception, False)
                        # otherwise, write the chains
                        else:
                            tabs = "\t"*i 
                            file.write(f'{tabs}SecRule {type} "{operator} {value}"\\\n')
                            prefix = '' if len(exception['conditions']) == 1 else '"'
                            file.write(f'{tabs}\t{prefix}t:{transform_function},\\\n')
                            self.write_exception_actions(file, i + 1, exception, i < num_conditions - 1)
        finally:            
            file.write("\n\n")
            file.flush()
            file.close()

    def write_exception_actions(self, conf_file, num_tabs, exception, chain):
        """write actions of an exception to conf file"""
        tabs = "\t"*num_tabs       
        # if chain, just write out chain. actions will be written out after final condition is written
        if chain:
            conf_file.write(f'{tabs}chain"\n')
        else:
            # if done chaining, write out actions
            num_actions = len(exception['actions'])  
            for i in range(num_actions):
                action = exception['actions'][i]
                type = action['type']
                value = action['value']
                modsec_action = self.action_map[type]
                conf_file.write(f'{tabs}{modsec_action}={value}')
                conf_file.write('"' if i == num_actions - 1 else ",\\\n")

    def get_condition_transform(self, condition_type):
        """determine how the server request should be transformed based on the condition type"""
        transform_function = 'none'
        if condition_type == 'REQUEST_URI': 
            transform_function = 'urlDecode'
        return transform_function

    def get_condition_value(self, condition):
        """
        get the condition value and transform to what the server expects
        i.e. request methods should be uppercase
        """
        value = condition['value']
        condition_type = condition['type']
        if condition_type == 'REQUEST_METHOD':
            value = value.upper()
        if condition_type == 'REMOTE_ADDR':
            # strip spaces from comma delimited list. 1.1.1.1, 2.2.2.2 => 1.1.1.1,2.2.2.2
            value = (',').join(map(lambda x: x.strip(), value.split(',')))
        return value

        
registrar.register_manager(ModsecExceptionsManager())