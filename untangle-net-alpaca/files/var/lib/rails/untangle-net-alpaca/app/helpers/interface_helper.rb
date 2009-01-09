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
require "ipaddr"

module InterfaceHelper
  include GetText

  ExternalIndex = 1
  InternalIndex = 2
  DmzIndex = 3

  ExternalName = "External"
  InternalName = "Internal"
  DmzName = "DMZ"

  ## DDD These are subject to internationalization DDD
  ## REVIEW : These are also linux specific.
  DefaultInterfaceMapping = {
    # default Display name plus the index
    "eth0" => [ ExternalName, ExternalIndex ],
    "eth1" => [ InternalName, InternalIndex ],
    "eth2" => [ DmzName, DmzIndex ]
  }

  ## Array of the critical interfaces, these are the interfaces that are displayed
  ## regardless of whether or not something is "mapped" to them
  CriticalInterfaces = [ ExternalIndex, InternalIndex ]

  ## REVIEW :: These Strings need to be internationalized.
  class ConfigType
    STATIC="static"
    DYNAMIC="dynamic"
    BRIDGE="bridge"
    PPPOE="pppoe"
  end

  ## Array of all of the available config types
  CONFIGTYPES = [ ConfigType::STATIC, ConfigType::DYNAMIC, ConfigType::BRIDGE, ConfigType::PPPOE ].freeze
  
  ## An array of the config types that you can bridge with
  BRIDGEABLE_CONFIGTYPES = [ ConfigType::STATIC, ConfigType::DYNAMIC, ConfigType::PPPOE ].freeze

  ## A hash of all of the various ethernet medias
  class EthernetMedia
    @@order = []
    @@key_hash = {}

    def initialize( name, speed, duplex )
      @name, @speed, @duplex = name, speed, duplex
      
      @@order << self
      @@key_hash[key] = self
    end
    
    def key
      "#{@speed}#{@duplex}"
    end

    def self.get_value( value )
      @@key_hash[value]
    end

    def self.order
      @@order
    end

    def self.get_default()
      @@order[0]
    end
    
    attr_reader :name, :speed, :duplex
  end
    
  [[ _( "Auto" ), "auto", "auto" ],
   [ _( "1000 Mbps, Full Duplex" ),"1000","full" ],
   [ _( "100 Mbps, Full Duplex" ),"100","full" ],
   [ _( "100 Mbps, Half Duplex" ),"100","half" ],
   [ _( "10 Mbps, Full Duplex" ),"10","full" ],
   [ _( "10 Mbps, Half Duplex" ),"10","half" ]].each { |args| EthernetMedia.new( *args ) }


  ## Load the new interfaces and return two arrays.
  ## first the array of new interfaces to delete.
  ## Second is the array of interfaces that should be deleted.
  ## REVIEW : this will not work if the mac address has a different case.
  def self.load_new_interfaces
    delete_interfaces = []
    new_interfaces = []

    physical_interfaces = self.loadInterfaces
    mac_addresses = {}

    ## These are existing in the database
    existing_mac_addresses = {}
    existing_indices = {}

    physical_interfaces.each do |interface|
      mac_addresses[interface.mac_address] = true unless ApplicationHelper.null? interface.mac_address
    end
    
    Interface.find( :all ).each do |interface|
      next unless interface.is_mapped?

      ## Delete any items that are not in the list of current mac addresses.
      next delete_interfaces << interface unless mac_addresses[interface.mac_address] == true

      ## Build the list of mac_addresses
      existing_mac_addresses[interface.mac_address] = true

      ## Append the item to the index hash
      existing_indices[interface.index] = true
    end

    ## Interfaces have to be sorted by index
    physical_interfaces.sort! { |a,b| a.index <=> b.index }

    ## Mark any interfaces that are not in the database as new, and update the index
    ## so it doesn't conflict with the current interfaces
    physical_interfaces.each do |interface|
      ## Ignore unmapped interfaces
      next unless interface.is_mapped?
      
      unless existing_mac_addresses[interface.mac_address] == true
        ## Check if the interfaces index is taken, if so, use a different one
        if ( existing_indices[interface.index] == true )
          ## Serious magic number (7) here
          ( interface.index .. 7 ).each do |idx| 
            break interface.index = idx unless existing_indices[idx] == true
          end

          interface.name = InterfaceHelper.get_interface_name( interface )
          existing_indices[interface.index] = true
          interface.wan = ( interface.index == ExternalIndex )
        end
        new_interfaces << interface 
      end
    end

    [ new_interfaces, delete_interfaces ]
  end

  ## DDD some of this code may be debian specific DDD
  def self.loadInterfaces
    ## Create an empty array
    interfaceArray = []

    ## Find all of the physical interfaces
    currentIndex = DefaultInterfaceMapping.size

    ## Hash from index to interface, used to add the critical internal and external
    ## interfaces if they don't exist.
    interface_hash = {}

    ia = networkManager.interfaces

    raise "Unable to detect any interfaces" if ( ia.nil? || ia.empty? )

    ia.each do |i| 
      interface = Interface.new

      ## Save the parameters from the physical interface.
      interface.os_name, interface.mac_address, interface.bus, interface.vendor = 
        i.os_name, i.mac_address, i.bus_id, i.vendor

      parameters = DefaultInterfaceMapping[i.os_name]
      ## Use the os name if it doesn't have a predefined virtual name
      parameters = [ i.os_name, currentIndex += 1 ] if parameters.nil?
      interface.name, interface.index  = parameters

      ## default it to a static config
      interface.config_type = InterfaceHelper::ConfigType::STATIC

      interface.wan = ( interface.index == ExternalIndex )
      
      ## Add the interface.
      interfaceArray << interface

      interface_hash[interface.index] = interface
    end

    ## Sort the interface array by index.
    interfaceArray.sort! { |a,b| a.index <=> b.index }

    ## Append empty interfaces for the ones that don't exists.
    CriticalInterfaces.each do |index|
      next unless interface_hash[index].nil?
      
      ## Find the first interface that is neither internal or external.
      match = interfaceArray.select{ |i| !InterfaceHelper.is_critical_interface( i ) }
      match = match[0]

      ## Remap the first interface
      unless match.nil?
        ## Update the interface hash in case it is used later.
        interface_hash[match.index] = nil
        interface_hash[index] = match

        match.index = index
        match.name = InterfaceHelper.get_interface_name( match )
        match.wan = ( index == ExternalIndex )
      end
      
      if ( interface_hash[index].nil? )
        i = Interface.new( :os_name => Interface::Unmapped, :vendor => "n/a" )
        i.index = index
        i.name = InterfaceHelper.get_interface_name( i )
        i.wan = ( i.index == ExternalIndex )
        interfaceArray << i
      end
    end

    ## Sort the interface array by index.
    interfaceArray.sort! { |a,b| a.index <=> b.index }

    interfaceArray
  end

  def self.networkManager
    Alpaca::OS.current_os["network_manager"]
  end

  def self.is_critical_interface( interface )
    CriticalInterfaces.include?( interface.index )
  end

  class IPNetworkTableModel < Alpaca::Table::TableModel
    def initialize( table_name="IP Addresses" )
      if table_name.nil?
        table_name = "IP Addresses"
      end
      columns = []
      columns << Alpaca::Table::Column.new( "ip-network", "Address and Netmask".t ) do |ip_network,options|
        row_id = options[:row_id]
        view = options[:view]
