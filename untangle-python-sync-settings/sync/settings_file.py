"""settings management"""
# pylint: disable=broad-except
# pylint: disable=bare-except
import collections
import json
import os.path

class SettingsFile:
    """
    This class manages settings files.
    """
    os_name = None

    @classmethod
    def set_os_name(cls, os_name = None):
        """
        Specifies os name for determining identifier.
        """
        cls.os_name = os_name

    def __init__(self, file_name=None):
        """
        Initialize
        """
        self._file_name = file_name
        self._id = None
        self._settings = {}

    @property
    def file_name(self):
        """
        Settings file name.
        """
        return self._file_name

    @property
    def id(self):
        """
        Settings identifier
        """
        if self._id is None:
            path = os.path.abspath(self.file_name).split('/')
            base_name = path.pop().split('.')
            if SettingsFile.os_name == 'debian':
                base_name.pop()
                base_name = '.'.join(base_name)
                id = base_name
                # Debian/ngfw has a special case where settings file is usually
                # "network.js" but if another app is specified, it will be
                # "settings_xx.js" where xx is a number.  In this case, pull
                # the last path as the identifier so "/../intrusion-prevention/settings_82.js"
                # will have an idenfitier of "intrusion-prevention".
                if base_name.startswith('settings_'):
                    id = path.pop()
            elif SettingsFile.os_name == 'openwrt':
                id = base_name[0]
        return id

    @property
    def settings(self):
        """
        Get the current settings of file
        """
        return self._settings

    @settings.setter
    def settings(self, settings):
        """
        Set the settings of the file.
        """
        self._settings = settings

    def read_settings(self):
        """
        Read and parse the settings file
        """
        # global opts
        if self._id is None:
            try:
                settings_file = open(self.file_name, 'r')
                settings_data = settings_file.read()
                settings_file.close()
                self._settings = json.loads(settings_data, object_pairs_hook=collections.OrderedDict)
            except IOError as exc:
                print("Unable to read settings file.", exc)
                traceback.print_exc()
                # cleanup(1)
        return self._settings

    def save_settings(self):
        """
        Save the specified settings to the settings file
        """
        try:
            settings_file = open(self.file_name, 'w')
            json.dump(self.settings, settings_file, indent=4, separators=(',', ': '))
            settings_file.flush()
            settings_file.close()
        except IOError as exc:
            print("Unable to save settings file.", exc)
            traceback.print_exc()
            # cleanup(1)
