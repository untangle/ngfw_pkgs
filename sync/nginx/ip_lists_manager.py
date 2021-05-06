"""This class is responsible for writing out the IP Block/Allow lists"""
from sync import registrar, manager

class IPListsManager(Manager):
    ip_allow_list = "/etc/ipAllowList"
    
    def initialize(self):
        """initialize this module"""
        registrar.register_settings_file("settings", self)
        registrar.register_file(self.ip_allow_list, None, self)

    def create_settings(self, settings_file, prefix, delete_list, filename):
        """creates settings"""
        print("%s: Initializing settings" % self.__class__.__name__)
        ipLists = {}
        ipLists['ipAllowList'] = []
        ipLists['ipBlockList'] = []
        settings_file.settings['ipLists'] = ipLists
        
registrar.register_manager(IPListsManager())