"""settings_manager manages /etc/config/current.json"""
# pylint: disable=unused-argument
import os
import json
import shutil
import requests
from sync import registrar, Manager
from collections import OrderedDict

# This class is responsible for writing /etc/config/network
# based on the settings object passed from sync-settings

class SettingsManager(Manager):
    """
    This class is responsible for writing the settings file
    and general settings initialization
    """
    default_filename = "/usr/share/untangle/waf/settings/defaults.json"
    settings_filename = "/usr/share/untangle/waf/settings/current.json"
    version_filename = "/usr/share/untangle/waf/settings/version"

    def initialize(self):
        """initialize this module"""
        registrar.register_settings_file("settings", self)
        registrar.register_file(self.settings_filename, None, self)

    def create_settings(self, settings_file, prefix, delete_list, filepath):
        """creates settings"""
        print("%s: Initializing settings" % self.__class__.__name__)

        #Get version
        settings_file.settings['version'] = get_version(self.version_filename)

        filename = prefix + filepath
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        json_str = json.dumps(settings_file.settings, indent=4)

        file = open(filename, "w+")
        file.write(json_str)
        file.write("\n")
        file.flush()
        file.close()

        print("%s: Wrote %s" % (self.__class__.__name__, filename))
    
    def sanitize_settings(self, settings_file):
        """santize settings sets settings to defaults that are set but not enabled"""
        print("%s: Sanitizing settings" % self.__class__.__name__)

    def sync_settings(self, settings_file, prefix, delete_list):
        """syncs settings"""
        # orig_settings_filename = settings_file.settings["filename"]
        orig_settings_filename = settings_file.file_name
        filename = prefix + self.settings_filename
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)
        shutil.copyfile(orig_settings_filename, filename)
        print("%s: Wrote %s" % (self.__class__.__name__, filename))

registrar.register_manager(SettingsManager())

def get_version(version_filename):
    version = "0.0"
    version_file = open(version_filename, "r")
    if version_file.mode == "r":
        version = version_file.read().strip()
    else:
        print("ERROR: failed to open version file")

    version_file.close()

    return version