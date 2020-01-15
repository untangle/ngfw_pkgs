"""Manager helper functions"""
# pylint: disable=bare-except
import traceback
import os

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


def sanitize_settings(settings_file):
    """
    Run the modules sanitizeor on the settings
    If the settings change, save them
    """
    for manager in registrar.managers:
        if registrar.check_registrar_settings_file(settings_file.id, manager):
            manager.sanitize_settings(settings_file)

def validate_settings(settings_file):
    """
    Validate the settings
    """
    for manager in registrar.managers:
        if registrar.check_registrar_settings_file(settings_file.id, manager):
            manager.validate_settings(settings_file)

def sync_to_tmpdirs(settings_file, tmpdir, tmpdir_delete):
    """
    Call sync_settings() on all managers
    """
    delete_list = []
    for manager in registrar.managers:
        if registrar.check_registrar_settings_file(settings_file.id, manager):
            try:
                manager.sync_settings(settings_file, tmpdir, delete_list)
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


def create_settings_in_tmpdir(settings_file, tmpdir, tmpdir_delete):
    """
    Call create_settings() on all managers
    """
    new_settings = {}
    delete_list = []

    for manager in registrar.managers:
        if registrar.check_registrar_settings_file(settings_file.id, manager):
            try:
                # manager.create_settings(new_settings, tmpdir, delete_list, settings_file.file_name)
                manager.create_settings(new_settings, tmpdir, delete_list, settings_file)
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
