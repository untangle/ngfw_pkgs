import os
import stat
import sys
import subprocess
import datetime
import traceback
from sync import registrar

# This class is responsible for writing /etc/config/network
# based on the settings object passed from sync-settings.py
class NetworkManager:
    network_filename = "/etc/config/network"

    def initialize( self ):
        registrar.register_file( self.network_filename, "restart-networking", self )

    def create_settings( self, settings, prefix, delete_list, verbosity=0 ):
        network = {}
        network['interfaces'] = []
        settings['network'] = network
        settings['foo'] = 'bar'
        
    def sync_settings( self, settings, prefix, delete_list, verbosity=0 ):
        self.write_network_file( settings, prefix, verbosity )
        
    def write_network_file( self, settings, prefix="", verbosity=0 ):
        filename = prefix + self.network_filename
        file_dir = os.path.dirname( filename )
        if not os.path.exists( file_dir ):
            os.makedirs( file_dir )

        self.network_file = open( filename, "w+" )
        self.network_file.write("## Auto Generated\n");
        self.network_file.write("## DO NOT EDIT. Changes will be overwritten.\n");
        self.network_file.write("\n\n");

        self.network_file.flush()
        self.network_file.close()
        
        if verbosity > 0:
            print("NetworkManager: Wrote %s" % filename)

        
registrar.register_manager(NetworkManager())
