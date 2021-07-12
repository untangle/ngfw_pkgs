"""settings management"""
# pylint: disable=broad-except
# pylint: disable=bare-except
import collections
import json
import os.path
import re
import traceback

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
            elif SettingsFile.os_name == 'openwrt' or SettingsFile.os_name == 'alpine':
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

    def is_setting_match(self, setting, compare):
        """
        If current setting matches compare, return True, otherwise False.

        NOTE: For compare as an object, a match is considered whatever matches fields defined in the compare.
        For example, a search of { description: "what I want" } will match that object even if the settings
        target contains more fields that aren't in the compare like { description: "what I want", some_boolean: True }

        setting     --- Current setting value.
        compare     --- Compare to match.
        """
        match = False

        setting_type = type(setting)
        compare_type = type(compare)
        if setting_type is collections.OrderedDict and compare_type is collections.OrderedDict:
            # Dictionary match.
            for compare_key in compare:
                if not compare_key in setting:
                    # Compare key not in setting object.
                    return False

                compare_value = compare[compare_key]
                compare_value_type = type(compare_value)
                setting_value = setting[compare_key]
                if compare_value_type != type(setting_value):
                    # Values are not same type.
                    if type(setting_value) is list:
                        # Special case: If setting is a list and we're not, see
                        # if our compare is inside it.
                        # This is to fix the case of port_protocol which is usually
                        # written as a string from us, but made into a list from the UI.
                        if str(compare_value) in list(map(str,setting_value)):
                            return True
                    return False

                if compare_value_type is collections.OrderedDict:
                    # Walk dictionary.
                    if self.is_setting_match(setting_value, compare_value) is False:
                        return False

                    # Dictionary match
                    match = True
                elif compare_value_type is list:
                    # Walk list
                    if len(compare_value) != len(setting_value):
                        # List not same length
                        return False

                    if self.is_setting_match(setting_value, compare_value) is False:
                        # No match.
                        return False

                    # List match
                    match = True
                elif compare_value_type is str:
                    # Try regex first
                    match = re.match(compare_value, setting_value)
                    if match == None:
                        if compare_value in setting_value:
                            # Tru substring match.
                            match = True
                        else:
                            return False
                else:
                    if compare_value == setting_value:
                        # Any other match.
                        match = True
                    else:
                        return False
        elif setting_type is list and compare_type is list:
            # Walk compare list and compare with corresponding setting index.
            for index, compare_item in enumerate(compare):
                if self.is_setting_match(setting[index], compare_item) is False:
                    # No match to this element.
                    return False

                # List elements match.
                match = True

        return match

    def get_settings_by_path(self, path=None, current_settings=None):
        """
        Recursively look for settings and return the target value.

        If not found, None is returned.

        Keyword arguments:
        path             -- path to search for (default None)
                            Example: firewall/tables/access/chains/name:access-rules/rules
        current_settings -- Current settings node (default None)
        """
        if current_settings is None:
            # Start with root of settings.
            current_settings = self.settings

        # Process search path
        if type(path) == list:
            paths = path
        else:
            # Break into array.
            paths = path.split('/')

        if len(paths) > 0:
            # Walk current settings via path.
            path_find = paths[0]
            paths = paths[1:]

            if type(current_settings) is collections.OrderedDict:
                if path_find in current_settings:
                    return self.get_settings_by_path(paths, current_settings.get(path_find))
                else:
                    return None
            elif type(current_settings) is list:
                for setting in current_settings:
                    if type(setting) is collections.OrderedDict:
                        path_compare = collections.OrderedDict()
                        for path in path_find.split(','):
                            path_set = path.split('=')
                            path_compare[path_set[0]] = path_set[1]

                        if self.is_setting_match(setting, path_compare):
                            return self.get_settings_by_path(paths, setting)
                        else:
                            return None

        # Reached the end of path.  Return the path settings.
        return current_settings

    def find_settings_list(self, path=None, compare=None):
        """
        From a path, search a list for matching dict settings and return matches.

        NOTE: For compare as an object, a match is considered whatever matches fields defined in the compare.
        For example, a search of { description: "what I want" } will match that object even if the settings
        target contains more fields that aren't in the compare like { description: "what I want", some_boolean: True }

        Keyword arguments:
        path             -- String path to search for (default None)
                            Example: firewall/tables/access/chains/name:access-rules/rules
                            If not a string, assume to be a collectons.OrderedDict of the current settings node.
        compare          -- Dict object to match. (defailt None)
                            Example: { "action": { "type": "ACCEPT" } }
        current_settings -- Current settings node (default None)
        """
        result = []
        if compare is None:
            return result

        if compare is not None:
            if type(compare) == dict:
                ## Convert to OrderedDict for 1:1 type comparisions to settings
                compare = json.loads(
                    json.dumps(compare),
                    object_pairs_hook=collections.OrderedDict)

        if type(path) == str:
            current_settings = self.get_settings_by_path(path)
        else:
            current_settings = path

        # Look for matching compares from this settings node.
        if type(current_settings) == list:
            for setting in current_settings:
                if self.is_setting_match(setting, compare):
                    result.append(setting)

        return result
