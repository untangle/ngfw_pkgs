"""Manager helper functions"""
# pylint: disable=bare-except
import traceback
import os
from collections import OrderedDict
from . import registrar


def managers_init():
    """
    Call init() on all managers
    """
    for manager in registrar.managers:
        try:
            manager.initialize()
        except:
            traceback.print_exc()
            return 1
    return 0


def sanitize_settings(settings):
    """
    Run the modules sanitizeor on the settings
    If the settings change, save them
    """
    for manager in registrar.managers:
        manager.sanitize_settings(settings)

def validate_settings(settings):
    """
    Validate the settings
    """
    validate_schema(settings)
    for manager in registrar.managers:
        manager.validate_settings(settings)

def sync_to_tmpdirs(settings, tmpdir, tmpdir_delete):
    """
    Call sync_settings() on all managers
    """
    delete_list = []
    for manager in registrar.managers:
        try:
            manager.sync_settings(settings, tmpdir, delete_list)
        except:
            traceback.print_exc()
            return 1

    for filename in delete_list:
        path = tmpdir_delete + filename
        file_dir = os.path.dirname(path)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)
        file = open(path, "w+")
        file.write("\n\n")
        file.flush()
        file.close()

    return 0


def create_settings_in_tmpdir(settings_filename, tmpdir, tmpdir_delete):
    """
    Call create_settings() on all managers
    """
    new_settings = {}
    delete_list = []

    for manager in registrar.managers:
        try:
            manager.create_settings(new_settings, tmpdir, delete_list, settings_filename)
        except:
            traceback.print_exc()
            return 1

    for filename in delete_list:
        path = tmpdir_delete + filename
        file_dir = os.path.dirname(path)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)
        file = open(path, "w+")
        file.write("\n\n")
        file.flush()
        file.close()

    return 0

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
    # print("Starting schema scan on: %s" % itemParents)
    bad_attributes = ['output', 'results', 'error']

    if isinstance(currentItem, OrderedDict):
        iterator = currentItem.items()
    elif isinstance(currentItem, list):
        iterator = enumerate(currentItem) 
    else:
        # print("Attribute: %s is non iterable" % currentItem)
        return

    for k, v in iterator:
        # print("Schema Validation: Verifying: %s type: %s" % (k, type(v)))

        if k in bad_attributes:
            dataLocation = str('/'.join(itemParents)) + '/' +  k
            print("Bad JSON data found: %s " % dataLocation)
            bad_attr_locations.append(dataLocation)

        if isinstance(v, OrderedDict) or isinstance(v, list):
            itemParents.append(str(k))
            schema_recurse(v, bad_attr_locations, itemParents)
            del itemParents[-1]
