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
        except Exception as e:
            traceback.print_exc()
            print("Abort. (errors)")
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
        except Exception as e:
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
        except Exception as e:
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
