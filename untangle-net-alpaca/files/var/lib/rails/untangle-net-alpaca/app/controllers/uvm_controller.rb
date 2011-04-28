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
class UvmController < ApplicationController  
  DnsServerSettingsDefaults = { :suffix => "example.com", :enabled => true }

  def get_settings
    settings = {}

    settings["user_subscriptions"] = Subscription.find( :all, :conditions => [ "system_id IS NULL" ] )
    settings["system_subscriptions"] = Subscription.find( :all, :conditions => [ "system_id IS NOT NULL" ] )
    
    alpaca_settings = AlpacaSettings.find( :first )
    alpaca_settings = AlpacaSettings.new if alpaca_settings.nil?
    modules_disabled = alpaca_settings.modules_disabled
    modules_disabled = "" if modules_disabled.nil?
    settings["enable_sip_helper"] = !modules_disabled.include?( "nf_nat_sip" )

    ## Interface enumeration
    settings["interface_enum"] = build_interface_enum()
    
    json_result( :values => settings )
  end

  def set_settings
    s = json_params
    
    ## Only update if these changes are inserted.
    unless ( s["uvm"].nil? )
      uvm_settings = UvmSettings.find( :first )
      uvm_settings = UvmSettings.new if uvm_settings.nil?
      uvm_settings.update_attributes( s["uvm"] )
      uvm_settings.save
    end

    ## Destroy all of the user rules
    Subscription.destroy_all( "system_id IS NULL" )
    position = 0
    s["user_subscriptions"].each do |entry|
      rule = Subscription.new( entry )
      rule.position = position
      rule.save
      position += 1
    end
    
    s["system_subscriptions"].each do |entry|
      rule = Subscription.find( :first, :conditions => [ "system_id = ?", entry["system_id"]] )
      next if rule.nil?
      rule.enabled = entry["enabled"]
      rule.save
    end
    
    ## Commit all of the packet filter rules.
    os["packet_filter_manager"].commit
    
    json_result
  end

  alias_method :index, :extjs

  def generate_rules
    ## Execute all of the packet filter rules.
    os["packet_filter_manager"].run_services
    json_result
  end

  ## Remap the interfaces
  def remap_interfaces
    s = json_params
    os_names, user_names = s["os_names"], s["user_names"]

    os_names = os_names.map { |i| i.sub( "ppp.", "" )}

    raise "os and user array must be the same size" if ( os_names.length != user_names.length ) 
    
    interface_array = Interface.find( :all )
    raise "Missing interfaces" if ( interface_array.length != os_names.length )
    
    physical_data = {}
    is_modified = false
    interface_array.each do |i|
      os_index = os_names.index( i.os_name )
      user_index = user_names.index( i.name )

      raise "Missing the interface: #{i.name}" if user_index.nil?
      raise "Missing the interface: #{i.os_name}" if os_index.nil?
      
      if ( user_index != os_index ) 
        is_modified = true
        name = user_names[os_index]
        physical_data[name] = [ i.os_name, i.mac_address, i.bus, i.vendor ]
      end
    end
      
    ## Nothing to do if the interfaces are not modified.
    unless is_modified
      logger.debug( "Interfaces are not modified" ) 
      return json_result
    end

    user_names.each do |name|
      data = physical_data[name]
      next if data.nil?
      
      i = Interface.find( :first, :conditions => [ "name = ?", name ] )
      i.os_name, i.mac_address, i.bus, i.vendor = data
      ## Delete all non-critical unmapped interfaces.
      unless ( InterfaceHelper.is_critical_interface( i ) || i.is_mapped? )
        i.destroy
      else
        i.save
      end
    end

    ## Don't call the network manager here, it is called in the next step.
    json_result
  end
  
  def write_files
    ## Load all of the interfaces if the settings haven't been initialized yet.
    if ( Interface.find( :first ).nil? )
      new_interfaces = InterfaceHelper.loadInterfaces
      new_interfaces.each { |i| i.save }
    end

    ## Write all of the configuration files for the packet filter rules
    ## This also causes the uvm manager to write a few files.
    os["packet_filter_manager"].write_files

    json_result
  end

  def session_redirect_create()
    s = json_params
    filter, new_ip, new_port = s["filter"], s["new_ip"], s["new_port"]

    logger.debug( "Creating a new session redirect: #{filter} #{new_ip} #{new_port}" )
    
    os["packet_filter_manager"].session_redirect_create( filter, new_ip, new_port )

    json_result
  end

  def session_redirect_delete
    s = json_params
    filter, new_ip, new_port = s["filter"], s["new_ip"], s["new_port"]

    logger.debug( "Deleting a new session redirect: #{filter} #{new_ip} #{new_port}" )
    os["packet_filter_manager"].session_redirect_delete( filter, new_ip, new_port )
    
    json_result
  end

  def save_hostname
    s = json_params
    hostname, save_suffix = s["hostname"], s["suffix"]

    logger.debug( "Saving the hostname: '#{hostname}'" )

    hostname_settings = HostnameSettings.find( :first )
    hostname_settings = HostnameSettings.new if hostname_settings.nil?

    hostname_settings.hostname = hostname
    hostname_settings.save

    ## Update the domain name suffix (only if the hostname is qualified.)
    if save_suffix && !( /^[^\.]+\.[^\.]+/.match( hostname ).nil? )
      suffix = hostname.sub( /^[^\.]*\./, "" )
      update_dns_server_settings( :suffix => suffix )
    end
    
    os["hostname_manager"].commit

    json_result
  end

  #
  # Called by NetworkManagerImpl
  # Used to fetch QoS Settings (for Bandwidth Control)
  #
  def get_qos_settings
    qos_settings = QosSettings.find( :first )
    json_result(:values => qos_settings)
  end

  def enable_qos
    qos_settings = QosSettings.find( :first )
    qos_settings.enabled = true
    qos_settings.save

    os["qos_manager"].commit

    json_result
  end

  #
  # Called by NetworkManagerImpl
  # Used to fetch interface metadata (like WAN speed for Bandwidth Control)
  #
  def get_wan_interfaces
    wan_interfaces = Interface.wan_interfaces
    json_result(:values => wan_interfaces)
  end

  #
  # Called by NetworkManagerImpl
  # This is used to the UVM can set the WAN speed (for Bandwidth Control)
  #
  def set_wan_speed
    name = json_params["name"]
    download_bandwidth = json_params["download_bandwidth"]
    upload_bandwidth = json_params["upload_bandwidth"]
    if name.nil?
      raise "Missing interface name"
    end
    intf = Interface.find( :first, :conditions => [ "name = ?", name ] )
    if intf.nil?
      raise "Could not find interface: #{name}"
    end
    
    if ! download_bandwidth.nil?
      intf.download_bandwidth = download_bandwidth
    end
    if ! upload_bandwidth.nil?
      intf.upload_bandwidth = upload_bandwidth
    end

    intf.save

    json_result
  end

  ## Set the settings up as if this was for the wizard (UVM wizard not the alpaca wizard)
  def wizard_start
    interfaces = InterfaceHelper.loadInterfaces

    internal, external = nil, nil
    interfaces.each do |interface|
      case interface.index
        when InterfaceHelper::ExternalIndex then external = interface
        when InterfaceHelper::InternalIndex then internal = interface
      end
    end
    
    raise "Missing internal or external interface" if external.nil? || internal.nil?

    Interface.destroy_all
    ## Have to save them in order to get valid indices for bridging.
    interfaces.each { |interface| interface.save }

    interfaces.each do |interface|
      case interface.index
      when InterfaceHelper::ExternalIndex 
        ## Configure the external interface for DHCP
        interface.intf_dynamic = IntfDynamic.new
        interface.config_type = InterfaceHelper::ConfigType::DYNAMIC
        
      when InterfaceHelper::InternalIndex 
        ## Configure the internal interface as a static
        static = IntfStatic.new
        static.ip_networks = [ IpNetwork.new( :ip => "192.168.2.1", :netmask => "24", :position => 1 )]
        static.nat_policies = [ NatPolicy.new( :ip => "0.0.0.0", :netmask => "0", :new_source => "auto" )]
        interface.intf_static = static
        interface.config_type = InterfaceHelper::ConfigType::STATIC
      else
        ## Bridge all other interfaces with external
        bridge = IntfBridge.new
        bridge.bridge_interface = external
        external.bridged_interfaces << bridge
        interface.intf_bridge = bridge
        interface.config_type = InterfaceHelper::ConfigType::BRIDGE
      end 

      ## Save the changes to the interface
      interface.save
    end
    
    DhcpServerSettings.destroy_all
    # DHCP is off by default to avoid problems when plugging the interfaces in wrong
    DhcpServerSettings.new( :enabled => false, :start_address => "192.168.2.100", :end_address => "192.168.2.200" ).save

    os["network_manager"].commit

    json_result
  end

  def wizard_external_interface_static
    s = json_params
    ip, netmask, default_gateway, dns_1, dns_2 = s["ip"], s["netmask"], s["default_gateway"], s["dns_1"], s["dns_2"]

    if netmask.include?( "255." )
      netmask = OSLibrary::NetworkManager::CIDR.index( netmask )
    end
    wizard_manage_interface( InterfaceHelper::ExternalIndex ) do |external_interface|
      static = IntfStatic.new
      static.ip_networks = [ IpNetwork.new( :ip => ip, :netmask => netmask, :position => 1 )]
      static.default_gateway, static.dns_1, static.dns_2 = default_gateway, dns_1, dns_2
      external_interface.intf_static = static
      external_interface.config_type = InterfaceHelper::ConfigType::STATIC

      update_dns_server_settings()
    end

    json_result
  end

  def wizard_external_interface_dynamic
    s = json_params

    wizard_manage_interface( InterfaceHelper::ExternalIndex ) do |external_interface|
      external_interface.intf_dynamic = IntfDynamic.new
      external_interface.config_type = InterfaceHelper::ConfigType::DYNAMIC

      update_dns_server_settings()
    end

    json_result
  end

  def wizard_external_interface_pppoe
    s = json_params
    username, password = s["username"], s["password"]

    wizard_manage_interface( InterfaceHelper::ExternalIndex ) do |external_interface|
      external_interface.intf_pppoe = IntfPppoe.new( :username => username, :password => password )
      external_interface.config_type = InterfaceHelper::ConfigType::PPPOE

      update_dns_server_settings()
    end

    json_result
  end

  def wizard_internal_interface_bridge
    wizard_manage_interface( InterfaceHelper::InternalIndex ) do |internal_interface|
      wizard_manage_interface( InterfaceHelper::ExternalIndex, false ) do |external_interface|
        bridge = IntfBridge.new
        bridge.bridge_interface = external_interface
        external_interface.bridged_interfaces << bridge
        internal_interface.intf_bridge = bridge
        internal_interface.config_type = InterfaceHelper::ConfigType::BRIDGE
      end

      ## Disable DHCP and DNS.
      DhcpServerSettings.destroy_all
      DhcpServerSettings.new( :enabled => false, :start_address => "", :end_address => "" ).save

      update_dns_server_settings( :enabled => false )
    end

    json_result
  end
    
  def wizard_internal_interface_nat
    s = json_params
    ip, netmask, is_dhcp_enabled = s["ip"], s["netmask"], s["is_dhcp_enabled"]

    if netmask.include?( "255." )
      netmask = OSLibrary::NetworkManager::CIDR.index( netmask )
    end
    
    wizard_manage_interface( InterfaceHelper::InternalIndex ) do |internal_interface|
      static = IntfStatic.new
      static.ip_networks = [ IpNetwork.new( :ip => ip, :netmask => netmask, :position => 1 )]
      static.nat_policies = [ NatPolicy.new( :ip => "0.0.0.0", :netmask => "0", :new_source => "auto" )]
      internal_interface.intf_static = static
      internal_interface.config_type = InterfaceHelper::ConfigType::STATIC

      ## Conditionally Enable DHCP and DNS
      DhcpServerSettings.destroy_all
      dhcp_server_settings = DhcpServerSettings.new
      
      wizard_calculate_dhcp_range( ip, netmask, dhcp_server_settings, is_dhcp_enabled )
      dhcp_server_settings.save
      update_dns_server_settings( :enabled => true )
    end

    json_result
  end

  def hello_world
    ## Just access the database to make sure another process doesn't have it locked.
    Interface.find( :first )
    json_result
  end

  def set_uvm_settings
    s = json_params
    alpaca_settings = AlpacaSettings.find( :first )
    alpaca_settings = AlpacaSettings.new if alpaca_settings.nil?
    alpaca_settings.language = s["language"]
    alpaca_settings.skin = s["skin"]
    alpaca_settings.save
    json_result
  end

  private
  def wizard_manage_interface( interface_index, commit = true )
    interface = Interface.find( :first, :conditions => [ "\"index\" = ?", interface_index ] )
    
    raise "Missing an interface" if interface.nil?
    yield interface

    ## Destroy all of the static entries (just safest to always do this).
    DhcpStaticEntry.destroy_all
    DnsStaticEntry.destroy_all

    interface.save
    
    ## Only commit if told to.
    os["network_manager"].commit if commit

    nil
  end
  
  def wizard_calculate_dhcp_range( ip, netmask, dhcp_server_settings, is_dhcp_enabled )
    ip = IPAddr.parse_ip( ip )
    netmask = IPAddr.parse_netmask( netmask )

    dhcp_server_settings.enabled = false
    dhcp_server_settings.start_address = "192.168.1.100"
    dhcp_server_settings.end_address = "192.168.1.200"

    ## This will only configure /24 or larger network, the logic for
    ## smaller networks is complicated and isn't really worth it.
    unless ( ip.nil? || netmask.nil? )
      start_address, end_address = nil, nil
      if (( netmask & IPAddr.parse( "0.0.0.255" )) == IPAddr.parse( "0.0.0.0" ))
        ## /24 or larger network
        mask = ip & netmask
        if (( mask | IPAddr.parse( "0.0.0.100" )).to_i > ip.to_i )
          start_address = mask | IPAddr.parse( "0.0.0.100" )
          end_address = mask | IPAddr.parse( "0.0.0.200" )
        else
          start_address = mask | IPAddr.parse( "0.0.0.16" )
          end_address = mask | IPAddr.parse( "0.0.0.99" )
        end
      end
            
      unless ( start_address.nil? || end_address.nil? )
        dhcp_server_settings.enabled = is_dhcp_enabled
        dhcp_server_settings.start_address = start_address.to_s
        dhcp_server_settings.end_address = end_address.to_s
      end
    end
  end
  
  def update_dns_server_settings( params = {} )
    dns_server_settings = DnsServerSettings.find( :first )
    dns_server_settings = DnsServerSettings.new( DnsServerSettingsDefaults ) if dns_server_settings.nil?
    unless params.nil?
      dns_server_settings.update_attributes( params )
      dns_server_settings.save
    end
  end
end
