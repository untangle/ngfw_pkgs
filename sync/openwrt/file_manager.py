"""network_manager manages the files specified in 'files' in settings"""
# pylint: disable=unused-argument
# pylint: disable=no-self-use
# pylint: disable=too-many-statements
# pylint: disable=bare-except
# pylint: disable=too-many-branches
import os
import base64
import re
from sync import registrar

class FileManager:
    """
    This class is responsible for writing all the files specified manually in the "files" section of settings
    """

    def initialize(self):
        """initialize this module"""
        pass

    def sanitize_settings(self, settings):
        """sanitizes removes blank settings"""
        pass

    def validate_settings(self, settings):
        """validates settings"""
        files = settings.get("files")
        if files is None:
            return
        for file_json in files:
            if file_json.get("path") is None:
                raise Exception("Invalid file missing path")
            if file_json.get("encoding") is None:
                raise Exception("Invalid file missing encoding: " + file_json.get("path"))
            if file_json.get("contents") is None:
                raise Exception("Invalid file missing contents: " + file_json.get("path"))
            if file_json.get("encoding") not in ["base64"]:
                raise Exception("Unsupported encoding in file: " + file_json.get("path") + " " + file_json.get("encoding"))
            if not re.match("[-_A-Za-z0-9/]+", file_json["path"]):
                raise Exception("Invalid filename: " + file_json.get("path"))
            registrar.register_file(file_json.get("path"), file_json.get("operation"), self)

    def create_settings(self, settings, prefix, delete_list, filename):
        """creates settings"""
        print("%s: Initializing settings" % self.__class__.__name__)
        settings['files'] = []

    def sync_settings(self, settings, prefix, delete_list):
        """syncs settings"""
        files = settings.get("files")
        if files is None:
            return
        for file_json in files:
            self.write_file(file_json, prefix)

    def write_file(self, file_json, prefix):
        """write the specified file"""
        filename = prefix + file_json.get('path')
        file_dir = os.path.dirname(filename)
        if not os.path.exists(file_dir):
            os.makedirs(file_dir)

        file = open(filename, "wb+")
        # only base64 is currently supported
        if file_json.get('encoding') == 'base64':
            file.write(base64.b64decode(file_json.get('contents')))
            file.flush()
            file.close()
            print("%s: Wrote %s" % (self.__class__.__name__, filename))

registrar.register_manager(FileManager())
