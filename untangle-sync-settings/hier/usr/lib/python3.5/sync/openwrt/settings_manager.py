import os
import json
import stat
import sys
import subprocess
import datetime
import traceback
from sync import registrar

# This class is responsible for writing /etc/config/network
# based on the settings object passed from sync-settings.py
class SettingsManager:
    settings_file = "/etc/config/settings.json"

    def initialize( self ):
        pass

    def create_settings( self, settings, prefix, delete_list, verbosity=0 ):
        print("%s: Initializing settings" % self.__class__.__name__)
        filename = prefix + self.settings_file
        file_dir = os.path.dirname( filename )
        if not os.path.exists( file_dir ):
            os.makedirs( file_dir )

        json_str = json.dumps(settings, indent=4)

        self.settings_file = open( filename, "w+" )
        self.settings_file.write(json_str)
        self.settings_file.write("\n")
        self.settings_file.flush()
        self.settings_file.close()
        
        if verbosity > 0:
            print("%s: Wrote %s" % (self.__class__.__name__,filename))
        
    def sync_settings( self, settings, prefix, delete_list, verbosity=0 ):
        pass
        
registrar.register_manager(SettingsManager())
