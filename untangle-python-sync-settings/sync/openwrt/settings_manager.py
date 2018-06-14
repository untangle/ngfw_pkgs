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

    def initialize( self ):
        pass

    def create_settings( self, settings, prefix, delete_list, filepath, verbosity=0 ):
        print("%s: Initializing settings" % self.__class__.__name__)

        settings['version'] = 1

        filename = prefix + filepath
        file_dir = os.path.dirname( filename )
        if not os.path.exists( file_dir ):
            os.makedirs( file_dir )

        json_str = json.dumps(settings, indent=4)

        file = open( filename, "w+" )
        file.write(json_str)
        file.write("\n")
        file.flush()
        file.close()
        
        if verbosity > 0:
            print("%s: Wrote %s" % (self.__class__.__name__,filename))
        
    def sync_settings( self, settings, prefix, delete_list, verbosity=0 ):
        pass
        
registrar.register_manager(SettingsManager())
