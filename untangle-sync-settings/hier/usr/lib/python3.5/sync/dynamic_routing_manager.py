import os
import pwd
import grp
import sys
import subprocess
import datetime
import traceback
import re
from shutil import move
from sync.network_util import NetworkUtil
from sync import registrar

# This class is responsible for writing 
# based on the settings object passed from sync-settings.py
class DynamicRoutingManager:
    conf_path="/etc/quagga"
    daemons_conf_filename=conf_path + "/daemons"
    zebra_conf_filename=conf_path + "/zebra.conf"
    bgpd_conf_filename=conf_path + "/bgpd.conf"
    ospfd_conf_filename=conf_path + "/ospfd.conf"
    file_uid=65534 #nobody
    file_gid=65534 #nobody

    auto_generated_comment="Auto Generated"
    do_not_edit_comment="DO NOT EDIT. Changes will be overwritten"

    hostname="Router"
    password="zebra"

    allowed_daemons = ["bgp", "ospf"]

    restart_hook_filename = "/etc/untangle/post-network-hook.d/990-restart-quagga"
    ip_dev_regex = re.compile(r'\s+dev\s+([^\s]+)')
    # ?? supprt inet6?
    ip_addr_regex = re.compile(r'\s+inet\s+([^\s]+)')

    def sync_settings( self, settings, prefix, delete_list, verbosity=0 ):
        if settings.get('dynamicRoutingSettings') is not None:
            self.write_daemons_conf( settings, prefix, verbosity )
            self.write_zebra_conf( settings, prefix, verbosity )
            self.write_bgpd_conf( settings, prefix, verbosity )
            self.write_ospfd_conf( settings, prefix, verbosity )
            self.write_restart_quagga_daemons_hook( settings, prefix, verbosity )
        return

    def initialize( self ):
        try:
            file_uid=pwd.getpwnam("quagga").pw_uid
            file_gid=grp.getgrnam("quagga").gr_gid
        except Exception as exc:
            traceback.print_exc()
            
        registrar.register_file( self.daemons_conf_filename, "restart-quagga", self )
        registrar.register_file( self.zebra_conf_filename, "restart-quagga", self )
        registrar.register_file( self.bgpd_conf_filename, "restart-quagga", self )
        registrar.register_file( self.ospfd_conf_filename, "restart-quagga", self )
        registrar.register_file( self.restart_hook_filename, "restart-quagga", self )

    def address_to_bits(self, address):
        return ''.join('{:08b}'.format(int(x)) for x in address.split('.'))

    def bits_to_address(self, bits, prefix):
        bits = '{message:{fill}{align}{width}}'.format(message=bits,fill='0',align='<',width=32)
        chunks = len(bits)
        chunk_size = chunks/4
        return '.'.join([ '{0}'.format(int(bits[i:i+chunk_size], 2)) for i in range(0, chunks, chunk_size)])

    def get_interfaces_from_networks(self, settings, want_daemon=None):
        interfaces = []

        # Look at bgp + ospf networks
        # look at interfaces to get best route match:
        # interfaces
        # openvpn
        # tunnelvpn
        #

        # Build explicitly define network list for specified daemon.
        # If daemon is not defined, pull from all daemons (used in Zebra)
        networks = []
        for daemon in self.allowed_daemons:
            if want_daemon is not None and want_daemon is not daemon:
                continue

            if "dynamicRoutingSettings" in settings:
                if ( daemon+"Enabled" in settings["dynamicRoutingSettings"] and 
                     daemon+"Networks" in settings["dynamicRoutingSettings"] and
                    "list" in settings["dynamicRoutingSettings"][daemon+"Networks"] ):
                    for networkSetting in settings["dynamicRoutingSettings"][daemon+"Networks"]["list"]:
                        if networkSetting["enabled"]:
                            network = networkSetting["network"] + "/" + str(networkSetting["prefix"])
                            if not network in networks:
                                networks.append({
                                    "network": network,
                                    "found": False
                                })

        interfaces_routes_to_add = {}
        for network in networks:
            network_network, netmask_prefix = network["network"].split('/')
            dynamic_prefix = int(netmask_prefix)
            dynamic_network_bits = self.address_to_bits(network_network)

            #
            # Look at static route settings
            #
            if "staticRoutes" in settings and "list" in settings["staticRoutes"]:
                for route in settings["staticRoutes"]["list"]:
                    route_prefix = route["prefix"]
                    route_network_bits = self.address_to_bits(route["network"])
                    if dynamic_prefix <= route_prefix and dynamic_network_bits[:route_prefix] == route_network_bits[:route_prefix]:
                        if not route["nextHop"] in interfaces_routes_to_add:
                            interfaces_routes_to_add[route["nextHop"]] = []
                        route_network = self.bits_to_address(route_network_bits, route_prefix)
                        if route_network not in interfaces_routes_to_add[route["nextHop"]]:
                            interfaces_routes_to_add[route["nextHop"]].append(route_network)

            #
            # Look at interface settings.
            #
            if "interfaces" in settings and "list" in settings["interfaces"]:
                for interface in settings["interfaces"]["list"]:
                    #
                    #  Treat aliases like routes.
                    #
                    if interface["configType"] == "ADDRESSED" and interface["v4Aliases"] and interface["v4Aliases"]["list"]:
                        for alias in interface["v4Aliases"]["list"]:
                            alias_prefix = int(alias["staticPrefix"])
                            alias_network_bits = self.address_to_bits(alias["staticAddress"])
                            if dynamic_prefix <= alias_prefix and dynamic_network_bits[:alias_prefix] == alias_network_bits[:alias_prefix]:
                                if not interface["interfaceId"] in interfaces_routes_to_add:
                                    interfaces_routes_to_add[interface["interfaceId"]] = []
                                alias_network = self.bits_to_address(self.address_to_bits(alias["staticAddress"]), alias_prefix)
                                if alias_network not in interfaces_routes_to_add[interface["interfaceId"]]:
                                    interfaces_routes_to_add[interface["interfaceId"]].append(alias_network)
                                
                                network["found"] = True
                                if not dev_object in interfaces:
                                    interfaces.append(dev_object)

                    #
                    # Look at static interface address
                    #
                    if interface["configType"] == "ADDRESSED" and interface["v4ConfigType"] == "STATIC":
                        interface_prefix = int(interface["v4StaticPrefix"])
                        interface_network_bits = self.address_to_bits(interface["v4StaticAddress"])
                        if (interface["interfaceId"] in list(interfaces_routes_to_add.keys())) or ( dynamic_prefix <= interface_prefix and dynamic_network_bits[:interface_prefix] == interface_network_bits[:interface_prefix]):
                            dev_object = {
                                'interfaceId': interface["interfaceId"],
                                'dev': interface["symbolicDev"],
                                'address': interface["v4StaticAddress"],
                                'prefix': interface["v4StaticPrefix"],
                                'network': self.bits_to_address(self.address_to_bits(interface["v4StaticAddress"])[:interface_prefix], interface_prefix)
                            }
                            if not dev_object in interfaces:
                                interfaces.append(dev_object)
                            network["found"] = True

                    # look @ dhcp, pppoe

            if network["found"] is False:
                # Look in system
                for route in subprocess.Popen("ip route show {0}".format(network["network"]), shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT).communicate()[0].split('\n'):
                    match_dev = re.search( self.ip_dev_regex, route )
                    if match_dev:
                        dev = match_dev.group(1)
                        if dev not in interfaces_routes_to_add:
                            interfaces_routes_to_add[dev] = []
                        if network not in interfaces_routes_to_add[dev]:
                            interfaces_routes_to_add[dev].append(network["network"])

                for dev in list(interfaces_routes_to_add.keys()):
                    for addr in subprocess.Popen("ip addr show dev {0}".format(dev), shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT).communicate()[0].split('\n'):
                        match_addr = re.search( self.ip_addr_regex, addr )
                        if match_addr:
                            dev_address, dev_prefix = match_addr.group(1).split('/')
                            dev_prefix = int(dev_prefix)
                            dev_object = {
                                'dev': dev,
                                'address': dev_address,
                                'prefix': dev_prefix,
                                'network': self.bits_to_address(self.address_to_bits(dev_address)[:dev_prefix], dev_prefix),
                            }
                            if not dev_object in interfaces:
                                interfaces.append( dev_object )
                            break

        for interface in interfaces:
            if "interfaceId" in interface and interface["interfaceId"] in interfaces_routes_to_add:
                interface["routes"] = interfaces_routes_to_add[interface["interfaceId"]]
            if interface["dev"] in interfaces_routes_to_add:
                interface["routes"] = interfaces_routes_to_add[interface["dev"]]

        return interfaces

    def write_daemons_conf( self, settings, prefix="", verbosity=0 ):
        """
        Create Quagga daemon configuration file.
        """
        filename = prefix + self.daemons_conf_filename
        file_dir = os.path.dirname( filename )
        if not os.path.exists( file_dir ):
            os.makedirs( file_dir )

        enables = {
            'zebra': False,
            'bgpd': False,
            'ospfd': False
        }
        enables['zebra'] = False if settings.get('dynamicRoutingSettings') == None else settings.get('dynamicRoutingSettings').get('enabled')
        if enables['zebra']:
            enables['bgpd']= settings['dynamicRoutingSettings']['bgpEnabled']
            enables['ospfd'] = settings['dynamicRoutingSettings']['ospfEnabled']

        # Daemon file is supplied by package, so "modify" by reading live instead of overwriting.
        daemons_contents = []
        # FIXME template no longer exists in jessie
        # file = open(self.daemons_conf_filename, "r")
        # for line in file:
        #     line = line.strip()
        #     if line == "":
        #         continue
        #     elif line.startswith('#'):
        #         if self.auto_generated_comment in line:
        #             continue
        #         if self.do_not_edit_comment in line:
        #             continue
        #         daemons_contents.append(line)
        #     elif "=" in line:
        #         [daemon,currently_enabled] = line.split("=", 2)
        #         if daemon in enables:
        #             daemons_contents.append("{0}={1}".format(daemon, 'yes' if enables[daemon] is True else 'no'))
        #         else:
        #             daemons_contents.append(line)
        #     else:
        #         daemons_contents.append(line)
        # file.close()

        file = open( filename, "w+" )
        file.write("## {0}{1}".format(self.auto_generated_comment, "\n"));
        file.write("## {0}{1}".format(self.do_not_edit_comment, "\n"));

        # FIXME
        for line in daemons_contents:
            file.write(line + "\n")

        file.flush()
        file.close()
        os.chown(filename, self.file_uid, self.file_gid)

        if verbosity > 0: print("DynamicRoutingManager: Wrote %s" % filename)

    def write_zebra_conf( self, settings, prefix="", verbosity=0 ):
        """
        Create Quagga zebra daemon configuration file.
        """
        enabled = False if settings.get('dynamicRoutingSettings') == None else settings.get('dynamicRoutingSettings').get('enabled')
        if not enabled:
            return

        filename = prefix + self.zebra_conf_filename
        file_dir = os.path.dirname( filename )
        if not os.path.exists( file_dir ):
            os.makedirs( file_dir )

        zebra_interfaces = []
        for interface in self.get_interfaces_from_networks(settings):
            zebra_interfaces.append("""\
interface {0}
 ip address {1}/{2}
 ipv6 nd suppress-ra""".format(interface["dev"], interface["address"], interface["prefix"]))

        file = open( filename, "w+" )
        file.write(r"""
! {0}
! {1}
hostname {2}
password {3}
enable password {3}

{4}

ip forwarding
line vty
""".format(self.auto_generated_comment, self.do_not_edit_comment, self.hostname, self.password, "\n".join(zebra_interfaces) ))

        file.write("\n");
        file.flush()
        file.close()
        os.chown(filename, self.file_uid, self.file_gid)

        if verbosity > 0: print("DynamicRoutingManager: Wrote %s" % filename)

    def write_bgpd_conf( self, settings, prefix="", verbosity=0 ):
        """
        Create Quagga bgp daemon configuration file.
        """
        enabled = False if settings.get('dynamicRoutingSettings') == None else settings.get('dynamicRoutingSettings').get('bgpEnabled')
        if not enabled:
            return

        filename = prefix + self.bgpd_conf_filename
        file_dir = os.path.dirname( filename )
        if not os.path.exists( file_dir ):
            os.makedirs( file_dir )

        bgp_networks = []
        if settings['dynamicRoutingSettings']['bgpNetworks'] and settings['dynamicRoutingSettings']['bgpNetworks']["list"]:
            for network in settings['dynamicRoutingSettings']['bgpNetworks']["list"]:
                if network["enabled"] is True:
                    bgp_networks.append("network {0}/{1}".format(network["network"], network["prefix"]) )

        bgp_neighbors = []
        if settings['dynamicRoutingSettings']['bgpNeighbors'] and settings['dynamicRoutingSettings']['bgpNeighbors']["list"]:
            for neighbor in settings['dynamicRoutingSettings']['bgpNeighbors']["list"]:
                if neighbor["enabled"] is True:
                    bgp_neighbors.append("""\
neighbor {0} remote-as {1}
neighbor {0} route-map set-nexthop out
neighbor {0} ebgp-multihop
neighbor {0} next-hop-self
""".format(neighbor["ipAddress"], neighbor["as"]) )

        file = open( filename, "w+" )
        file.write(r"""
! {0}
! {1}
hostname bgpd
password {2}
enable password {2}

router bgp {3}
bgp router-id {4}

{5}

{6}

route-map set-nexthop permit 10
""".format(self.auto_generated_comment, self.do_not_edit_comment, self.password, settings['dynamicRoutingSettings']['bgpRouterAs'], settings['dynamicRoutingSettings']['bgpRouterId'], "\n".join(bgp_networks), "\n".join(bgp_neighbors) ))

        file.write("\n");
        file.flush()
        file.close()
        os.chown(filename, self.file_uid, self.file_gid)

        if verbosity > 0: print("DynamicRoutingManager: Wrote %s" % filename)

    def write_ospfd_conf( self, settings, prefix="", verbosity=0 ):
        """
        Create Quagga ospf daemon configuration file.
        """
        enabled = False if settings.get('dynamicRoutingSettings') == None else settings.get('dynamicRoutingSettings').get('ospfEnabled')
        if not enabled:
            return

        filename = prefix + self.ospfd_conf_filename
        file_dir = os.path.dirname( filename )
        if not os.path.exists( file_dir ):
            os.makedirs( file_dir )

        interfaces_from_networks = self.get_interfaces_from_networks(settings, "ospf")

        # !??? look for defined interfaces and add anyway

        ospf_interfaces = []
        for interface in interfaces_from_networks:
            ospf_interfaces.append("interface {0}".format(interface["dev"]) )

            if "ospfInterfaces" in settings['dynamicRoutingSettings'] and "list" in settings['dynamicRoutingSettings']['ospfInterfaces']:
                for ospf_interface in settings['dynamicRoutingSettings']['ospfInterfaces']["list"]:
                    if ospf_interface["dev"] == interface["dev"] and ospf_interface["enabled"] is True:
                        if ospf_interface["authentication"] != 0:
                            if ospf_interface["authentication"] == 1:
                                ospf_interfaces.append(" ip ospf authentication-key {0}".format( ospf_interface["authenticationPassword"]));
                            if ospf_interface["authentication"] == 2:
                                ospf_interfaces.append(" ip ospf authentication message-digest")
                                ospf_interfaces.append(" ip ospf message-digest-key {0} md5 {1}".format( ospf_interface["authenticationKeyId"], ospf_interface["authenticationKey"]));
                        ospf_interfaces.append("""\
 ip ospf hello-interval {0}
 ip ospf dead-interval {1}
 ip ospf retransmit-interval {2}
 ip ospf transmit-delay {3}
 ip ospf priority {4}
 """.format(str(ospf_interface["helloInterval"]), str(ospf_interface["deadInterval"]),str(ospf_interface["retransmitInterval"]), str(ospf_interface["transmitDelay"]),str(ospf_interface["routerPriority"]) ))
                        if ospf_interface["autoInterfaceCost"] is False:
                            ospf_interfaces.append(" ip ospf cost {0}".format(str(ospf_interface["interfaceCost"])))
                        else:
                            ospf_interfaces.append(" no ip ospf cost")

        ospf_ids_areas = {}
        ospf_areas = []
        if "ospfAreas" in settings['dynamicRoutingSettings'] and "list" in settings['dynamicRoutingSettings']['ospfAreas']:
            for area in settings['dynamicRoutingSettings']['ospfAreas']["list"]:
                ospf_ids_areas[area["ruleId"]] = area["area"]
                if area["type"] == 0:
                    if "virtualLinks" in area and "list" in area["virtualLinks"]:
                        for virtual_link in area["virtualLinks"]["list"]:
                            ospf_areas.append(" area {0} virtual-link {1}".format(area["area"], virtual_link))
                else:
                    if area["type"] == 1:
                        ospf_areas.append(" area {0} stub".format(area["area"]))
                    elif area["type"] == 2:
                        ospf_areas.append(" area {0} stub no-summary".format(area["area"]))
                    elif area["type"] == 3:
                        ospf_areas.append(" no area {0} stub".format(area["area"]))
                    elif area["type"] == 4:
                        ospf_areas.append(" no area {0} stub no-summary".format(area["area"]))

                if area["authentication"] != 0:
                    if area["authentication"] == 1:
                        ospf_areas.append(" area {0} authentication".format(area["area"]))
                    elif area["authentication"] == 2:
                        ospf_areas.append(" area {0} authentication message-digest".format(area["area"]))

        ospf_options = []
        if 'ospfRouterId' in settings['dynamicRoutingSettings'] and settings['dynamicRoutingSettings']["ospfRouterId"] != "":
            ospf_options.append( " ospf router-id {0}".format(settings['dynamicRoutingSettings']['ospfRouterId']))
        if 'ospfAbrType' in settings['dynamicRoutingSettings'] and settings['dynamicRoutingSettings']["ospfAbrType"] > 0:
            if settings['dynamicRoutingSettings']["ospfAbrType"] == 1:
                abr_type = 'cisco'
            elif settings['dynamicRoutingSettings']["ospfAbrType"] == 2:
                abr_type = 'ibm'
            elif settings['dynamicRoutingSettings']["ospfAbrType"] == 3:
                abr_type = 'shortcut'
            else:
                abr_type = 'standard'
            ospf_options.append( " ospf abr-type {0}".format( abr_type) )
        if 'ospfUseDefaultMetricEnabled' in settings['dynamicRoutingSettings'] and settings['dynamicRoutingSettings']["ospfUseDefaultMetricEnabled"] is True and "ospfDefaultMetric" in settings['dynamicRoutingSettings']:
            ospf_options.append( " default-metric {0}".format( str(settings['dynamicRoutingSettings']['ospfDefaultMetric']) ))
        if 'ospfAutoCost' in settings['dynamicRoutingSettings'] and settings['dynamicRoutingSettings']["ospfAutoCost"] > 0:
            ospf_options.append( " auto-cost reference-bandwidth {0}".format( str(settings['dynamicRoutingSettings']['ospfAutoCost']) ))
        if 'ospfDefaultInformationOriginateType' in settings['dynamicRoutingSettings'] and settings['dynamicRoutingSettings']["ospfDefaultInformationOriginateType"] > 0:
            if settings['dynamicRoutingSettings']["ospfDefaultInformationOriginateType"] == 1:
                otype = ""
            else:
                otype = "always"
            ospf_options.append( " default-information originate {0} metric {1} metric-type {2}".format( otype, settings['dynamicRoutingSettings']["ospfDefaultInformationOriginateMetric"], settings['dynamicRoutingSettings']["ospfDefaultInformationOriginateExternalType"]))
        if 'ospfRedistConnectedEnabled' in settings['dynamicRoutingSettings'] and settings['dynamicRoutingSettings']["ospfRedistConnectedEnabled"] is True:
            ospf_options.append( " redistribute connected metric-type {0} metric {1}".format( settings['dynamicRoutingSettings']["ospfRedistConnectedExternalType"], settings['dynamicRoutingSettings']["ospfRedistConnectedMetric"]))
        if 'ospfRedistStaticEnabled' in settings['dynamicRoutingSettings'] and settings['dynamicRoutingSettings']["ospfRedistStaticEnabled"] is True:
            ospf_options.append( " redistribute static metric-type {0} metric {1}".format( settings['dynamicRoutingSettings']["ospfRedistStaticExternalType"], settings['dynamicRoutingSettings']["ospfRedistStaticMetric"]))
        if settings['dynamicRoutingSettings']['bgpEnabled'] is True and 'ospfRedistBgpEnabled' in settings['dynamicRoutingSettings'] and settings['dynamicRoutingSettings']["ospfRedistBgpEnabled"] is True:
            ospf_options.append( " redistribute bgp metric-type {0} metric {1}".format( settings['dynamicRoutingSettings']["ospfRedistBgpExternalType"], settings['dynamicRoutingSettings']["ospfRedistBgpMetric"]))


        ospf_networks = []
        if 'ospfNetworks' in settings['dynamicRoutingSettings'] and "list" in settings['dynamicRoutingSettings']['ospfNetworks']:
            for network in settings['dynamicRoutingSettings']['ospfNetworks']["list"]:
                if network["enabled"] is True:
                    ospf_networks.append(" network {0}/{1} area {2}".format(network["network"], network["prefix"], ospf_ids_areas[network["area"]]) )
                    for interface in interfaces_from_networks:
                        if "routes" in interface and network["network"] + '/' + str(network["prefix"]) in interface['routes']:
                            ospf_networks.append(" network {0}/{1} area {2}".format(interface["network"], interface["prefix"], ospf_ids_areas[network["area"]]) )

        file = open( filename, "w+" )
