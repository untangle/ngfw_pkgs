#
# $HeadURL$
# Copyright (c) 2007-2008 Untangle, Inc.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License, version 2,
# as published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but
# AS-IS and WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE, TITLE, or
# NONINFRINGEMENT.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA.
#
class OSLibrary::Debian::NetworkManager < OSLibrary::NetworkManager
  include Singleton

  Service = "/etc/init.d/networking"
  InterfacesConfigFile = "/etc/network/interfaces"
  InterfacesStatusFile = "/etc/network/run/ifstate"
  ## A simple file used to configure the ethernet media on configure network interfaces.
  MediaConfigurationFile = "/etc/untangle-net-alpaca/ethernet_media"
  NetClassDir = "/sys/class/net"

  def get_interfaces_status_file
    return InterfacesStatusFile
  end

  def interfaces
    logger.debug( "Running inside of the network manager for debian" )

    interfaceArray = []

    devices=`cd #{NetClassDir};echo */device | sed 's|/device||g'`.split

    devices.each do |os_name|

      bus_id = File.readlink("#{NetClassDir}/#{os_name}/device").sub(/.*devices\//, '')
      vendor=get_vendor( os_name )

      ## For some reason, on some systems this causes ruby to hang, use 'cat' instead.
      # mac_address = File.open( "#{NetClassDir}/#{os_name}/address", "r" ) { |f| f.readline.strip }
      mac_address = `cat "#{NetClassDir}/#{os_name}/address"`.strip
      
      logger.debug( "found network device: #{os_name}, mac: #{mac_address}, vendor: #{vendor}, bus_id: #{bus_id}" )
      interfaceArray << PhysicalInterface.new( os_name, mac_address, bus_id, vendor )
    end
    
    interfaceArray
  end

  def hook_commit
    puts "NetworkManager"
    write_files
    run_services
  end

  def hook_write_files
    interfaces_file = []
    interfaces_file << header

    media_file = []
    
    interfaces = Interface.find( :all )
    interfaces.each do |interface|
      config = interface.current_config
      ## REVIEW refactor me.
      case config
      when IntfStatic
        interfaces_file << static( interface, config )
      when IntfDynamic
        interfaces_file << dynamic( interface, config )
      when IntfBridge
        interfaces_file << bridge( interface, config )
      when IntfPppoe
        interfaces_file << pppoe( interface, config )
      end

      media_file << "#{interface.os_name} #{get_media( interface )}"
    end

    interfaces_file.push <<EOF
## This will run any scripts that need to execute when the address changes.
auto update
iface update inet manual

EOF

    ## Delete all empty or nil parts
    interfaces_file = interfaces_file.delete_if { |p| p.nil? || p.empty? }

    os["override_manager"].write_file( InterfacesConfigFile, interfaces_file.join( "\n" ), "\n" )

    os["override_manager"].write_file( MediaConfigurationFile, media_file.join( "\n" ), "\n" )

    ## Write the /etc/iftab file, ifrename is not executed
    ## Review : now because we no longer need to remap interfaces
    ## furthermore, udev is kind enough to handle this automatically.

    ## Clear out all of the interface state.
    ## Review: Should this be immutable.
    File.open( get_interfaces_status_file(), "w" ) { |f| f.print( "lo=lo" ) }
  end

  def hook_run_services
    ## Restart networking
    logger.warn "Unable to reconfigure network settings." unless run_command( "sh #{Service} start" ) == 0
  end

  ## Given an interface, this returns the expected bridge name
  def self.bridge_name( interface )
    "br.#{interface.os_name}"
  end

  private

  ## Dump out the configuration for a statically configured interface.
  def static( interface, static )
    i = nil

    ## name of the interface
    name = interface.os_name
    
    if static.nil?
      logger.warn( "The interface #{interface} is not configured" )
      return ""
    end

    ip_networks = clean_ip_networks( static.ip_networks )

    if ( ip_networks.empty? )
      logger.warn( "The interface #{interface} does not have any valid IP Networks" )
      return ""
    end

    ## This will automatically remove the first ip_network if it is assigned to the bridge.
    bridge = bridgeSettings( interface, static.mtu, "manual", ip_networks )
    
    mtu = mtuSetting( static.mtu )

    gw = static.default_gateway
    gateway_string = ""
    if ( interface.wan && !gw.nil? && !gw.empty? )
      gateway_string = "\tgateway #{static.default_gateway}\n" 
    end
    
    ## set the name
    ## Clear the MTU because that is set in the bridge
    name, mtu = OSLibrary::Debian::NetworkManager.bridge_name( interface ), nil unless bridge.empty?
    
    ## Configure each IP and then join it all together with some newlines.
    bridge += "\n" + append_ip_networks( ip_networks, name, mtu, !bridge.empty? )

    ## Append the gateway at the end, this way if one of the aliases
    ## is routed to the gateway it will still work.
    "\n" + bridge.strip + "\n" + gateway_string
  end

  def dynamic( interface, dynamic )
    ## REVIEW this is the first area that requires managers for separate files.
    ## this is updated in /etc/network/interfaces.
    ## The hostname may be modified here, or in /etc/dhcp3/dhclient.conf, ...
    ## overrides definitely go in /etc/dhcp3/dhclient.conf
    ## Default gateway override settings?

    ## REVIEW what should timeout be on configuring the interface

    i = nil

    ## name of the interface
    name = interface.os_name
    
    if dynamic.nil?
      logger.warn( "The interface #{interface} is not configured" )
      return ""
    end
    
    ## assume it is a bridge until determining otherwise
    name = OSLibrary::Debian::NetworkManager.bridge_name( interface )
    
    base_string = bridgeSettings( interface, dynamic.mtu, "dhcp" )

    ## REVIEW MTU Setting doesn't do anything in this case.
    if base_string.empty?
      name = interface.os_name
      base_string  = <<EOF
auto #{name}
iface #{name} inet dhcp
#{mtuSetting( dynamic.mtu )}
EOF
    end

    ## never set the mtu, and always start with an alias.
    ip_networks = clean_ip_networks( dynamic.ip_networks )
    base_string + "\n" + append_ip_networks( ip_networks, name, nil, true )
  end

  def bridge( interface, bridge )
    logger.debug( "Nothing needed for a bridge interface" )
    ""
  end

  ## These are the settings that should be appended to the first
  ## interface index that is inside of the interface (if this is in fact a bridge)
  def bridgeSettings( interface, mtu, config_method, ip_networks = [] )
    ## Retrieve an array of all of the bridged interfaces.
    bridged_interfaces = interface.bridged_interface_array
    
    ## If this is nil or empty, it is not a bridge.    
    return "" if ( bridged_interfaces.nil? || bridged_interfaces.empty? )
    
    ## Append this interface
    bridged_interfaces << interface

    bridge_name = self.class.bridge_name( interface )

    ## The bridge is configured as br.<intf> and then all of the ips
    ## are configured as br.<intf>:0 - done this way so restart
    ## doesn't call ifconfig br.intf down, if this happens the
    ## bridge has to relearn creating 30seconds of down time.

    configuration = <<EOF
auto #{bridge_name}
iface #{bridge_name} inet #{config_method}
\talpaca_bridge_ports #{bridged_interfaces.map{ |i| i.os_name }.join( " " )}
\tbridge_ageing 900
#{mtuSetting( mtu, "alpaca_bridge_" )}
EOF

    unless ip_networks.empty?
      ## Append the configuration for the first item
      primary_network = ip_networks.delete_at(0)
      configuration += <<EOF
\taddress #{primary_network.ip}
\tnetmask #{OSLibrary::NetworkManager.parseNetmask( primary_network.netmask)}
EOF
    end

    return configuration
  end

  def pppoe( interface, pppoe )
    ## REVIEW this is the first area that requires managers for separate files.
    ## this is updated in /etc/network/interfaces.
    ## Default gateway override settings?

    ## REVIEW what should timeout be on configuring the interface

    ## name of the interface
    name = interface.os_name
    
    if pppoe.nil?
      logger.warn( "The interface #{interface} is not configured" )
      return ""
    end

    ip_networks = clean_ip_networks( pppoe.ip_networks )

    ## This will automatically remove the first ip_network if it is assigned to the bridge.
    #bridge = bridgeSettings( interface, nil, "manual", ip_networks )
    
    #name = OSLibrary::Debian::NetworkManager.bridge_name( interface ) unless bridge.empty?
    ## Configure each IP and then join it all together with some newlines.
    #bridge += "\n" + append_ip_networks( ip_networks, name, nil, !bridge.empty? )
    
    ## Currently bridges are not supported for PPPoE
    alias_config = append_ip_networks( ip_networks, name, nil, false )
    
    ## Hardcoded at ppp0

    ## Use the ifconfig to guarantee the device is running, pppoe
    ## complains if the interface isn't running.
<<EOF
#{alias_config}

auto ppp0
iface ppp0 inet ppp
\tpre-up ifconfig #{name} up
\tprovider #{OSLibrary::PppoeManager::ProviderName}

EOF
  end


  def append_ip_networks( ip_networks, name, mtu_string, start_with_alias )
    ## this determines whether the indexing should start with an alias.
    ## mtu never applies to an alias.
    i, mtu_string = ( start_with_alias ) ? [ 0, nil ] : [ nil, mtu_string ]

    ip_networks.map do |ip_network|
      ip_network_name = "#{name}#{i.nil? ? "" : ":#{i}"}"
      i = i.nil? ? 0 : i + 1
      
      base = <<EOF
auto #{ip_network_name}
iface #{ip_network_name} inet static
\taddress #{ip_network.ip}
\tnetmask #{OSLibrary::NetworkManager.parseNetmask( ip_network.netmask)}
EOF

      base += mtu_string + "\n" unless mtu_string.nil?
      mtu_string = nil
      
      base
    end.join( "\n" )
  end

  ## mtu is always set, just in case the user overrides it
  def mtuSetting( mtu, prefix = "" )
    ## MTU of 0 or less is ignored
    mtu = OSLibrary::NetworkManager::DefaultMTU if ( mtu.nil? || mtu <= 0 )

    return "\t#{prefix}mtu #{mtu}"
  end

  def get_vendor( os_name )
    subsystem="#{NetClassDir}/#{os_name}/device/subsystem"
    bus = File.readlink(subsystem).sub(/.*\//, '')

    uevent="#{NetClassDir}/#{os_name}/device/uevent"
    vendor_id = `awk '/(PCI_ID|PRODUCT)/ { sub( /^[^=]*=/, "" );  print $0 }' #{uevent}`.strip
    
    return "Unknown" if ApplicationHelper.null?( vendor_id ) || ApplicationHelper.null?( bus )

    vendor_id = vendor_id.sub( /[:\/].*/, "" )
    
    case bus
    when "usb"
      vendor = `zcat -f /usr/share/misc/usb.ids | awk '/^#{vendor_id}/ { $1 = "" ; print $0 }'`.strip
    when "pci"
      vendor = `awk '/^#{vendor_id}/ { $1 = "" ; print $0 }' /usr/share/misc/pci.ids`.strip
    else return "Unknown"
    end
    
    return "Unknown" if ApplicationHelper.null?( vendor )
    return vendor
  end

  def get_media( interface )
    case "#{interface.speed}-#{interface.duplex}"
    when "10-full" then return "10-full-duplex" 
    when "10-half" then return "10-half-duplex" 
    when "100-full" then return "100-full-duplex" 
    when "100-half" then return "100-half-duplex"
    end

    logger.warn( "Unknown media #{interface.speed},#{interface.duplex}" ) unless interface.speed == "auto"
    
    ## default.
    return "auto"
  end
                

  def header
    <<EOF
## #{Time.new}
## Auto Generated by the Untangle Net Alpaca
## If you modify this file manually, your changes
## may be overriden

auto cleanup
iface cleanup inet manual

## Configuration for the loopback interface
auto lo
iface lo inet loopback

EOF
  end

  def clean_ip_networks( ip_networks )
    ## Copy the array of ip_networks
    ip_networks = [ ip_networks  ].flatten

    ## Copy all of the ip networks
    ip_networks = ip_networks.map { |i| i.clone }

    ## Remove any interfaces that are not valid.
    ip_networks.delete_if { |ip_network| !is_valid_ip_network?( ip_network ) }
  end

  def is_valid_ip_network?( ip_network )
    return false if ApplicationHelper.null?( ip_network.ip )
    return false if ApplicationHelper.null?( ip_network.netmask )

    return false if IPAddr.parse_ip( ip_network.ip ).nil?
    return false if IPAddr.parse_netmask( ip_network.netmask ).nil?

    return false if ( ip_network.ip == "0.0.0.0" || ip_network.ip == "255.255.255.255" )
    return false if ( ip_network.netmask == "0.0.0.0" )

    true
  end
end
