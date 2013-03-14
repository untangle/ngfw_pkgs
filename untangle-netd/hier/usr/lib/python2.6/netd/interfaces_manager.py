import os
import sys
import subprocess
import datetime
import traceback

# TODO IPv4 aliases
# TODO IPv6 aliases
# TODO change logic that writes PPPoE config file to use connection.systemDev as name instead 

# This class is responsible for writing /etc/network/interfaces
# based on the settings object passed from sync-settings.py
class InterfacesManager:
    defaultFilename = "/etc/network/interfaces"
    interfacesFilename = defaultFilename
    interfacesFile = None

    def write_interface_v4( self, interface_settings, interfaces ):

        devName = interface_settings.get('symbolicDev')
        configString = "manual"
        if interface_settings.get('v4ConfigType') == 'AUTO':
            configString = "dhcp"
        if interface_settings.get('v4ConfigType') == 'PPPOE':
            configString = "ppp"
            # we gave it a unique name in 9.4 - is this necessary?
            # devName = "ppp." + interface_settings.get('symbolicDev')

        self.interfacesFile.write("## Interface %s IPv4\n" % (str(interface_settings.get('interfaceId'))) )
        self.interfacesFile.write("auto %s\n" % devName)

        # find interfaces bridged to this interface
        isBridge = False
        bridgedInterfaces = []
        for intf in interfaces:
            if intf.get('configType') == 'BRIDGED' and intf.get('bridgedTo') == interface_settings.get('interfaceId'):
                bridgedInterfaces.append(str(intf.get('systemDev')))
        if len(bridgedInterfaces) > 0:
            isBridge = True
            bridgedInterfaces.append(interface_settings.get('systemDev')) # include yourself in bridge

        self.interfacesFile.write("iface %s inet %s\n" % (devName, configString) )
        self.interfacesFile.write("\tnetd_interface_index %i\n" % interface_settings.get('interfaceId'))

        # handle static stuff
        if interface_settings.get('v4ConfigType') == 'STATIC':
            self.interfacesFile.write("\tnetd_v4_address %s\n" % interface_settings.get('v4StaticAddress'))
            self.interfacesFile.write("\tnetd_v4_netmask %s\n" % interface_settings.get('v4StaticNetmask'))
            if interface_settings.get('v4StaticGateway') != None:
                self.interfacesFile.write("\tnetd_v4_gateway %s\n" % interface_settings.get('v4StaticGateway'))

        # handle bridge-related stuff
        if isBridge:
            self.interfacesFile.write("\tbridge_ports %s\n" % " ".join(bridgedInterfaces))
            self.interfacesFile.write("\tbridge_ageing %i\n" % 900) #XXX
            self.interfacesFile.write("\tbridge_maxwait %i\n" % 0) #XXX
            self.interfacesFile.write("\tnetd_bridge_mtu %i\n" % 1500) #XXX

        # handle PPPoE stuff
        if interface_settings.get('v4ConfigType') == 'PPPOE':
            self.interfacesFile.write("\tpre-up /sbin/ifconfig %s up\n" % interface_settings.get('physicalDev')) 
            self.interfacesFile.write("\tprovider %s\n" % ("connection.intf" + str(interface_settings.get('interfaceId')))) 
            

        # handle aliases
        if interface_settings.get('v4Aliases') != None and interface_settings.get('v4Aliases').get('list') != None:
            count = 1
            for alias in interface_settings.get('v4Aliases').get('list'):
                self.interfacesFile.write("\n");
                self.interfacesFile.write("## Interface %s IPv4 alias\n" % (str(interface_settings.get('interfaceId'))) )
                self.interfacesFile.write("auto %s:%i\n" % (interface_settings.get('symbolicDev'), count))
                self.interfacesFile.write("iface %s:%i inet manual\n" % ( interface_settings.get('symbolicDev'), count ))
                self.interfacesFile.write("\tnetd_v4_address %s\n" % alias.get('v4StaticAddress'))
                self.interfacesFile.write("\tnetd_v4_netmask %s\n" % alias.get('v4StaticNetmask'))
                count = count+1
                
        
        self.interfacesFile.write("\n\n");

    def write_interface_v6( self, interface_settings, interfaces ):

        if interface_settings.get('v6ConfigType') == 'AUTO':
            return # nothing needed to support RA # FIXME what about non-WANs?

        self.interfacesFile.write("## Interface %i IPv6\n" % (interface_settings.get('interfaceId')) )
        if interface_settings.get('v6StaticAddress') == None:
            self.interfacesFile.write("## No IPv6 configured. \n")
            self.interfacesFile.write("\n\n");
            return

        #self.interfacesFile.write("auto %s\n" % interface_settings.get('symbolicDev'))
        self.interfacesFile.write("iface %s inet6 %s\n" % (interface_settings.get('symbolicDev'), "manual") )
        self.interfacesFile.write("\tnetd_interface_index %i\n" % interface_settings.get('interfaceId'))
        self.interfacesFile.write("\tnetd_v6_address %s\n" % interface_settings.get('v6StaticAddress'))
        self.interfacesFile.write("\tnetd_v6_netmask %s\n" % interface_settings.get('v6StaticPrefixLength'))
        if interface_settings.get('v6StaticGateway') != None:
            self.interfacesFile.write("\tnetd_v6_gateway %s\n" % interface_settings.get('v6StaticGateway'))
        self.interfacesFile.write("\n\n");

    def check_interface_settings( self, interface_settings):
        if interface_settings.get('systemDev') == None:
            print "ERROR: Missisg symbolic dev!"
            return False
        if interface_settings.get('symbolicDev') == None:
            print "ERROR: Missisg symbolic dev!"
            return False
        if interface_settings.get('interfaceId') == None:
            print "ERROR: Missisg interface ID!"
            return False
        if interface_settings.get('name') == None:
            print "ERROR: Missisg interface name!"
            return False
        return True

    def sync_settings( self, settings, prefix="", verbosity=0 ):
        if verbosity > 1: print "InterfacesManager: sync_settings()"
        
        self.interfacesFilename = prefix + self.defaultFilename
        self.interfacesDir = os.path.dirname( self.interfacesFilename )
        if not os.path.exists( self.interfacesDir ):
            os.makedirs( self.interfacesDir )

        self.interfacesFile = open( self.interfacesFilename, "w+" )
        self.interfacesFile.write("## Auto Generated on %s\n" % datetime.datetime.now());
        self.interfacesFile.write("## DO NOT EDIT. Changes will be overwritten.\n");
        self.interfacesFile.write("\n\n");

        # should this be before or after networking_pre_restart_hook?
        # I think before in case anything in the before script needs loopback
        self.interfacesFile.write("auto lo\n");
        self.interfacesFile.write("iface lo inet loopback\n");
        self.interfacesFile.write("\n\n");

        self.interfacesFile.write("## This is a fake interface that launches the pre-networking-restart\n");
        self.interfacesFile.write("## hooks using the if-up.d scripts when IFACE=networking_pre_restart_hook\n");
        self.interfacesFile.write("auto networking_pre_restart_hook\n");
        self.interfacesFile.write("iface networking_pre_restart_hook inet manual\n");
        self.interfacesFile.write("\n\n");

        if settings != None and settings.get('interfaces') != None and settings.get('interfaces').get('list') != None:
            for interface_settings in settings.get('interfaces').get('list'):
                # only write 'ADDRESSED' interfaces
                if interface_settings.get('configType') != 'ADDRESSED':
                    continue
                # if invalid settigs, skip it
                if not self.check_interface_settings( interface_settings ):
                    continue

                try:
                    self.write_interface_v4( interface_settings, settings.get('interfaces').get('list') )
                except Exception,exc:
                    traceback.print_exc()

                try:
                    self.write_interface_v6( interface_settings, settings.get('interfaces').get('list') )
                except Exception,exc:
                    traceback.print_exc()

        self.interfacesFile.write("## This is a fake interface that launches the post-networking-restart\n");
        self.interfacesFile.write("## hooks using the if-up.d scripts when IFACE=networking_post_restart_hook\n");
        self.interfacesFile.write("auto networking_post_restart_hook\n");
        self.interfacesFile.write("iface networking_post_restart_hook inet manual\n");
        self.interfacesFile.write("\n\n");
        
        self.interfacesFile.flush()
        self.interfacesFile.close()

        if verbosity > 0:
            print "InterfacesManager: Wrote %s" % self.interfacesFilename

        

        
