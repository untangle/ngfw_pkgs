#
# $HeadURL: svn://chef/work/pkgs/untangle-net-alpaca/files/var/lib/rails/untangle-net-alpaca/vendor/plugins/alpaca/lib/alpaca/uvm_data_loader.rb $
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
require "logger"
require "json"

## The ConfigurationLoader loads settings from the current state of
## the box.  This is useful in situations when there are no default
## settings for a box and the user isn't required to go through a
## wizard.
class Alpaca::ConfigurationLoader
  LOG_FILE = '/var/log/untangle-net-alpaca/alpaca-load-configuration.log'

  PrepareConfiguration = "pre_prepare_configuration"
  SaveConfiguration = "pre_save_configuration"

  include ::Alpaca::ComponentExtensions

  def initialize
    @logger = Logger.new( LOG_FILE, 10, 1048576 )
  end

  attr_reader :logger

  def load_configuration
    logger.debug( "Loading configuration #{Time.new}" )
    load_network_settings

    load_hostname

    load_dns_settings
  end

  def preconfigure
    logger.debug( "Preconfiguring the box #{Time.new}" )

    config_file = ENV["CONFIG_FILE"]

    config = ""
    File.open( config_file,  "r" ) { |f| f.each_line { |l| config << l }}
    config = ::JSON.parse( config )

    settings_hash = {}
    
    ## Give all of the components a chance to screen the settings before saving them.
    iterate_components do |component|
      next unless component.respond_to? PrepareConfiguration
      component.send( PrepareConfiguration, config, settings_hash )
    end
    
    ## Order doesn't matter because this is just saving to the database
    iterate_components do |component|
      next unless component.respond_to? SaveConfiguration
      component.send( SaveConfiguration, config, settings_hash )
    end
  end

  private
  def load_network_settings
    ## Load the network settings.
    
    ## Delete all of the interfaces on the box (this really should run from scratch)
    Interface.destroy_all
    
    ## Load all of the interfaces on the box
    interfaces = InterfaceHelper.loadInterfaces

    ## Sort the interfaces (WAN is first, and then it is by indexes, this is mainly to
    ## make the bridge calculate map the bridge to the highest interface.
    interfaces.sort! do |a,b| 
      next -1 if a.wan
      next 1 if b.wan
      a.index <=> b.index
    end

    ## Retrieve the interface mapping, this is used for bridging.
    interface_map = calculate_interface_map( interfaces )

    raise ( "No interfaces are available, exiting" ) if interfaces.empty?

    interfaces.each do |interface|
      logger.debug( "Loading the interface: #{interface.os_name}" )
      os_name = interface_map[interface]

      unless interface.is_mapped?
        next interface.save
      end

      ## This should be bridged to another interface
      if ( os_name.is_a?( Interface ))
        bridge_interface = os_name
        bridge = IntfBridge.new
        bridge.bridge_interface = bridge_interface
        bridge_interface.bridged_interfaces << bridge
        interface.intf_bridge = bridge
        interface.config_type = InterfaceHelper::ConfigType::BRIDGE
        interface.save
        next
      end

      ## Determine if DHCP is enabled on this interface.
      os_name = interface.os_name if os_name.nil?

      logger.debug( "os_name: '#{os_name}'" )
      
      network_array = `ip addr show #{os_name} | awk '/inet.*scope global/ { print $2 }'`.strip.split
      is_dhcp=`ps aux | grep 'dhc[p].*#{os_name}'`.strip != ""

      ## Convert the strings into ip networks.
      position = 0
      network_array = network_array.map do |network| 
        ip_network = IpNetwork.new( :position => position += 1 )
        ip_network.parseNetwork( network )
        ip_network
      end
      
      ## The DHCP case is just concerned with the aliases.
      if ( is_dhcp )
        ## The first address is (hopefully) configured by DHCP.
        network_array.delete_at( 0 )
        dynamic = IntfDynamic.new
        dynamic.ip_networks = network_array
        interface.intf_dynamic = dynamic
        interface.config_type = InterfaceHelper::ConfigType::DYNAMIC
        interface.save
        next
      end

      ## Create a new static configuration
      static = IntfStatic.new

      if interface.wan
        ## setup the dns servers and the default gateway.
        static.dns_1, static.dns_2 = get_dns_servers
        static.default_gateway = get_default_gateway
      end

      static.ip_networks = network_array
      interface.intf_static = static
      interface.config_type = InterfaceHelper::ConfigType::STATIC
      interface.save
    end
  end

  def load_hostname
    HostnameSettings.destroy_all
    HostnameSettings.new( :hostname => `hostname`.strip ).save
  end

  def load_dns_settings
    suffix = `awk '/^search/ { print $2 ; exit }' /etc/resolv.conf`.strip
    suffix = "example.com" unless ::Alpaca::Validator.is_hostname?( suffix )

    DhcpServerSettings.destroy_all
    DnsServerSettings.destroy_all
    DhcpStaticEntry.destroy_all
    DnsStaticEntry.destroy_all

    DnsServerSettings.new( :suffix => suffix, :enabled => true ).save

    DhcpServerSettings.new( :enabled => false, :start_address => "", :end_address => "" ).save
  end

  def get_dns_servers
    servers = `awk '/nameserver/ { print $2 }' /etc/resolv.conf`.strip.split
    servers += `awk '/^server=/ { sub( "server=", "" ); print }' /etc/dnsmasq.conf`.strip.split

    ## Delete all of the invalid nameservers
    servers.delete_if { |n| n.nil? || n.empty? || /127\.0\./.match( n ) || IPAddr.parse_ip( n ).nil? }
    servers.uniq!
    
    servers
  end

  def get_default_gateway
    `ip route show | awk '/^default/ { print $3 }'`
  end

  ## This creates a map in the form of
  ## interface -> { <os_name> | <interface> }
  ## if interface is mapped to an os_name, then it should be configured using the
  ## ip configuration from the interface.  If it is mapped an interface, it should
  ## be setup as a bridge to that interface.
  def calculate_interface_map( interface_array )
    interface_map = {}

    os_name_map = {}

    ## Default to looking up by os_name
    interface_array.each do |interface|
      next unless interface.is_mapped?

      logger.debug( "os_name_map[#{interface.os_name}] = #{interface}" )
      os_name_map[interface.os_name] = interface
    end

    ## In the first pass, map all of the interfaces to the bridge name.
    `find /sys/class/net/*/brif* 2>/dev/null`.each_line do |line|
      line.strip!
      logger.debug( "Testing the line: #{line}" )
      match = /^\/sys\/class\/net\/([^\/]*)\/brif\/([^\/]*)$/.match( line )
      next if match.nil?
      bridge,os_name = match[1], match[2]

      next if os_name.nil?

      interface = os_name_map[os_name]
      next logger.warn( "Unable to find the interface '#{os_name}'" ) if interface.nil?
      
      interface_map[interface] = bridge
    end

    interface_map.each { |k,v| logger.debug( "#{k.os_name} => #{v}" ) }

    ## Map from <bridge> -> interface
    bridge_map = {}

    ## In the second pass, (use the interface array so it is sorted) and
    ## map the bridges to the first one that matches.
    interface_array.each do |interface|
      next unless interface.is_mapped?

      bridge_name = interface_map[interface]
      ## Skip the interfaces that havent' been remapped.
      next if ( bridge_name.nil? )
      
      bridge = bridge_map[bridge_name]

      if bridge.nil?
        ## If the bridge doesn't exist, create one
        interface_map[interface] = bridge_name
        bridge_map[bridge_name] = interface
      else
        ## Otherwise, map this interface to the existing bridge.
        interface_map[interface] = bridge
      end
    end

    interface_map
  end

  ## Have to define these in order to use the component util
  def params
    {}
  end

  def session
    nil
  end

  def request
    nil
  end


end
