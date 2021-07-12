"""This class is responsible for writing out the IP Block/Allow lists"""
from sync import registrar, Manager
import os
import netaddr

class ModsecRulesManager(Manager):
    modsec_rules_conf="/etc/modsecurity.d/untangle-modsec-rules.conf"
    
    def initialize(self):
        """initialize this module"""
        registrar.register_settings_file("settings", self)
        registrar.register_file(self.modsec_rules_conf, "restart-nginx", self)

    def create_settings(self, settings_file, prefix, delete_list, filename):
        """creates settings"""
        print("%s: Initializing settings" % self.__class__.__name__)
        settings_file = self.create_iplists_settings(settings_file)

    def sanitize_settings(self, settings_file):
        """sanitizes settings for ip lists"""
        print("%s: Sanitizing settings" % self.__class__.__name__)
        if "ipLists" not in settings_file.settings:
            settings_file = self.create_iplists_settings(settings_file)

    def create_iplists_settings(self, settings_file):
        """create iplists settings in settings_file. Empty arrays for both block and allow list"""
        ipLists = {}
        ipLists['ipAllowList'] = []
        ipLists['ipBlockList'] = []
        settings_file.settings['ipLists'] = ipLists
        return settings_file

    def sync_settings(self, settings_file, prefix, delete_list):
        self.write_ipaccess_to_conf(settings_file, prefix)

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

        
registrar.register_manager(ModsecRulesManager())