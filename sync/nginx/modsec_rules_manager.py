"""This class is responsible for writing out the IP Block/Allow lists"""
import os
from sync import registrar, Manager
import netaddr

class ModsecRulesManager(Manager):
    modsec_rules_conf="/etc/modsecurity.d/untangle-modsec-rules.conf"
    untangle_exclusion_file_before="/etc/modsecurity.d/owasp-crs/rules/REQUEST-900-UNTANGLE-EXCLUSION-BEFORE.conf"
    untangle_exclusion_file_after="/etc/modsecurity.d/owasp-crs/rules/RESPONSE-999-UNTANGLE-EXCLUSION-AFTER.conf"
    untangle_modsec_rules_conf="/etc/modsecurity.d/untangle-crs-rules.conf"
    start_rule_id = 3
    # map is ID to an array of ifSeen and ifEnabled. Start out with false for ifSeen and true of ifEnabled
    default_rule_sets_map = {
        "905": [False, True],
        "910": [False, True],
        "911": [False, True],
        "912": [False, True],
        "913": [False, True],
        "920": [False, True],
        "921": [False, True], 
        "930": [False, True],
        "931": [False, True],
        "932": [False, True],
        "933": [False, True],
        "934": [False, True],
        "941": [False, True],
        "942": [False, True],
        "943": [False, True],
        "944": [False, True],
        "949": [False, True],
        "950": [False, True],
        "951": [False, True],
        "952": [False, True],
        "953": [False, True],
        "954": [False, True],
    }
    
    def initialize(self):
        """initialize this module"""
        registrar.register_settings_file("settings", self)
        registrar.register_file(self.modsec_rules_conf, "restart-nginx", self)
        registrar.register_file(self.untangle_exclusion_file_before, "restart-nginx", self)
        registrar.register_file(self.untangle_exclusion_file_after, "restart-nginx", self)
        registrar.register_file(self.untangle_modsec_rules_conf, "restart-nginx", self)

    def create_settings(self, settings_file, prefix, delete_list, filename):
        """creates settings"""
        print("%s: Initializing settings" % self.__class__.__name__)
        settings_file = self.create_iplists_settings(settings_file)
        settings_file.settings['disabledRules'] = []
        settings_file.settings['ruleSets'] = {ruleSetId: self.default_rule_sets_map[ruleSetId][1] for ruleSetId in self.default_rule_sets_map.keys()}

    def sanitize_settings(self, settings_file):
        """sanitizes settings for ip lists"""
        print("%s: Sanitizing settings" % self.__class__.__name__)
        if "ipLists" not in settings_file.settings:
            settings_file = self.create_iplists_settings(settings_file)

        if 'ruleSets' not in settings_file.settings:
            settings_file.settings['ruleSets'] = {ruleSetId: self.default_rule_sets_map[ruleSetId][1] for ruleSetId in self.default_rule_sets_map.keys()}

    def sync_settings(self, settings_file, prefix, delete_list):
        """sync settings"""
        self.write_ipaccess_to_conf(settings_file, prefix)
        self.write_untangle_exclusion_rules_before(settings_file.settings, prefix)
        self.write_untangle_exclusion_rules_after(settings_file.settings, prefix)
        self.write_untangle_modsec_rules(settings_file.settings, prefix)

    def create_iplists_settings(self, settings_file):
        """create iplists settings in settings_file. Empty arrays for both block and allow list"""
        ipLists = {}
        ipLists['ipAllowList'] = []
        ipLists['ipBlockList'] = []
        settings_file.settings['ipLists'] = ipLists
        return settings_file

    def write_ipaccess_to_conf(self, settings_file, prefix):
        """write out the ip block and allow lists to the conf file"""
        filename = prefix + self.modsec_rules_conf
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        file = open(filename, "w+")
        ipAllowList = settings_file.settings['ipLists']['ipAllowList']
        if any(ip['enabled'] == True for ip in ipAllowList):
            allowedAddresses = self.prepare_iplist_for_ipmatch(ipAllowList)
            # any addresses that match here will skip all rule engine evalutation
            rule = "SecRule REMOTE_ADDR \"@ipMatch " + allowedAddresses + "\" \"id:1,phase:1,t:none,log,allow,msg:'IP is in IP Allow List'\"\n"
            file.write(rule)

        ipBlockList = settings_file.settings['ipLists']['ipBlockList']
        if any(ip['enabled'] == True for ip in ipBlockList):
            blockedAddresses = self.prepare_iplist_for_ipmatch(ipBlockList)
            # any addresses that match here will have their connections dropped
            rule = "SecRule REMOTE_ADDR \"@ipMatch " + blockedAddresses + "\" \"id:2,phase:1,t:none,log,deny,msg:'IP is in IP Block List'\"\n"
            file.write(rule)

        file.flush()
        file.close()

    def prepare_iplist_for_ipmatch(self, ipAddressList):
        """takes a list of ipAddress objects and put the IPs them in a comma-delimited list"""
        addresses = []
        for ip in ipAddressList:
            if ip['enabled'] == False: continue
            ipAddress = ip['ipAddress']
            parts = ipAddress.split("-")
            if len(parts) == 1:
                addresses.append(ipAddress)
            elif len(parts) == 2:
                # modsecurity doesn't support ranges for @ipMatch so the subnets must be calculated
                for ip in netaddr.iprange_to_cidrs(parts[0], parts[1]):
                    addresses.append(ip.ip.format())

        return ",".join(addresses)

    def write_untangle_exclusion_rules_before(self, settings, prefix):
        """write out the exclusion rules in the BEFORE exclusion file"""
        filename = prefix + self.untangle_exclusion_file_before
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        self.current_file = open(filename, "w+")
        file = self.current_file
        file.write("## Auto Generated\n")
        file.write("## DO NOT EDIT. Changes will be overwritten.\n\n\n")

        file.flush()
        file.close()

    def write_untangle_exclusion_rules_after(self, settings, prefix):
        """write out the exclusion rules in the AFTER exclusion file"""
        filename = prefix + self.untangle_exclusion_file_after
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        self.current_file = open(filename, "w+")
        file = self.current_file
        file.write("## Auto Generated\n")
        file.write("## DO NOT EDIT. Changes will be overwritten.\n\n\n")

        if 'disabledRules' in settings and len(settings['disabledRules']) > 0:
            for rule in settings['disabledRules']:
                file.write("SecRuleRemoveById " + rule + "\n")

        file.flush()
        file.close()
    
    def write_untangle_modsec_rules(self, settings, prefix):
        """write the untangle modsec rules conf file"""
        filename = prefix + self.untangle_modsec_rules_conf
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        self.current_file = open(filename, "w+")
        file = self.current_file
        file.write("## Auto Generated\n")
        file.write("## DO NOT EDIT. Changes will be overwritten.\n\n\n")

        # Initialization is needed always
        file.write("Include " + self.untangle_exclusion_file_before + "\n")
        file.write("Include /etc/modsecurity.d/owasp-crs/rules/REQUEST-901-INITIALIZATION.conf\n")
        
        # Application exclusions included by default, enabled in configuration
        file.write("Include /etc/modsecurity.d/owasp-crs/rules/REQUEST-903.9001-DRUPAL-EXCLUSION-RULES.conf\n")
        file.write("Include /etc/modsecurity.d/owasp-crs/rules/REQUEST-903.9002-WORDPRESS-EXCLUSION-RULES.conf\n")
        file.write("Include /etc/modsecurity.d/owasp-crs/rules/REQUEST-903.9003-NEXTCLOUD-EXCLUSION-RULES.conf\n")
        file.write("Include /etc/modsecurity.d/owasp-crs/rules/REQUEST-903.9004-DOKUWIKI-EXCLUSION-RULES.conf\n")
        file.write("Include /etc/modsecurity.d/owasp-crs/rules/REQUEST-903.9005-CPANEL-EXCLUSION-RULES.conf\n")
        file.write("Include /etc/modsecurity.d/owasp-crs/rules/REQUEST-903.9006-XENFORO-EXCLUSION-RULES.conf\n")
        
        # Rulesets - will need to add settings toggles
        toggles = settings["ruleSets"]
        # process toggles first to check for existence and unknown ids
        ruleSetsMap = self.default_rule_sets_map

        for toggle, value in toggles.items():
            if toggle in ruleSetsMap:
                ruleSetsMap[toggle] = [True, value]
            else:
                print ("Unknown ruleset seen from API")

        if any(ruleSet[1] == False for ruleSet in ruleSetsMap):
            print("Missing ruleset seen from API")

        file.write("Include /etc/modsecurity.d/owasp-crs/rules/REQUEST-905-COMMON-EXCEPTIONS.conf\n" if ruleSetsMap["905"][1] else "")
        file.write("Include /etc/modsecurity.d/owasp-crs/rules/REQUEST-910-IP-REPUTATION.conf\n" if ruleSetsMap["910"][1] else "")
        file.write("Include /etc/modsecurity.d/owasp-crs/rules/REQUEST-911-METHOD-ENFORCEMENT.conf\n" if ruleSetsMap["911"][1] else "")
        file.write("Include /etc/modsecurity.d/owasp-crs/rules/REQUEST-912-DOS-PROTECTION.conf\n" if ruleSetsMap["912"][1] else "")
        file.write("Include /etc/modsecurity.d/owasp-crs/rules/REQUEST-913-SCANNER-DETECTION.conf\n" if ruleSetsMap["913"][1] else "")
        file.write("Include /etc/modsecurity.d/owasp-crs/rules/REQUEST-920-PROTOCOL-ENFORCEMENT.conf\n" if ruleSetsMap["920"][1] else "")
        file.write("Include /etc/modsecurity.d/owasp-crs/rules/REQUEST-921-PROTOCOL-ATTACK.conf\n" if ruleSetsMap["921"][1] else "")
        file.write("Include /etc/modsecurity.d/owasp-crs/rules/REQUEST-930-APPLICATION-ATTACK-LFI.conf\n" if ruleSetsMap["930"][1] else "")
        file.write("Include /etc/modsecurity.d/owasp-crs/rules/REQUEST-931-APPLICATION-ATTACK-RFI.conf\n" if ruleSetsMap["931"][1] else "")
        file.write("Include /etc/modsecurity.d/owasp-crs/rules/REQUEST-932-APPLICATION-ATTACK-RCE.conf\n" if ruleSetsMap["932"][1] else "")
        file.write("Include /etc/modsecurity.d/owasp-crs/rules/REQUEST-933-APPLICATION-ATTACK-PHP.conf\n" if ruleSetsMap["933"][1] else "")
        file.write("Include /etc/modsecurity.d/owasp-crs/rules/REQUEST-934-APPLICATION-ATTACK-NODEJS.conf\n" if ruleSetsMap["934"][1] else "")
        file.write("Include /etc/modsecurity.d/owasp-crs/rules/REQUEST-941-APPLICATION-ATTACK-XSS.conf\n" if ruleSetsMap["941"][1] else "")
        file.write("Include /etc/modsecurity.d/owasp-crs/rules/REQUEST-942-APPLICATION-ATTACK-SQLI.conf\n" if ruleSetsMap["942"][1] else "")
        file.write("Include /etc/modsecurity.d/owasp-crs/rules/REQUEST-943-APPLICATION-ATTACK-SESSION-FIXATION.conf\n" if ruleSetsMap["943"][1] else "")
        file.write("Include /etc/modsecurity.d/owasp-crs/rules/REQUEST-944-APPLICATION-ATTACK-JAVA.conf\n" if ruleSetsMap["944"][1] else "")
        file.write("Include /etc/modsecurity.d/owasp-crs/rules/REQUEST-949-BLOCKING-EVALUATION.conf\n" if ruleSetsMap["949"][1] else "")
        file.write("Include /etc/modsecurity.d/owasp-crs/rules/RESPONSE-950-DATA-LEAKAGES.conf\n" if ruleSetsMap["950"][1] else "")
        file.write("Include /etc/modsecurity.d/owasp-crs/rules/RESPONSE-951-DATA-LEAKAGES-SQL.conf\n" if ruleSetsMap["951"][1] else "")
        file.write("Include /etc/modsecurity.d/owasp-crs/rules/RESPONSE-952-DATA-LEAKAGES-JAVA.conf\n" if ruleSetsMap["952"][1] else "")
        file.write("Include /etc/modsecurity.d/owasp-crs/rules/RESPONSE-953-DATA-LEAKAGES-PHP.conf\n" if ruleSetsMap["953"][1] else "")
        file.write("Include /etc/modsecurity.d/owasp-crs/rules/RESPONSE-954-DATA-LEAKAGES-IIS.conf\n" if ruleSetsMap["954"][1] else "")

        # always include following
        file.write("Include /etc/modsecurity.d/owasp-crs/rules/RESPONSE-959-BLOCKING-EVALUATION.conf\n")
        file.write("Include /etc/modsecurity.d/owasp-crs/rules/RESPONSE-980-CORRELATION.conf\n")
        file.write("Include " + self.untangle_exclusion_file_after + "\n")
        file.write("\n\n")
        file.flush()
        file.close()
        
registrar.register_manager(ModsecRulesManager())