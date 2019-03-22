"""settings_manager manages /etc/config/current.json"""
# pylint: disable=unused-argument
import os
import json
import shutil
from sync import registrar

# This class is responsible for writing /etc/config/network
# based on the settings object passed from sync-settings

class SettingsManager:
    """
    This class is responsible for writing /etc/config/current.json
    and general settings initialization
    """
    settings_filename = "/etc/config/current.json"

    def initialize(self):
        """initialize this module"""
        registrar.register_file(self.settings_filename, None, self)

    def sanitize_settings(self, settings):
        """sanitizes removes blank settings"""
        pass

    def validate_settings(self, settings):
        """validates settings"""
        pass

    def create_settings(self, settings, prefix, delete_list, filepath):
        """creates settings"""
        print("%s: Initializing settings" % self.__class__.__name__)

        settings['version'] = 1

        filename = prefix + filepath
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        json_str = json.dumps(settings, indent=4)

        file = open(filename, "w+")
        file.write(json_str)
        file.write("\n")
        file.flush()
        file.close()

        print("%s: Wrote %s" % (self.__class__.__name__, filename))

    def sync_settings(self, settings, prefix, delete_list):
        """syncs settings"""
        orig_settings_filename = settings["filename"]
        filename = prefix + self.settings_filename
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)
        shutil.copyfile(orig_settings_filename, filename)
        print("%s: Wrote %s" % (self.__class__.__name__, filename))

registrar.register_manager(SettingsManager())