# passive-interface {6}
        file.write(r"""
! {0}
! {1}
hostname ospfd
password {2}
enable password {2}

log stdout

{3}

router ospf
{4}
{5}
{6}

route-map set-nexthop permit 10
""".format(self.auto_generated_comment, self.do_not_edit_comment, self.password, "\n".join(ospf_interfaces), "\n".join(ospf_options),  "\n".join(ospf_networks), "\n".join(ospf_areas) ))

        file.write("\n");
        file.flush()
        file.close()
        os.chown(filename, self.file_uid, self.file_gid)

        if verbosity > 0: print("DynamicRoutingManager: Wrote %s" % filename)

    def write_restart_quagga_daemons_hook( self, settings, prefix="", verbosity=0 ):
        """
        Create network process extension to restart or stop daemon
        """
        filename = prefix + self.restart_hook_filename
        file_dir = os.path.dirname( filename )
        if not os.path.exists( file_dir ):
            os.makedirs( file_dir )

        file = open( filename, "w+" )
        file.write("#!/bin/dash");
        file.write("\n\n");

        file.write("""
## {0}
## {1} 

""".format(self.auto_generated_comment, self.do_not_edit_comment))

        # !!! look for enabled with dictionary check
        if settings.get('dynamicRoutingSettings') == None or not settings.get('dynamicRoutingSettings').get('enabled'):
            file.write(r"""
ZEBRA_PID="`pidof zebra`"

# Stop quagga if running
if [ ! -z "$ZEBRA_PID" ] ; then
    # FIXME stretch uses separate services for zebra/ospfd/ospf6d/bgpd
    systemctl --no-block stop quagga
fi
""")
        else:
            file.write(r"""
ZEBRA_PID="`pidof zebra`"

# Restart quagga if it isnt found
# Or if zebra.conf orhas been written since quagga was started
if [ -z "ZEBRA_PID" ] ; then
    # FIXME stretch uses separate services for zebra/ospfd/ospf6d/bgpd
    systemctl --no-block restart quagga
# use not older than (instead of newer than) because it compares seconds and we want an equal value to still do a restart
elif [ ! {0} -ot /proc/$ZEBRA_PID ] ; then
    # FIXME stretch uses separate services for zebra/ospfd/ospf6d/bgpd
    systemctl --no-block restart quagga
fi
""".format(self.daemons_conf_filename))

        file.write("\n");
        file.flush()
        file.close()
    
        os.system("chmod a+x %s" % filename)
        if verbosity > 0: print("DynamicRoutingManager: Wrote %s" % filename)
        return


