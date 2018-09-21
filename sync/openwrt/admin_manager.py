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

    def create_settings(self, settings, prefix, delete_list, filename, verbosity=0):
        print("%s: Initializing settings" % self.__class__.__name__)
        settings['admin'] = {}
        settings['admin']['credentials'] = [{
            "username": "admin",
            "passwordCleartext": "passwd"
        }]
        pass

    def sync_settings( self, settings, prefix, delete_list, verbosity=0 ):
        # FIXME write /etc/shadow
        pass

registrar.register_manager(AdminManager())
