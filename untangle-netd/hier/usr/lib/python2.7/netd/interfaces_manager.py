import os
import sys
import subprocess
import datetime
import traceback

# This class is responsible for writing /etc/network/interfaces
# based on the settings object passed from sync-settings.py
class InterfacesManager:
    defaultFilename = "/etc/network/interfaces"
    interfacesFilename = defaultFilename
    interfacesFile = None

    def write_interface_v4( self, interface_settings, interfaces ):

        self.interfacesFile.write("## Interface %i (%s) IPv4\n" % (interface_settings['interfaceId'], interface_settings['name']) )
        self.interfacesFile.write("auto %s\n" % interface_settings['symbolicDev'])

        isV4Auto = False
        isV4PPPoE = False
        if interface_settings['v4ConfigType'] == 'auto':
            isV4Auto = True
        if interface_settings['v4ConfigType'] == 'pppoe':
            isV4PPPoE = True

        configString = "manual"
        if isV4Auto:
            configString = "dhcp"
        if isV4PPPoE:
            configString = "ppp"

        # find interfaces bridged to this interface
        isBridge = False
        bridgedInterfaces = []
        for intf in interfaces:
            if intf['config'] == 'bridged' and intf['bridgedTo'] == interface_settings['interfaceId']:
                bridgedInterfaces.append(str(intf['systemDev']))
        if len(bridgedInterfaces) > 0:
            isBridge = True
            bridgedInterfaces.append(interface_settings['systemDev']) # include yourself in bridge

        self.interfacesFile.write("iface %s inet %s\n" % (interface_settings['symbolicDev'], configString) )
        self.interfacesFile.write("\tnetd_interface_index %i\n" % interface_settings['interfaceId'])
        if not isV4Auto:
            self.interfacesFile.write("\tnetd_v4_address %s\n" % interface_settings['v4StaticAddress'])
            self.interfacesFile.write("\tnetd_v4_netmask %s\n" % interface_settings['v4StaticNetmask'])
            self.interfacesFile.write("\tnetd_v4_gateway %s\n" % interface_settings['v4StaticGateway'])
        if isBridge:
            self.interfacesFile.write("\tbridge_ports %s\n" % " ".join(bridgedInterfaces))
            self.interfacesFile.write("\tbridge_ageing %i\n" % 900) #XXX
            self.interfacesFile.write("\tbridge_maxwait %i\n" % 0) #XXX
            self.interfacesFile.write("\tnetd_bridge_mtu %i\n" % 1500) #XXX
        if isV4PPPoE:
            self.interfacesFile.write("\tpre-up /sbin/ifconfig %s up\n" % interface_settings['physicalDev']) 
            self.interfacesFile.write("\tprovider %s\n" % ("connection." + interface_settings['physicalDev'])) 
            
        self.interfacesFile.write("\n\n");

    def write_interface_v6( self, interface_settings, interfaces ):

        if interface_settings['v4ConfigType'] == 'auto':
            return # nothing needed to support RA
        
        self.interfacesFile.write("## Interface %i (%s) IPv6\n" % (interface_settings['interfaceId'], interface_settings['name']) )
        self.interfacesFile.write("auto %s\n" % interface_settings['symbolicDev'])
        self.interfacesFile.write("iface %s inet6 %s\n" % (interface_settings['symbolicDev'], "static") )
        self.interfacesFile.write("\tnetd_interface_index %i\n" % interface_settings['interfaceId'])
        self.interfacesFile.write("\tnetd_v6_address %s\n" % interface_settings['v6StaticAddress'])
        self.interfacesFile.write("\tnetd_v6_netmask %s\n" % interface_settings['v6StaticPrefixLength'])
        self.interfacesFile.write("\tnetd_v6_gateway %s\n" % interface_settings['v6StaticGateway'])
        self.interfacesFile.write("\n\n");

    def check_interface_settings( self, interface_settings):
        if interface_settings['systemDev'] == None:
            print "ERROR: Missisg symbolic dev!"
            return False
        if interface_settings['symbolicDev'] == None:
            print "ERROR: Missisg symbolic dev!"
            return False
        if interface_settings['interfaceId'] == None:
            print "ERROR: Missisg interface ID!"
            return False
        if interface_settings['name'] == None:
            print "ERROR: Missisg interface name!"
            return False
        return True

    def sync_settings( self, settings, prefix="", verbosity=0 ):
        
        self.interfacesFilename = prefix + self.defaultFilename
        self.interfacesDir = os.path.dirname( self.interfacesFilename )
        if not os.path.exists( self.interfacesDir ):
            os.makedirs( self.interfacesDir )

        self.interfacesFile = open( self.interfacesFilename, "w+" )
        self.interfacesFile.write("## Auto Generated on %s\n" % datetime.datetime.now());
        self.interfacesFile.write("## DO NOT EDIT. Changes will be overwritten\n");
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

        if settings != None and settings['interfaces'] != None and settings['interfaces']['list'] != None:
            for interface_settings in settings['interfaces']['list']:
                # only write 'addressed' interfaces
                if interface_settings['config'] != 'addressed':
                    continue
                # if invalid settigs, skip it
                if not self.check_interface_settings( interface_settings ):
                    continue

                try:
                    self.write_interface_v4( interface_settings, settings['interfaces']['list'] )
                except Exception,exc:
                    traceback.print_exc()

                try:
                    self.write_interface_v6( interface_settings, settings['interfaces']['list'] )
                except Exception,exc:
                    traceback.print_exc()

        self.interfacesFile.write("## This is a fake interface that launches the post-networking-restart\n");
        self.interfacesFile.write("## hooks using the if-up.d scripts when IFACE=networking_post_restart_hook\n");
        self.interfacesFile.write("auto networking_post_restart_hook\n");
        self.interfacesFile.write("iface networking_post_restart_hook inet manual\n");
        self.interfacesFile.write("\n\n");
        
        self.interfacesFile.flush()
        self.interfacesFile.close()

        if verbosity > 1:
            print "Writing %s" % interfacesFilename

        

        
