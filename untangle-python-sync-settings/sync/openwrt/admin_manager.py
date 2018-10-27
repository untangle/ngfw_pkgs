import os
import stat
import sys
import subprocess
import datetime
import traceback
from sync import registrar
from sync import nftables_util

# This class is responsible for managing the "admin" (credentials) settings


class AdminManager:
    def initialize(self):
        pass

    def sanitize_settings(self, settings):
        pass

    def validate_settings(self, settings):
        pass

    def create_settings(self, settings, prefix, delete_list, filename):
        print("%s: Initializing settings" % self.__class__.__name__)
        settings['admin'] = {}
        settings['admin']['credentials'] = [{
            "username": "admin",
            "passwordCleartext": "passwd"
        }]
        pass

    def sync_settings(self, settings, prefix, delete_list):
        # FIXME write /etc/shadow
        pass


registrar.register_manager(AdminManager())
