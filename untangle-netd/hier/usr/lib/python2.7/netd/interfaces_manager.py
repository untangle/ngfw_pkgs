import os
import sys
import subprocess
import datetime

# This class is responsible for writing /etc/network/interfaces
# based on the settings object passed from sync-settings.py
class InterfacesManager:
    defaultFilename = "/etc/network/interfaces"
    interfacesFilename = defaultFilename
    interfacesFile = None

    def write_interface( self, interface_settings ):
        if interface_settings['symbolicDev'] == None:
            print "ERROR: Missisg symbolic dev!"
            return
        if interface_settings['interfaceId'] == None:
            print "ERROR: Missisg interface ID!"
            return
        if interface_settings['name'] == None:
            print "ERROR: Missisg interface name!"
            return

        self.interfacesFile.write("## Interface %i (%s)\n" % (interface_settings['interfaceId'], interface_settings['name']) )
        self.interfacesFile.write("# auto %s\n" % interface_settings['symbolicDev'])
        self.interfacesFile.write("\n\n");
        # XXX FIXME 

    def sync_settings( self, settings, prefix="", verbosity=0 ):
        
        self.interfacesFilename = prefix + self.defaultFilename
        self.interfacesDir = os.path.dirname( self.interfacesFilename )
        if not os.path.exists( self.interfacesDir ):
            os.makedirs( self.interfacesDir )

        self.interfacesFile = open( self.interfacesFilename, "w+" )
        self.interfacesFile.write("## Auto Generated on %s\n" % datetime.datetime.now());
        self.interfacesFile.write("## DO NOT EDIT. Changes will be overwritten\n");
        self.interfacesFile.write("\n\n");

        self.interfacesFile.write("## XXX what is this? why? add comment here\n");
        self.interfacesFile.write("auto cleanup\n");
        self.interfacesFile.write("iface cleanup inet manual\n");
        self.interfacesFile.write("\n\n");

        if settings != None and settings['interfaces'] != None and settings['interfaces']['list'] != None:
            for interface_settings in settings['interfaces']['list']:
                # only write 'addressed' interfaces
                if interface_settings['config'] != 'addressed':
                    continue
                self.write_interface( interface_settings )

        self.interfacesFile.write("## XXX what is this? why? add comment here\n");
        self.interfacesFile.write("auto update\n");
        self.interfacesFile.write("iface update inet manual\n");
        self.interfacesFile.write("\n\n");
        
        self.interfacesFile.flush()
        self.interfacesFile.close()

        if verbosity > 1:
            print "Writing %s" % interfacesFilename

        

        
