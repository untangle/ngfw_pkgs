"""settings_manager manages /etc/config/current.json"""
# pylint: disable=unused-argument
import os
import json
import shutil
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
    ui_version_filename = "/usr/share/untangle/waf/settings/ui-version"

    def initialize(self):
        """initialize this module"""
        registrar.register_settings_file("settings", self)
        registrar.register_file(self.settings_filename, None, self)
        registrar.register_file(self.version_filename, None, self)
        registrar.register_file(self.ui_version_filename, None, self)

    def create_settings(self, settings_file, prefix, delete_list, filepath):
        """creates settings"""
        print("%s: Initializing settings" % self.__class__.__name__)

        self.set_versions(settings_file.settings)
        self.default_timezone(settings_file.settings)

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

        serverSettings = settings_file.settings.get('server')

        sslSettings = serverSettings['serverSsl']
        if (sslSettings.get('enabled') is None):
            # Add SSL Enabled field if our defaults predate this version
            sslSettings['enabled'] = False

        self.default_timezone(settings_file.settings)
        self.set_versions(settings_file.settings)

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


    def default_timezone(self, settings):
        """applies the default timezone"""
        if 'timezone' not in settings:
            settings['timezone'] = 'UTC'

    def set_versions(self, settings):
        """gets the build version and hashes"""
        settings['version'] = get_semver_from_file(self.version_filename, "0.0", "major.minor.patch")
        settings['wafCommitHash'] = get_semver_from_file(self.version_filename, "0000000", "build")
        settings['uiCommitHash'] = get_semver_from_file(self.ui_version_filename, "0000000", "build")

registrar.register_manager(SettingsManager())

def get_semver_from_file(filename, default_value, semver_spec):
    """get_semver_from_file will retrieve the semver component from a file"""

    value = default_value
    text_file = open(filename, "r")
    if text_file.mode == "r":
        value = text_file.read().strip()

        # Split everything up to 3rd occurence in the version, and join them back together
        # IE: 1.0.0.20210806T115009.a045ea9-1buster becomes 1.0.0
        if semver_spec == "major.minor.patch":
            value = ".".join(value.split(".", 3)[:3])

        # Split everything up to 4th and 5th occurence in the version, and join them back together
        # IE: 1.0.0.20210806T115009.a045ea9-1buster becomes 20210806T115009.a045ea9-1buster
        if semver_spec == "build":
            value = ".".join(value.split(".", 5)[3:5])

    else:
        print(f"ERROR: failed to open text file: {filename}")

    text_file.close()

    return value