<<EOF
        #{view.hidden_field_tag( "networkIndices[]", row_id )}
        #{view.text_field( "networks", options[:row_id], { :value => "#{ip_network.ip} / #{ip_network.netmask}" } )}
EOF
      end

      columns << Alpaca::Table::DeleteColumn.new
      
      super(  table_name, "ip_networks", "", "ip_network", columns )
    end

    def row_id( row )
      "row-#{rand( 0x100000000 )}"
    end

    def action( table_data, view )
      <<EOF
<div onclick="#{view.remote_function( :url => { :action => :create_ip_network, :list_id => table_data.css_id } )}" class="add-button">
  #{"Add".t}
</div>
EOF
    end
  end

  def ip_network_table_model(table_name="IP Addresses")
    IPNetworkTableModel.new(table_name)
  end

  class NatTableModel < Alpaca::Table::TableModel
    include Singleton

    def initialize
      columns = []
      columns << Alpaca::Table::Column.new( "ip-address", "Address and Netmask".t ) do |nat,options|
        row_id = options[:row_id]
        view = options[:view]
<<EOF
        #{view.hidden_field_tag( "natIndices[]", row_id )}
        #{view.text_field( "natNetworks", options[:row_id], { :value => "#{nat.ip} / #{nat.netmask}" } )}
EOF
      end
      
      columns << Alpaca::Table::Column.new( "new-source", "Source Address".t ) do |nat,options| 
        options[:view].text_field( "natNewSources", options[:row_id], { :value => "#{nat.new_source}" } )
      end

      columns << Alpaca::Table::DeleteColumn.new
      
      super(  "NAT Policies", "nats", "", "nat", columns )
    end

    def row_id( row )
      "row-#{rand( 0x100000000 )}"
    end

    def action( table_data, view )
      <<EOF
<div onclick="#{view.remote_function( :url => { :action => :create_nat_policy, :list_id => table_data.css_id } )}" class="add-button">
  #{"Add".t}
</div>
EOF
    end
  end

  def nat_table_model
    NatTableModel.instance
  end

  def ethernet_media_select( interface )
    media = "#{interface.speed}#{interface.duplex}"
    media = "autoauto" if EthernetMedia.get_value(media).nil?

    options = EthernetMedia.order.map { |m| [ m.name, m.key ] }

    select_tag( "ethernet_media", options_for_select( options, media ), :id => "ethernet_media_select")
  end

  ## Given a ethernet media string, this will return the speed and duplex setting
  def self.get_speed_duplex( media )
    v = EthernetMedia.get_value( media )
    v = EthernetMedia.order[0] if v.nil?
    [ v[:speed], v[:duplex]]
  end

  ## Given an interface, set the name the interface should have.
  def self.get_interface_name( interface )
    index = interface.index.to_i

    case interface.index
    when ExternalIndex then ExternalName
    when InternalIndex then InternalName
    when DmzIndex then DmzName
    else interface.os_name
    end
  end
end
