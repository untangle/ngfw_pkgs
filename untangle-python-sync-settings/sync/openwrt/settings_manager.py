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
    This class is responsible for writing /etc/config/current.json
    and general settings initialization
    """
    settings_filename = "/etc/config/current.json"

    def initialize(self):
        """initialize this module"""
        registrar.register_settings_file("settings", self)
        registrar.register_file(self.settings_filename, None, self)

    def create_settings(self, settings_file, prefix, delete_list, filepath):
        """creates settings"""
        print("%s: Initializing settings" % self.__class__.__name__)

        settings_file.settings['version'] = 1

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

    def sanitize_settings(self, settings_file):
        # Update settings file version after all other sanitizers have run
        if settings_file.settings['version'] < 3:
            settings_file.settings['version'] = 3

registrar.register_manager(SettingsManager())


def validate_schema(settings):
    """
    Eventually this should validate the schema against mfw_schema, at which point the recursion can probably be removed
    """
    bad_att_locations = []

    schema_recurse(settings, bad_att_locations)

    if len(bad_att_locations) > 0:
        raise Exception("Schema Validation: Bad attributes found. JSON Locations: %s " % bad_att_locations)


def schema_recurse(currentItem, bad_attr_locations, itemParents=['root']):
    """
    This function currently recurses the entire json schema for attribute names of 'output', 'result', or 'error' and raises an exception if found

    """
    bad_attributes = ['output', 'results', 'error']

    if isinstance(currentItem, OrderedDict):
        iterator = currentItem.items()
    elif isinstance(currentItem, list):
        iterator = enumerate(currentItem) 
    else:
        return

    for k, v in iterator:
        if k in bad_attributes:
            dataLocation = str('/'.join(itemParents)) + '/' +  k
            print("Bad JSON data found: %s " % dataLocation)
            bad_attr_locations.append(dataLocation)

        if isinstance(v, OrderedDict) or isinstance(v, list):
            itemParents.append(str(k))
            schema_recurse(v, bad_attr_locations, itemParents)
            del itemParents[-1]
