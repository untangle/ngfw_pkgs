import os
import stat
import sys
import subprocess
import datetime
import traceback
from sync import registrar

# This class is responsible for writing /etc/network/interfaces
# based on the settings object passed from sync-settings.py
class InterfacesManager:
    interfaces_filename = "/etc/network/interfaces"
    interfaces_marks_filename = "/etc/untangle/iptables-rules.d/100-interface-marks"
    pre_network_hook_filename = "/etc/untangle/pre-network-hook.d/045-interfaces"
    src_interface_mark_mask = 0x00ff
    dst_interface_mark_mask = 0xff00
    lxc_interface_mark_mask = 0x04000000
    both_interfaces_mark_mask = 0xffff
    interfaces_file = None

    def sync_settings( self, settings, prefix, delete_list, verbosity=0 ):
        self.write_interfaces_file( settings, prefix, verbosity )
        self.write_interface_marks( settings, prefix, verbosity )
        self.write_pre_network_hook( settings, prefix, verbosity )

        # 14.0 delete obsolete file (can be removed in 14.1)
        delete_list.append("/etc/network/if-up.d/netd")
        
    def initialize( self ):
        registrar.register_file( self.interfaces_filename, "restart-networking", self )
        registrar.register_file( self.interfaces_marks_filename, "restart-iptables", self )
        registrar.register_file( self.pre_network_hook_filename, "restart-networking", self )
        
    def write_interface_v4( self, interface_settings, interfaces, settings ):

        # find interfaces bridged to this interface
        isBridge = False
        bridgedInterfacesStr = []
        bridgedInterfaces = []
        for intf in interfaces:
            if intf.get('configType') == 'BRIDGED' and intf.get('bridgedTo') == interface_settings.get('interfaceId'):
                bridgedInterfacesStr.append(str(intf.get('systemDev')))
                bridgedInterfaces.append(intf)
        if len(bridgedInterfaces) > 0:
            isBridge = True
            bridgedInterfacesStr.append(interface_settings.get('systemDev')) # include yourself in bridge
            bridgedInterfaces.append(interface_settings) # include yourself in bridge
        # We want to add the physical devices to the bridge first (see issue NGFW-10101)
        # And easy way to do this is to just sort by length
        bridgedInterfacesStr.sort(key=lambda x: len(x))

        # If this is a bridge interface, write the blank config for the systemDev
        if isBridge:
            for intf in bridgedInterfaces:
                self.write_interface_blank( intf, interfaces )
        
        devName = interface_settings.get('symbolicDev')
        configString = "manual"
        if interface_settings.get('v4ConfigType') == 'AUTO':
            configString = "dhcp"
        if interface_settings.get('v4ConfigType') == 'PPPOE':
            configString = "ppp"

        self.interfaces_file.write("## Interface %i IPv4 (%s)\n" % (interface_settings.get('interfaceId'),interface_settings.get('v4ConfigType')) )
        self.interfaces_file.write("auto %s\n" % devName)


        # find the minimum MTU of all devs in bridge (if its a bridge)
        bridgeMinMtu = None
        if isBridge:
            for intf in bridgedInterfaces:
                if intf.get('physicalDev') != None and settings.get('devices') != None and settings.get('devices').get('list') != None:
                    for devSettings in settings.get('devices').get('list'):
                        if devSettings.get('deviceName') != None and devSettings.get('deviceName') == intf.get('physicalDev'):
                            if devSettings.get('mtu') != None:
                                # mtu found
                                if bridgeMinMtu == None:
                                    bridgeMinMtu = int(devSettings.get('mtu'))
                                elif int(devSettings.get('mtu')) < bridgeMinMtu:
                                    bridgeMinMtu = int(devSettings.get('mtu'))

        self.interfaces_file.write("iface %s inet %s\n" % (devName, configString) )
        self.interfaces_file.write("\tuntangle_interface_index %i\n" % interface_settings.get('interfaceId'))

        # load 8021q
        if interface_settings.get('isVlanInterface'):
            self.interfaces_file.write("\tpre-up modprobe -q 8021q\n") 

        # handle static stuff
        if interface_settings.get('v4ConfigType') == 'STATIC':
            self.interfaces_file.write("\tuntangle_v4_address %s\n" % interface_settings.get('v4StaticAddress'))
            self.interfaces_file.write("\tuntangle_v4_netmask %s\n" % interface_settings.get('v4StaticNetmask'))
            if interface_settings.get('v4StaticGateway') != None:
                self.interfaces_file.write("\tuntangle_v4_gateway %s\n" % interface_settings.get('v4StaticGateway'))

        # handle bridge-related stuff
        if isBridge:
            self.interfaces_file.write("\tbridge_ports %s\n" % " ".join(bridgedInterfacesStr))
            self.interfaces_file.write("\tbridge_ageing %i\n" % 900) #XXX
            stpEnabled = (settings.get('stpEnabled') != None and settings.get('stpEnabled'))
            if stpEnabled:
                self.interfaces_file.write("\tbridge_stp on\n") 
                self.interfaces_file.write("\tbridge_maxwait %i\n" % 30)
            else:
                self.interfaces_file.write("\tbridge_stp off\n") 
                # maxwait comments: http://bugs.debian.org/cgi-bin/bugreport.cgi?bug=549696
                # For now I've decide to set this to 20 
                # Its tempting to set this to zero because stp is disbled
                self.interfaces_file.write("\tbridge_maxwait %i\n" % 20)
            if bridgeMinMtu != None:
                self.interfaces_file.write("\tmtu %i\n" % bridgeMinMtu)
            # multicast_snooping causes issues with IMQ/QoS, disable it (bug #11930)
            self.interfaces_file.write("\tpost-up if [ -f /sys/devices/virtual/net/$IFACE/bridge/multicast_snooping ] ; then echo 0 > /sys/devices/virtual/net/$IFACE/bridge/multicast_snooping || true ; fi" + "\n") 

        # handle PPPoE stuff
        if interface_settings.get('v4ConfigType') == 'PPPOE':
            if interface_settings.get('v4PPPoERootDev') != None:
                if interface_settings.get('isVlanInterface'):
                    self.interfaces_file.write("\tpre-up env IF_VLAN_RAW_DEVICE=%s IFACE=%s /etc/network/if-pre-up.d/vlan\n" % (interface_settings.get('physicalDev'),interface_settings.get('v4PPPoERootDev')))
                self.interfaces_file.write("\tpre-up /sbin/ifconfig %s up\n" % interface_settings.get('v4PPPoERootDev'))
                self.interfaces_file.write("\tpost-down /sbin/ifconfig %s down\n" % interface_settings.get('v4PPPoERootDev'))
                if interface_settings.get('isVlanInterface'):
                    self.interfaces_file.write("\tpost-down env IF_VLAN_RAW_DEVICE=%s IFACE=%s /etc/network/if-post-down.d/vlan\n" % (interface_settings.get('physicalDev'),interface_settings.get('v4PPPoERootDev')))
            self.interfaces_file.write("\tprovider %s\n" % ("connection.intf" + str(interface_settings.get('interfaceId')))) 
            # sleep to give PPPoE time to get address (bug #11431)
            self.interfaces_file.write("\tpost-up /usr/share/untangle-sync-settings/bin/pppoe-wait-for-address.sh %s 60\n" % devName ) 

        # write VRRP source routes
        if interface_settings.get('isWan') and interface_settings.get('configType') == 'ADDRESSED' and interface_settings.get('vrrpEnabled'):
            if interface_settings.get('vrrpAliases') != None and interface_settings.get('vrrpAliases').get('list') != None:
                for alias in interface_settings.get('vrrpAliases').get('list'):
                    self.interfaces_file.write("\tpost-up /usr/share/untangle-sync-settings/bin/add-source-route.sh %s \"uplink.%i\" -4\n" % (alias.get('staticAddress'), interface_settings.get('interfaceId'))) 
            
        if interface_settings.get('isWirelessInterface'):
            self.interfaces_file.write("\thostapd /etc/hostapd/hostapd.conf-%s\n" % devName);

        self.interfaces_file.write("\n\n");

    def write_interface_v6( self, interface_settings, interfaces ):

        # If it is static without an address it is disabled
        if interface_settings.get('v6ConfigType') == 'STATIC' and interface_settings.get('v6StaticAddress') == None:
            interface_settings['v6ConfigType'] = 'DISABLED'

        self.interfaces_file.write("## Interface %i IPv6 (%s)\n" % (interface_settings.get('interfaceId'),interface_settings.get('v6ConfigType')) )
        #self.interfaces_file.write("auto %s\n" % interface_settings.get('symbolicDev'))

        self.interfaces_file.write("iface %s inet6 %s\n" % (interface_settings.get('symbolicDev'), "manual") )
        self.interfaces_file.write("\tuntangle_interface_index %i\n" % interface_settings.get('interfaceId'))

        if interface_settings.get('v6ConfigType') == 'STATIC':
            self.interfaces_file.write("\tpre-up echo 0 > /proc/sys/net/ipv6/conf/$IFACE/disable_ipv6" + "\n")
            self.interfaces_file.write("\tpre-up echo 0 > /proc/sys/net/ipv6/conf/$IFACE/autoconf" + "\n")
            if interface_settings.get('v6StaticAddress') != None:
                self.interfaces_file.write("\tuntangle_v6_address %s\n" % interface_settings.get('v6StaticAddress'))
            if interface_settings.get('v6StaticPrefixLength') != None:
                self.interfaces_file.write("\tuntangle_v6_prefix %s\n" % interface_settings.get('v6StaticPrefixLength'))
            if interface_settings.get('isWan'):
                if interface_settings.get('v6StaticGateway') != None:
                    self.interfaces_file.write("\tuntangle_v6_gateway %s\n" % interface_settings.get('v6StaticGateway'))
                    self.interfaces_file.write("\tpre-up echo 0 > /proc/sys/net/ipv6/conf/$IFACE/accept_ra" + "\n")
                else: # no gateway specified, use RAs
                    self.interfaces_file.write("\tpre-up echo 1 > /proc/sys/net/ipv6/conf/$IFACE/accept_ra" + "\n")
        elif interface_settings.get('v6ConfigType') == 'AUTO':
            self.interfaces_file.write("\tpre-up echo 0 > /proc/sys/net/ipv6/conf/$IFACE/disable_ipv6" + "\n")
            self.interfaces_file.write("\tpre-up echo 1 > /proc/sys/net/ipv6/conf/$IFACE/autoconf" + "\n")
            self.interfaces_file.write("\tuntangle_v6_address %s\n" % "auto")
            if interface_settings.get('isWan'):
                self.interfaces_file.write("\tpre-up echo 1 > /proc/sys/net/ipv6/conf/$IFACE/accept_ra" + "\n")
            else:
                self.interfaces_file.write("\tpre-up echo 0 > /proc/sys/net/ipv6/conf/$IFACE/accept_ra" + "\n")
        elif interface_settings.get('v6ConfigType') == 'DISABLED':
            self.interfaces_file.write("\tpre-up echo 1 > /proc/sys/net/ipv6/conf/$IFACE/disable_ipv6" + "\n")

        self.interfaces_file.write("\n\n");

    def write_interface_disabled( self, interface_settings, interfaces ):
        devName = interface_settings.get('symbolicDev')
        self.interfaces_file.write("## Interface %i (DISABLED)\n" % interface_settings.get('interfaceId') )
        self.interfaces_file.write("auto %s\n" % devName)
        self.interfaces_file.write("iface %s inet manual\n" % devName )
        self.interfaces_file.write("\tpre-up echo 1 > /proc/sys/net/ipv6/conf/$IFACE/disable_ipv6" + "\n")
        self.interfaces_file.write("\tpost-up ifconfig %s 0.0.0.0 up\n" % devName )
        self.interfaces_file.write("\n\n");

    def write_interface_blank( self, interface_settings, interfaces ):
        # This is not necessary as the bridge-utils scripts bring up any sub-interfaces automatically
        # in /etc/network/if-**.d/bridge
        # However, we may want to control how and when those interfaces are brought up and down
        # If so, we can specify the config here
        if interface_settings.get('isWirelessInterface'):
            devName = interface_settings.get('systemDev')
            self.interfaces_file.write("## Interface %i (BRIDGE PORT)\n" % interface_settings.get('interfaceId') )
            self.interfaces_file.write("auto %s\n" % devName)
            self.interfaces_file.write("iface %s inet manual\n" % devName )
            self.interfaces_file.write("\tpost-up ifconfig %s 0.0.0.0 up\n" % devName )
            self.interfaces_file.write("\thostapd /etc/hostapd/hostapd.conf-%s\n" % devName);
            self.interfaces_file.write("\n\n");
        
    def write_interface_aliases( self, interface_settings, interfaces ):
        # determine the proper interface to put the aliases "on"
        if interface_settings.get('v4ConfigType') != 'PPPOE':
            intf_str = interface_settings.get('symbolicDev')
        else:
            # If its a PPPoE interface, put the alias on the physical device
            # This is because the ppp interface can go up and down
            intf_str = interface_settings.get('physicalDev')

        # handle v4 aliases
        count = 1
        if interface_settings.get('v4Aliases') != None and interface_settings.get('v4Aliases').get('list') != None:
            for alias in interface_settings.get('v4Aliases').get('list'):
                self.interfaces_file.write("## Interface %i IPv4 alias\n" % (interface_settings.get('interfaceId')) )
                self.interfaces_file.write("auto %s:%i\n" % (intf_str, count))
                self.interfaces_file.write("iface %s:%i inet manual\n" % ( intf_str, count ))
                self.interfaces_file.write("\tuntangle_interface_index %i\n" % interface_settings.get('interfaceId'))
                self.interfaces_file.write("\tuntangle_v4_address %s\n" % alias.get('staticAddress'))
                self.interfaces_file.write("\tuntangle_v4_netmask %s\n" % alias.get('staticNetmask'))
                self.interfaces_file.write("\n");
                count = count+1

        # handle v6 aliases
        if interface_settings.get('v6Aliases') != None and interface_settings.get('v6Aliases').get('list') != None:
            for alias in interface_settings.get('v6Aliases').get('list'):
                self.interfaces_file.write("## Interface %i IPv6 alias\n" % (interface_settings.get('interfaceId')) )
                self.interfaces_file.write("auto %s:%i\n" % (intf_str, count))
                self.interfaces_file.write("iface %s:%i inet manual\n" % ( intf_str, count ))
                self.interfaces_file.write("\tuntangle_interface_index %i\n" % interface_settings.get('interfaceId'))
                self.interfaces_file.write("\tuntangle_v6_address %s\n" % alias.get('staticAddress'))
                self.interfaces_file.write("\tuntangle_v6_netmask %s\n" % alias.get('staticNetmask'))
                self.interfaces_file.write("\n");
                count = count+1

    def check_interface_settings( self, interface_settings):
        if interface_settings.get('systemDev') == None:
            print("ERROR: Missisg symbolic dev!")
            return False
        if interface_settings.get('symbolicDev') == None:
            print("ERROR: Missisg symbolic dev!")
            return False
        if interface_settings.get('interfaceId') == None:
            print("ERROR: Missisg interface ID!")
            return False
        if interface_settings.get('name') == None:
            print("ERROR: Missisg interface name!")
            return False
        return True

    def write_interfaces_file( self, settings, prefix="", verbosity=0 ):
        filename = prefix + self.interfaces_filename
        file_dir = os.path.dirname( filename )
        if not os.path.exists( file_dir ):
            os.makedirs( file_dir )

        self.interfaces_file = open( filename, "w+" )
        self.interfaces_file.write("## Auto Generated\n");
        self.interfaces_file.write("## DO NOT EDIT. Changes will be overwritten.\n");
        self.interfaces_file.write("\n\n");

        self.interfaces_file.write("## This is a fake interface that launches the pre-networking-restart\n");
        self.interfaces_file.write("## hooks using the if-up.d scripts when IFACE=networking_pre_restart_hook\n");
        self.interfaces_file.write("auto networking_pre_restart_hook\n");
        self.interfaces_file.write("iface networking_pre_restart_hook inet manual\n");
        if settings.get('blockDuringRestarts') != None and settings.get('blockDuringRestarts'):
            self.interfaces_file.write("\tpre-up /sbin/iptables -t filter -I FORWARD -m conntrack --ctstate NEW -j DROP -m comment --comment \"drop sessions during restart\"\n");
            self.interfaces_file.write("\tpre-up /sbin/iptables -t filter -I INPUT   -m conntrack --ctstate NEW -j DROP -m comment --comment \"drop sessions during restart\"\n");
        self.interfaces_file.write("\n\n");

        self.interfaces_file.write("auto lo\n");
        self.interfaces_file.write("iface lo inet loopback\n");
        self.interfaces_file.write("\n\n");

        self.interfaces_file.write("source-directory interfaces.d\n");
        self.interfaces_file.write("\n\n");

        # Write disable interfaces first
        if settings != None and settings.get('disabledInterfaces') != None and settings.get('disabledInterfaces').get('list') != None:
            for interface_settings in settings.get('disabledInterfaces').get('list'):

                try:
                    self.write_interface_disabled( interface_settings, settings.get('interfaces').get('list') )
                except Exception as exc:
                    traceback.print_exc()

        # Write addressed interfaces last
        if settings != None and settings.get('interfaces') != None and settings.get('interfaces').get('list') != None:
            for interface_settings in settings.get('interfaces').get('list'):
                # only write 'ADDRESSED' interfaces
                if interface_settings.get('configType') != 'ADDRESSED':
                    continue

                # if invalid settigs, skip it
                if not self.check_interface_settings( interface_settings ):
                    continue

                # Now write the main interface configurations
                try:
                    self.write_interface_v4( interface_settings, settings.get('interfaces').get('list') , settings)
                except Exception as exc:
                    traceback.print_exc()
                try:
                    self.write_interface_v6( interface_settings, settings.get('interfaces').get('list') )
                except Exception as exc:
                    traceback.print_exc()
                try:
                    self.write_interface_aliases( interface_settings, settings.get('interfaces').get('list') )
                except Exception as exc:
                    traceback.print_exc()

        self.interfaces_file.write("## This is a fake interface that launches the post-networking-restart\n");
        self.interfaces_file.write("## hooks using the if-up.d scripts when IFACE=networking_post_restart_hook\n");
        self.interfaces_file.write("auto networking_post_restart_hook\n");
        self.interfaces_file.write("iface networking_post_restart_hook inet manual\n");
        self.interfaces_file.write("\n\n");
        
        self.interfaces_file.flush()
        self.interfaces_file.close()

        if verbosity > 0:
            print("InterfacesManager: Wrote %s" % filename)

    def write_restore_interface_marks( self, file, interfaces, prefix, verbosity ):

        file.write("\n\n");
        file.write("#\n");
        file.write("# Create restore-interface-marks chain"+ "\n");
        file.write("#\n\n");

        file.write("# First zero out any marks on this packet"+ "\n");
        file.write("${IPTABLES} -t mangle -A restore-interface-marks -j MARK --and-mark 0xFFFF0000 -m comment --comment \"Zero out source and destination interface marks\"" + "\n");
        file.write("\n");
        
        file.write("# Ignore and broadcast sessions as they will all share the same conntrack entry so the connmark cant be used for src/dst intf" + "\n");
        file.write("# These packets will still be marked in the mark-src-intf and mark-dst-intf chains later\n");
        file.write("${IPTABLES} -t mangle -A restore-interface-marks -m addrtype --dst-type broadcast  -j RETURN -m comment --comment \"Do not mark broadcast packets\"" + "\n");
        file.write("${IPTABLES} -t mangle -A restore-interface-marks -m addrtype --src-type broadcast  -j RETURN -m comment --comment \"Do not mark broadcast packets\"" + "\n");
        file.write("\n");

        file.write("# This rule says if the packet is in the original direction, just copy the intf marks from the connmark/session mark" + "\n");
        file.write("uname -a | grep -q 2.6.32" + "\n");
        file.write("KERN_2_6_32=$?" + "\n");
        file.write("if [ ${KERN_2_6_32} -eq 0 ] ; then" + "\n");
        file.write("\t# The rule actually says REPLY and not ORIGINAL and thats because ctdir matches backwards in 2.6.32 # http://www.spinics.net/lists/netfilter-devel/msg17864.html" + "\n");
        file.write("\t${IPTABLES} -t mangle -A restore-interface-marks -m conntrack --ctdir REPLY -j CONNMARK --restore-mark --mask 0x%X -m comment --comment \"If packet is in original direction, copy mark from connmark to packet\"" % self.both_interfaces_mark_mask + "\n");
        file.write("\t${IPTABLES} -t mangle -A restore-interface-marks -m conntrack --ctdir REPLY -j RETURN -m comment --comment \"If packet is in original direction we are done, just return\"" + "\n");
        file.write("else" + "\n");
        file.write("\t${IPTABLES} -t mangle -A restore-interface-marks -m conntrack --ctdir ORIGINAL -j CONNMARK --restore-mark --mask 0x%X -m comment --comment \"If packet is in original direction, copy mark from connmark to packet\"" % self.both_interfaces_mark_mask + "\n");
        file.write("\t${IPTABLES} -t mangle -A restore-interface-marks -m conntrack --ctdir ORIGINAL -j RETURN -m comment --comment \"If packet is in original direction we are done, just return\"" + "\n");
        file.write("fi" + "\n");
        file.write("\n");

        file.write("# Since this is a reply packet, copy dst intf from connmark to src intf mark, copy src intf from connmark to dst intf mark." + "\n");
        file.write("# Two rules for each interfaces, one to set src mark, one to set dst mark" + "\n")

        for intf in interfaces:
            id = intf['interfaceId']
            file.write("${IPTABLES} -t mangle -A restore-interface-marks -m connmark --mark 0x%04X/0x%04X -j MARK --set-mark 0x%04X/0x%04X -m comment --comment \"Set dst interface mark from connmark for intf %i\"" % (id, self.src_interface_mark_mask, id << 8, self.dst_interface_mark_mask, id) + "\n");
            file.write("${IPTABLES} -t mangle -A restore-interface-marks -m connmark --mark 0x%04X/0x%04X -j MARK --set-mark 0x%04X/0x%04X -m comment --comment \"Set src interface mark from connmark for intf %i\"" % (id << 8, self.dst_interface_mark_mask, id, self.src_interface_mark_mask, id) + "\n");
        file.write("\n");

    def write_mark_src_intf( self, file, interfaces, prefix, verbosity ):

        file.write("\n\n");
        file.write("#\n");
        file.write("# Create the mark-src-intf chain." + "\n");
        file.write("#\n\n");

        file.write("${IPTABLES} -t mangle -A mark-src-intf -m mark ! --mark 0/0x%04X -j RETURN -m comment --comment \"If its already set, just return\"" % (self.src_interface_mark_mask) + "\n");
        file.write("\n");

        for intf in interfaces:
            id = intf['interfaceId']
            systemDev = intf['systemDev']
            symbolicDev = intf['symbolicDev']
            configType = intf['configType']

            file.write("${IPTABLES} -t mangle -A mark-src-intf -i %s -j MARK --set-mark 0x%04X/0x%04X -m comment --comment \"Set src interface mark for intf %i\"" % (systemDev, id, self.src_interface_mark_mask, id) + "\n");
            # if bridged also add bridge rules
            if symbolicDev.startswith("br.") or configType == 'BRIDGED':
                file.write("${IPTABLES} -t mangle -A mark-src-intf -m physdev --physdev-in %s -j MARK --set-mark 0x%04X/0x%04X -m comment --comment \"Set src interface mark for intf %i using physdev\"" % (systemDev, id, self.src_interface_mark_mask, id) + "\n");

        for intf in interfaces:
            id = intf['interfaceId']
            # Restore the mark from the source MAC address
            # see netcap_virtual_interface.c for more details
            file.write("${IPTABLES} -t mangle -A mark-src-intf -i utun -p tcp -m mac --mac-source 00:00:00:00:00:%02X -j MARK --set-mark 0x00%02X/0x00FF -m comment --comment \"Set reinject packet src interface mark for intf %x\"" % (id, id, id) + "\n");

        # Special rule to mark LXC traffic
        # This is put in a special chain so it can be easily flushed/changed
        file.write("${IPTABLES} -t mangle -A mark-src-intf -i br.lxc -j mark-src-lxc-intf -m comment --comment \"Mark LXC interface\"" + "\n")
        file.write("${IPTABLES} -t mangle -A mark-src-intf -i veth+  -j mark-src-lxc-intf -m comment --comment \"Mark LXC interface\"" + "\n")

       # Save mark to connmark
        file.write("${IPTABLES} -t mangle -A mark-src-intf -m mark ! --mark 0/0x%04X -m conntrack --ctstate NEW -j CONNMARK --save-mark --mask 0x%04X -m comment --comment \"Save src interface mark to connmark\"" % (self.src_interface_mark_mask, self.src_interface_mark_mask) + "\n");

        # IPsec traffic may come from a bridge interface
        # Unfortunately, the incoming interface will be br.ethX but none of the above physdev rules will match above.
        # Do not print a warning to kern.log in this case
        file.write("${IPTABLES} -t mangle -A mark-src-intf -m policy --pol ipsec --dir in -j RETURN -m comment --comment \"Do not warn on IPsec traffic\"" + "\n")
        file.write("${IPTABLES} -t mangle -A mark-src-intf -m policy --pol ipsec --dir in -j RETURN -m comment --comment \"Do not warn on IPsec traffic\"" + "\n")

        # Dont log lo or utun packets
        file.write("${IPTABLES} -t mangle -A mark-src-intf -i lo -j RETURN -m comment --comment \"Do not warn loopback traffic\"" + "\n")
        file.write("${IPTABLES} -t mangle -A mark-src-intf -i utun -j RETURN -m comment --comment \"Do not warn on utun traffic\"" + "\n");

        # Log unknown packets
        file.write("${IPTABLES} -t mangle -A mark-src-intf -m mark --mark 0/0x%04X -j LOG --log-prefix \"WARNING (unknown src intf):\" -m comment --comment \"WARN on missing src mark\"" % (self.src_interface_mark_mask) + "\n");

        file.write("\n");

    def write_mark_src_lxc_intf( self, file, settings, interfaces, prefix, verbosity ):

        file.write("\n\n");
        file.write("#\n");
        file.write("# Create the mark-src-lxc-intf chain." + "\n");
        file.write("#\n\n");

        lxcInterfaceId = self.get_lxc_interface_id( settings )
        if lxcInterfaceId == None:
            return

        # Add a rule so LXC traffic is marked as if it was coming from lxcInterfaceId
        file.write("${IPTABLES} -t mangle -A mark-src-lxc-intf -i br.lxc -j MARK --set-mark 0x%04X/0x%04X -m comment --comment \"Set src interface mark lxc\"" % (lxcInterfaceId, self.src_interface_mark_mask) + "\n")
        file.write("${IPTABLES} -t mangle -A mark-src-lxc-intf -i veth+  -j MARK --set-mark 0x%04X/0x%04X -m comment --comment \"Set src interface mark lxc\"" % (lxcInterfaceId, self.src_interface_mark_mask) + "\n")

        # Give it a special mark
        file.write("${IPTABLES} -t mangle -A mark-src-lxc-intf -i br.lxc -j MARK --set-mark 0x%04X/0x%04X -m comment --comment \"Set lxc mark for lxc\"" % (self.lxc_interface_mark_mask, self.lxc_interface_mark_mask) + "\n")
        file.write("${IPTABLES} -t mangle -A mark-src-lxc-intf -i veth+  -j MARK --set-mark 0x%04X/0x%04X -m comment --comment \"Set lxc mark for lxc\"" % (self.lxc_interface_mark_mask, self.lxc_interface_mark_mask) + "\n")

        file.write("${IPTABLES} -t mangle -A mark-src-lxc-intf -i br.lxc -j CONNMARK --save-mark --mask 0x%04X -m comment --comment \"Save lxc mark to connmark\"" % (self.lxc_interface_mark_mask)+ "\n")
        file.write("${IPTABLES} -t mangle -A mark-src-lxc-intf -i veth+  -j CONNMARK --save-mark --mask 0x%04X -m comment --comment \"Save lxc mark to connmark\"" % (self.lxc_interface_mark_mask)+ "\n")

        file.write("\n");

    def write_mark_dst_intf( self, file, settings, interfaces, prefix, verbosity ):

        file.write("\n\n");
        file.write("#\n");
        file.write("# Create the mark-dst-intf chain." + "\n");
        file.write("#\n\n");

        # We dont bother with already marked packets, except if its the first packet in the session
        # If it is the first packet then WAN-balancer could have picked a WAN but it might be headed elsewhere because of a static route.
        file.write("${IPTABLES} -t mangle -A mark-dst-intf -m mark ! --mark 0/0x%04X -m conntrack ! --ctstate NEW -j RETURN -m comment --comment \"If its already set and an existing session, just return\"" % (self.dst_interface_mark_mask) + "\n");
        file.write("\n");

        # Don't bother with broadcast packets,
        file.write("${IPTABLES} -t mangle -A mark-dst-intf -m addrtype --dst-type broadcast -j RETURN -m comment --comment \"If its a broadcast packet, just return\"" + "\n");
        file.write("\n");

        for intf in interfaces:
            id = intf['interfaceId']
            systemDev = intf['systemDev']
            symbolicDev = intf['symbolicDev']
            configType = intf['configType']

            file.write("${IPTABLES} -t mangle -A mark-dst-intf -o %s -j MARK --set-mark 0x%04X/0x%04X -m comment --comment \"Set dst interface mark for intf %i\"" % (systemDev, id << 8, self.dst_interface_mark_mask, id) + "\n");
            # if bridged also add bridge rules
            if symbolicDev.startswith("br.") or configType == 'BRIDGED':
                file.write("${IPTABLES} -t mangle -A mark-dst-intf -o %s -m physdev --physdev-out %s -j MARK --set-mark 0x%04X/0x%04X -m comment --comment \"Set dst interface mark for intf %i using physdev\"" % (symbolicDev, systemDev, id << 8, self.dst_interface_mark_mask, id) + "\n");

        # This is a terrible hack to work around NGFW-6246
        # physdev-out does not work for bridged interfaces in 4.x, so we have to assume some destination interface so we assume the main interface
        # otherwise the traffic will have no dest interface
        # This may mean we incorrectly mark the dest interface!
        ngfw6246HackRules = {}
        for intf in interfaces:
            id = intf['interfaceId']
            systemDev = intf['systemDev']
            symbolicDev = intf['symbolicDev']
            configType = intf['configType']

            if symbolicDev.startswith("br.") or configType == 'BRIDGED':
                if ngfw6246HackRules.get(symbolicDev) == None:
                    ngfw6246HackRules[symbolicDev] = True
                    file.write("uname -r | grep -q '^4'" + "\n");
                    file.write("KERN_4_X=$?" + "\n");
                    file.write("if [ ${KERN_4_X} -eq 0 ] ; then" + "\n");
                    file.write("    ${IPTABLES} -t mangle -A mark-dst-intf -o %s -m mark --mark 0x0000/0xff00 -j MARK --set-mark 0x%04X/0x%04X -m comment --comment \"Assume dst interface mark for intf %i\"" % (symbolicDev, id << 8, self.dst_interface_mark_mask, id) + "\n");
                    file.write("fi" + "\n");
                    file.write("\n");

        file.write("\n");

        lxcInterfaceId = self.get_lxc_interface_id( settings )
        if lxcInterfaceId != None:
            # Add a rule so LXC traffic is marked as if it was going to from lxcInterfaceId
            file.write("${IPTABLES} -t mangle -A mark-dst-intf -o br.lxc -j MARK --set-mark 0x%04X/0x%04X -m comment --comment \"Set dst interface mark lxc\"" % ((lxcInterfaceId<<8), self.dst_interface_mark_mask) + "\n")
            file.write("${IPTABLES} -t mangle -A mark-dst-intf -o veth+  -j MARK --set-mark 0x%04X/0x%04X -m comment --comment \"Set dst interface mark lxc\"" % ((lxcInterfaceId<<8), self.dst_interface_mark_mask) + "\n")
            file.write("\n");
        
    def write_save_dst_intf_mark( self, file, interfaces, prefix, verbosity ):

        file.write("\n\n");
        file.write("#\n");
        file.write("# Create the save-mark-dst-intf chain." + "\n");
        file.write("#\n\n");

        # file.write("${IPTABLES} -t filter -A save-mark-dst-intf -m mark --mark 0/0x%04X -j LOG --log-prefix \"WARNING (unknown dst intf):\" -m comment --comment \"WARN on missing dst mark\"" % (self.dst_interface_mark_mask) + "\n");
        file.write("${IPTABLES} -t filter -A save-mark-dst-intf -m conntrack --ctstate NEW -j CONNMARK --save-mark --mask 0x%04X -m comment --comment \"Save dst interface mark to connmark\"" % (self.dst_interface_mark_mask) + "\n");
                
        file.write("\n");


    def write_interface_marks( self, settings, prefix, verbosity ):
        interfaces = settings['interfaces']['list']

        filename = prefix + self.interfaces_marks_filename
        file_dir = os.path.dirname( filename )
        if not os.path.exists( file_dir ):
            os.makedirs( file_dir )

        file = open( filename, "w+" )
        file.write("## Auto Generated\n");
        file.write("## DO NOT EDIT. Changes will be overwritten.\n");
        file.write("\n\n");

        file.write("# Create (if needed) and flush restore-interface-marks, mark-src-intf, mark-dst-intf chains" + "\n");
        file.write("${IPTABLES} -t mangle -N restore-interface-marks 2>/dev/null" + "\n");
        file.write("${IPTABLES} -t mangle -F restore-interface-marks >/dev/null 2>&1" + "\n");
        file.write("${IPTABLES} -t mangle -N mark-src-intf 2>/dev/null" + "\n");
        file.write("${IPTABLES} -t mangle -F mark-src-intf >/dev/null 2>&1" + "\n");
        file.write("${IPTABLES} -t mangle -N mark-dst-intf 2>/dev/null" + "\n");
        file.write("${IPTABLES} -t mangle -F mark-dst-intf >/dev/null 2>&1" + "\n");
        file.write("${IPTABLES} -t filter -N save-mark-dst-intf 2>/dev/null" + "\n");
        file.write("${IPTABLES} -t filter -F save-mark-dst-intf >/dev/null 2>&1" + "\n");
        file.write("${IPTABLES} -t mangle -N mark-src-lxc-intf 2>/dev/null" + "\n");
        file.write("${IPTABLES} -t mangle -F mark-src-lxc-intf 2>/dev/null" + "\n");
        file.write("\n");
        
        file.write("# Call restore-interface-marks then mark-src-intf from PREROUTING chain in mangle" + "\n");
        file.write("${IPTABLES} -t mangle -D prerouting-set-marks -m comment --comment \"Restore interface marks (0xffff) from connmark\" -j restore-interface-marks >/dev/null 2>&1" + "\n");
        file.write("${IPTABLES} -t mangle -D prerouting-set-marks -m comment --comment \"Set src intf mark (0x00ff)\" -j mark-src-intf >/dev/null 2>&1" + "\n");
        file.write("${IPTABLES} -t mangle -A prerouting-set-marks -m comment --comment \"Restore interface marks (0xffff) from connmark\" -j restore-interface-marks" + "\n");
        file.write("${IPTABLES} -t mangle -A prerouting-set-marks -m comment --comment \"Set src intf mark (0x00ff)\" -j mark-src-intf" + "\n");
        file.write("\n");

        file.write("# Call mark-dst-intf from FORWARD chain in mangle" + "\n");
        file.write("${IPTABLES} -t mangle -D forward-set-marks -m comment --comment \"Set dst intf mark (0xff00)\" -j mark-dst-intf >/dev/null 2>&1" + "\n");
        file.write("${IPTABLES} -t mangle -A forward-set-marks -m comment --comment \"Set dst intf mark (0xff00)\" -j mark-dst-intf" + "\n");
        file.write("\n");

        file.write("# Call save-mark-dst-intf from FORWARD chain in filter" + "\n");
        file.write("# Do not think this is necessary - local traffic is always bypassed" + "\n");
        file.write("${IPTABLES} -t filter -D FORWARD -m comment --comment \"Save dst intf mark (0xff00)\" -j save-mark-dst-intf >/dev/null 2>&1" + "\n");
        file.write("${IPTABLES} -t filter -A FORWARD -m comment --comment \"Save dst intf mark (0xff00)\" -j save-mark-dst-intf" + "\n");
        file.write("\n");

        file.write("# Call mark-dst-intf from OUTPUT chain in mangle for local traffic" + "\n");
        file.write("# Do not think this is necessary - local traffic is always bypassed" + "\n");
        file.write("# ${IPTABLES} -t mangle -D output-set-marks -m comment --comment \"Set dst intf mark (0xff00)\" -j mark-dst-intf >/dev/null 2>&1" + "\n");
        file.write("# ${IPTABLES} -t mangle -A output-set-marks -m comment --comment \"Set dst intf mark (0xff00)\" -j mark-dst-intf" + "\n");
        file.write("\n");

        self.write_restore_interface_marks( file, interfaces, prefix, verbosity );

        self.write_mark_src_intf( file, interfaces, prefix, verbosity );

        self.write_mark_dst_intf( file, settings, interfaces, prefix, verbosity );

        self.write_save_dst_intf_mark( file, interfaces, prefix, verbosity );

        self.write_mark_src_lxc_intf( file, settings, interfaces, prefix, verbosity );

        file.flush()
        file.close()

        if verbosity > 0:
            print("InterfacesManager: Wrote %s" % filename)

        return

    def write_pre_network_hook( self, settings, prefix="", verbosity=0 ):

        filename = prefix + self.pre_network_hook_filename
        file_dir = os.path.dirname( filename )
        if not os.path.exists( file_dir ):
            os.makedirs( file_dir )

        file = open( filename, "w+" )
        file.write("#!/bin/dash");
        file.write("\n\n");

        file.write("## Auto Generated\n");
        file.write("## DO NOT EDIT. Changes will be overwritten.\n");
        file.write("\n\n");

        file.write(r"""
## Return a list of all of the bridges
bridge_list()
{
    find /sys/class/net/*/bridge -name 'bridge_id' 2>/dev/null | sed -e 's|/sys/class/net/\([^/]*\)/.*|\1|'
}

## Return a list of interfaces that are in bridge. 
bridge_port_list()
{
    local l_bridge=$1
    
    test -n "${l_bridge}" && {
        find /sys/class/net/${l_bridge}/brif/ -maxdepth 1 -mindepth 1 -exec basename {} \; 2>/dev/null
    }
}

## Deconfigure all of the active bridges
bridge_destroy_all()
{
    local l_bridge
    local l_port
 
    for l_bridge in `bridge_list` ; do
        $DEBUG "Destroying bridge: '${l_bridge}'."
        for l_port in `bridge_port_list ${l_bridge}` ; do
            $DEBUG "Removing interface '${l_port}' from the bridge '${l_bridge}'."
            brctl delif ${l_bridge} ${l_port}
            ifconfig ${l_port} 0.0.0.0
            ifconfig ${l_port} down
        done
        ifconfig ${l_bridge} down
        brctl delbr ${l_bridge}
    done
}

# cleanup: Flushing interface addresses.
ip addr flush scope global 2>/dev/null
    
# cleanup: Destroying all of the bridges.
bridge_destroy_all

# remove interface status files
rm -f /var/lib/interface-status/interface*status.js

# disable forwarding on all interfaces, enable in all
# enable accept_ra on all interfaces
# http://strugglers.net/~andy/blog/2011/09/04/linux-ipv6-router-advertisements-and-forwarding/
""")
        file.write("echo 1 > /proc/sys/net/ipv6/conf/all/forwarding" + "\n")
        file.write("echo 0 > /proc/sys/net/ipv6/conf/default/forwarding" + "\n")
        for intf in settings.get('interfaces').get('list'):
            file.write("if [ -f /proc/sys/net/ipv6/conf/%s/forwarding ] ; then echo 0 > /proc/sys/net/ipv6/conf/%s/forwarding; fi" % (intf['physicalDev'], intf['physicalDev'])+ "\n")

        file.flush()
        file.close()
        os.chmod(filename, os.stat(filename).st_mode | stat.S_IEXEC)

        if verbosity > 0: print("InterfacesManager: Wrote %s" % filename)

    def get_lxc_interface_id( self, settings ):

        lxcInterfaceId = settings.get('lxcInterfaceId')
        if lxcInterfaceId == 0 or lxcInterfaceId == None:
            try:
                for intf in settings.get('interfaces').get('list'):
                    if not intf.get('isWan'):
                        lxcInterfaceId = intf.get('interfaceId')
                        return lxcInterfaceId
            except Exception as exc:
                traceback.print_exc()

        if lxcInterfaceId == 0 or lxcInterfaceId == None:
            return None


        

        
