import os
import stat
import sys
import subprocess
import datetime
import traceback
from sync import registrar

# This class is responsible for writing FIXME
# based on the settings object passed from sync-settings
class FirewallManager:
    def initialize( self ):
        pass

    def create_settings( self, settings, prefix, delete_list, filename, verbosity=0 ):
        print("%s: Initializing settings" % self.__class__.__name__)
        settings['firewall'] = {}
        settings['firewall']['variables'] = [
            {"key": "HTTP_PORT", "value": "80"},
            {"key": "HTTPS_PORT", "value": "443"}
        ]
        settings['firewall']['tables'] = {}
        
    def sync_settings( self, settings, prefix, delete_list, verbosity=0 ):
        pass
        
registrar.register_manager(FirewallManager())
