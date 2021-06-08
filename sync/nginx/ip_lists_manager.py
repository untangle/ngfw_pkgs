"""This class is responsible for writing out the IP Block/Allow lists"""
from sync import registrar, Manager

class IPListsManager(Manager):
    ip_allow_list = "/etc/ipAllowList"
    
    def initialize(self):
        """initialize this module"""
        registrar.register_settings_file("settings", self)
        registrar.register_file(self.ip_allow_list, None, self)

    def create_settings(self, settings_file, prefix, delete_list, filename):
        """creates settings"""
        print("%s: Initializing settings" % self.__class__.__name__)
        settings_file = self.create_iplists_settings(settings_file)

    def sanitize_settings(self, settings_file):
        """sanitizes settings for ip lists"""
        if "ipLists" in settings_file.settings:
            settings_file = self.create_iplists_settings(settings_file)

    def create_iplists_settings(self, settings_file):
        ipLists = {}
        ipLists['ipAllowList'] = []
        ipLists['ipBlockList'] = []
        settings_file.settings['ipLists'] = ipLists
        return settings_file
        
registrar.register_manager(IPListsManager())