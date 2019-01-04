"""This class is responsible for writing the system settings"""
# pylint: disable=unused-argument
from sync import registrar

class SystemManager:
    """SystemManager manages the system settings"""
    def initialize(self):
        """initialize this module"""
        pass

    def sanitize_settings(self, settings):
        """sanitizes settings"""
        pass

    def validate_settings(self, settings):
        """validates settings"""
        pass

    def create_settings(self, settings, prefix, delete_list, filename):
        """creates settings"""
        print("%s: Initializing settings" % self.__class__.__name__)
        settings['system'] = {}
        settings['system']['hostName'] = 'mfw'
        settings['system']['domainName'] = 'example.com'
        settings['system']['setupWizard'] = {"completed": False}

    def sync_settings(self, settings, prefix, delete_list):
        """syncs settings"""
        pass


registrar.register_manager(SystemManager())
