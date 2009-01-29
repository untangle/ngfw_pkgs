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
class NetworkController < ApplicationController
  UpdateInterfaces = "update_interfaces"

  def get_settings
    ## Cannot use this panel in advanced mode.
    if ( @config_level > AlpacaSettings::Level::Basic )
      return json_error( "Currently in advanced mode." )
    end
    
    interface_list = Interface.find( :all )

    if ( interface_list.nil? || interface_list.empty? )
      interface_list = InterfaceHelper.loadInterfaces
      ## Save all of the new interfaces
      interface_list.each { |interface| interface.save }      
    end
    
    interface_list.sort! { |a,b| a.index <=> b.index }
    
    settings = {}
    settings["config_list"] = interface_list.map do |interface|
      ## This is the dhcp status of this particular interface.
      d = nil

      ## XXXX MULTIWAN (not really this is basic mode) XXXX
      if interface.wan
        d = os["dhcp_manager"].get_dhcp_status( interface )
        settings["dhcp_status"] = d
      end
      
      NetworkHelper.build_interface_config( interface, interface_list, d )
    end

    json_result( :values => settings )
  end

  def set_settings
    s = json_params

    ## Retrieve all of the interfaces
    config_list = s["config_list"]
    
    ## Verify the list lines up with the existing interfaces
    interfaces = Interface.find( :all )

    ## Verify the list matches.
    if ( interfaces.size != config_list.size )
      return json_error( "Number of submitted interfaces does not match number of configured interfaces." )
    end

    interface_map = {}
    interfaces = interfaces.each{ |interface| interface_map[interface.id] = interface }
    
    ## Verify every id is represented
    config_list.each do |config|
      if interface_map[config["interface"]["id"]].nil?
          return json_error( "Submitted request does not configure every known interface." )
      end

      unless InterfaceHelper::CONFIGTYPES.include?( config["interface"]["config_type"] )
        return json_error( "Invalid configuration type #{config["interface"]["config_type"]}" )
      end
    end

    ## This is where it gets a little hairy, because it should verify all
    ## interfaces, and then save, for now it is saving interfaces as it goes.
    config_list.each do |config|
      interface_config = config["interface"]
      interface = interface_map[interface_config["id"]]
      case interface_config["config_type"]
      when InterfaceHelper::ConfigType::STATIC then static_v2( interface, config )
      when InterfaceHelper::ConfigType::DYNAMIC then dynamic_v2( interface, config )
      when InterfaceHelper::ConfigType::BRIDGE then bridge_v2( interface, config )
      when InterfaceHelper::ConfigType::PPPOE then pppoe_v2( interface, config )
        ## This is redundant
      else return json_error( "Unknown configuration type #{config_type}" )
      end      
    end

    spawn do
      os["network_manager"].commit
    end
    
    json_result
  end
  
  def index
    if ( @config_level > AlpacaSettings::Level::Basic )
      return redirect_to( :controller => 'interface', :action => 'e_list' )
    end

    extjs
  end
  
  def get_aliases
    ## Index is a reserved word, so the column name must be quoted.
    conditions = [ "\"index\" = ?", InterfaceHelper::ExternalIndex ]
    external_interface = Interface.find( :first, :conditions => conditions )
    
    if external_interface
      external_aliases, msg = external_interface.visit_config( AliasVisitor.new )
      unless msg.nil?
        return json_error( msg )
      end
    else 
      return json_error( "There presently isn't an external interface." )
    end

    external_aliases = [] if external_aliases.nil?
    external_aliases = external_aliases.map { |ea| { "network_string" => "#{ea.ip} / #{ea.netmask}" }}
    
    json_result( :values => { "external_aliases" => external_aliases })
  end

  def set_aliases
    s = json_params

    ## Index is a reserved word, so the column name must be quoted.
    conditions = [ "\"index\" = ?", InterfaceHelper::ExternalIndex ]
    external_interface = Interface.find( :first, :conditions => conditions )

    if external_interface.nil?
      return json_error( "Unable to find external interface." )
    end

    current_config = external_interface.current_config
    
    static = external_interface.intf_static
    if static.nil?
      static = IntfStatic.new 
      external_interface.intf_static = static
    end      
    
    dynamic = external_interface.intf_dynamic
    if dynamic.nil?
      dynamic = IntfDynamic.new 
      external_interface.intf_dynamic = dynamic
    end
    
    pppoe = external_interface.intf_pppoe
    if pppoe.nil?
      pppoe = IntfPppoe.new 
      external_interface.intf_pppoe = pppoe
    end
    
    aliasVisitor = SaveAliasesVisitorV2.new( s["external_aliases"] )
    [ static, dynamic, pppoe ].each do |config|
      msg = config.accept( external_interface, aliasVisitor )
      if ( current_config == config and !msg.nil? )
        return json_error( msg )
      end
      config.save
    end

    external_interface.save

    spawn do
      os["network_manager"].commit
    end
    
    json_result
  end

  alias_method :e_aliases, :extjs


  ## Basic mode networking configuration
  def manage
    ## Cannot use this panel in advanced mode.
    if ( @config_level > AlpacaSettings::Level::Basic )
      return redirect_to( :controller => 'interface', :action => 'list' )
    end
    
    @interface_list = Interface.find( :all )

    if ( @interface_list.nil? || @interface_list.empty? )
      @interface_list = InterfaceHelper.loadInterfaces
      ## Save all of the new interfaces
      @interface_list.each { |interface| interface.save }      
    end
    
    @interface_list.sort! { |a,b| a.index <=> b.index }
    
    @config_list = @interface_list.map do |interface|
      ## This is the dhcp status of this particular interface.
      d = nil
      d = @dhcp_status = os["dhcp_manager"].get_dhcp_status( interface ) if interface.wan
      
      NetworkHelper.build_interface_config( interface, @interface_list, d )
    end

    ## This should be in a global place
    @cidr_options = OSLibrary::NetworkManager::CIDR.map { |k,v| [ format( "%-3s &nbsp; %s", k, v ) , k ] }
    @cidr_options.sort! { |a,b| a[1].to_i <=> b[1].to_i }


    if ! Interface.valid_dhcp_server?
      flash[:warning] = "DHCP Server is configured on a subnet that is not on any configured interfaces."
    end
    session[:last_controller_before_refresh] = "network"

  end

  def save
    return redirect_to( :action => 'manage' ) unless ( params[:commit] == "Save" )
    
    ## Retrieve all of the interfaces
    interface_list = params[:interface_list]

    interface_id_list = params[:interface_id_list]

    ## Convert the interface ids to numbers
    interface_id_list = interface_id_list.map do |interface_id|
      i = interface_id.to_i
      if i.to_s != interface_id
          flash[:error] = "Invalid interface id not found."
          return redirect_to( :action => 'manage' ) 
      end
      i
    end

    ## Verify the list exists.
    if interface_list.nil?
        flash[:error] = "Invalid parameters, interface list missing."
        return redirect_to( :action => 'manage' ) 
    end
    
    ## Verify the list lines up with the existing interfaces
    interfaces = Interface.find( :all )

    ## Verify the list matches.
    if ( interfaces.size != interface_list.size )
        flash[:error] = "Number of submitted interfaces does not match number of configured interfaces."
        return redirect_to( :action => 'manage' )
    end

    interface_map = {}
    interfaces = interfaces.each{ |interface| interface_map[interface.id] = interface }
    
    ## Verify every id is represented
    interface_id_list.each do |interface_id|
      if interface_map[interface_id].nil?
          flash[:error] = "Submitted request does not configure every known interface."
          return redirect_to( :action => 'manage' ) 
      end
    end

    ## This is where it gets a little hairy, because it should verify all
    ## interfaces, and then save, for now it is saving interfaces as it goes.
    [ interface_list, interface_id_list ].transpose.each do |panel_id, interface_id| 
      config_type = params["config_type_#{panel_id}"]

      interface = interface_map[interface_id]

      case config_type
      when InterfaceHelper::ConfigType::STATIC then static( interface, panel_id )
      when InterfaceHelper::ConfigType::DYNAMIC then dynamic( interface, panel_id )
      when InterfaceHelper::ConfigType::BRIDGE then bridge( interface, panel_id )
      when InterfaceHelper::ConfigType::PPPOE then pppoe( interface, panel_id )
      ## REVIEW : Move this into the validation part
      else raise "Unknown configuration type #{config_type}"  
      end
    end

    spawn do
      os["network_manager"].commit
    end

    return redirect_to( :action => 'manage' )
  end

  def commit
    spawn do
      os["network_manager"].commit
    end
    return redirect_to( :action => 'manage' )
  end

  ## These are the aliases for the external interface.
  def aliases
    ## Index is a reserved word, so the column name must be quoted.
    conditions = [ "\"index\" = ?", InterfaceHelper::ExternalIndex ]
    external_interface = Interface.find( :first, :conditions => conditions )
    
    if external_interface
      @external_aliases, @msg = external_interface.visit_config( AliasVisitor.new )
    else 
      @external_aliases = []
      @msg = "There presently isn't an external interface."
    end

    @external_aliases = [] if @external_aliases.nil?
    
    logger.debug( "Found the aliases: '#{@external_aliases}'" )
    @external_aliases.each { |a| logger.debug( "Found the aliases: '#{a}'" ) }
  end

  def create_ip_network
    @list_id = params[:list_id]
    raise "no row id" if @list_id.nil?
    raise "invalid list id  #{@list_id} syntax" if @list_id != "external-aliases"

    ## Review : How to set defaults
    @ip_network = IpNetwork.new
    @ip_network.ip = "1.2.3.4"
    @ip_network.netmask = "24"
    @ip_network.allow_ping = true
  end

  def save_aliases
    return redirect_to( :action => 'aliases' ) unless ( params[:commit] == "Save" )

    ## Index is a reserved word, so the column name must be quoted.
    conditions = [ "\"index\" = ?", InterfaceHelper::ExternalIndex ]
    external_interface = Interface.find( :first, :conditions => conditions )
    
    @msg = nil
    if external_interface
      current_config = external_interface.current_config

      static = external_interface.intf_static
      if static.nil?
        static = IntfStatic.new 
        external_interface.intf_static = static
      end      

      dynamic = external_interface.intf_dynamic
      if dynamic.nil?
        dynamic = IntfDynamic.new 
        external_interface.intf_dynamic = dynamic
      end

      pppoe = external_interface.intf_pppoe
      if pppoe.nil?
        pppoe = IntfPppoe.new 
        external_interface.intf_pppoe = pppoe
      end
      
      aliasVisitor = SaveAliasesVisitor.new( params )
      [ static, dynamic, pppoe ].each do |config|
        msg = config.accept( external_interface, aliasVisitor )
        @msg = msg if ( current_config == config )
      end
    else 
      @msg = "There presently isn't an external interface."
    end
    
    ## Show the error page unless the message is non-nil.
    return unless @msg.nil?
    
    spawn do
      os["network_manager"].commit
    end

    return redirect_to( :action => 'aliases' )
  end

  def refresh_interfaces
    @new_interfaces, @deleted_interfaces = InterfaceHelper.load_new_interfaces
    @last_controller = "network"
    if ! session[:last_controller_before_refresh].nil? && session[:last_controller_before_refresh].length > 0
        @last_controller = session[:last_controller_before_refresh]
    end
  end

  def commit_interfaces
    ## Ignore if they hit cancel
    return redirect_to( :action => 'manage' ) unless ( params[:commit] == "Save" )
    
    new_interfaces, deleted_interfaces = InterfaceHelper.load_new_interfaces

    new_interface_list = params[:new_interfaces]
    deleted_interface_list = params[:deleted_interfaces]

    new_interface_list = [] if new_interface_list.nil?
    deleted_interface_list = [] if deleted_interface_list.nil?

    if ( new_interface_list.size != new_interfaces.size || 
         deleted_interface_list.size != deleted_interfaces.size )
      return redirect_to( :action => 'refresh_interfaces' ) 
    end

    ## Verify that the new and deleted interfaces line up.
    ma = {}
    new_interface_list.each { |i| ma[i] = true }
    logger.debug( "ma : #{ma}" )
    new_interfaces.each do |i|
      return redirect_to( :action => 'refresh_interfaces' )  unless ma[i.mac_address] == true
    end

    ma = {}
    logger.debug( "ma : #{ma}" )
    deleted_interface_list.each { |i| ma[i] = true }
    deleted_interfaces.each do |i|
      return redirect_to( :action => 'refresh_interfaces' )  unless ma[i.mac_address] == true
    end
    
    ## Destroy the interfaces to be deleted.
    deleted_interfaces.each do |i| 
      if ( InterfaceHelper.is_critical_interface( i ))
        ## Critical interfaces are not deleted, they are just set to the no-interface
        i.os_name, i.mac_address, i.bus, i.vendor = Interface::Unmapped, "", "", "n/a"
        i.save
      else
        i.destroy
      end
    end

    ## This is the array of critical interfaces that haven't been assigned to a phyiscal interface
    conditions =  [ "os_name = ?", Interface::Unmapped ]
    unmapped_interfaces = Interface.find( :all, :conditions => conditions )
    
    ## Create the new interfaces
    new_interfaces.each do |i|
      unless unmapped_interfaces.empty?
        ## Map the first unmapped interface
        ui = unmapped_interfaces.delete_at( 0 )
        ui.os_name, ui.mac_address, ui.bus, ui.vendor = i.os_name, i.mac_address, i.bus, i.vendor
        ui.save
      else
        ## Otherwise just create a new interface.
        i.save
      end
    end
    
    ## Iterate all of the helpers telling them about the new interfaces
    iterate_components do |component|
      next unless component.respond_to?( UpdateInterfaces )
      component.send( UpdateInterfaces, Interface.find( :all ))
    end

    ## Redirect them to the manage page.
    return redirect_to( :action => 'manage' )
  end

  private

  class AliasVisitor < Interface::ConfigVisitor
    def intf_static( interface, config )
      ## Create a copy of the array.
      aliases = [ config.ip_networks ].flatten

      ## Delete the alias at the first position from the list
      aliases.delete_if { |a| a.position == 1 }
      [ aliases, nil ]
    end

    def intf_dynamic( interface, config )
      [ config.ip_networks, nil ]
    end

    def intf_bridge( interface, config )
      [ [], "External Interface is presently configured as a bridge" ]
    end

    def intf_pppoe( interface, config )
      ## Review : We currently support this.
      [ config.ip_networks, nil ]
    end
  end

  class SaveAliasesVisitor < Interface::ConfigVisitor
    def initialize( params )
      @params = params
    end

    def intf_static( interface, config )
      ## Create the ip_network list, starting with position 2
      ip_networks = ip_network_list( 2 )
      external = config.ip_networks[0]
      if external.nil?
        config.ip_networks = ip_networks
      else
        ## Put it at the beginning
        config.ip_networks = [ external ] + ip_networks 
      end
      
      nil
    end

    def intf_dynamic( interface, config )
      config.ip_networks = ip_network_list( 1 )

      nil
    end

    def intf_bridge( interface, config )
      "External Interface is presently configured as a bridge"
    end

    def intf_pppoe( interface, config )
      config.ip_networks = ip_network_list( 1 )
      nil
    end

    private
    def ip_network_list( position )
      ## save the networks
      networkStringHash = @params[:networks]
      ## indices is used to guarantee they are done in proper order.
      indices = @params[:networkIndices]
      
      ip_networks = []
      unless indices.nil?
        indices.each do |key,value|
          network = IpNetwork.new
          network.parseNetwork( networkStringHash[key] )
          network.position, position = position, position + 1
          ip_networks << network
        end
      end
      
      ip_networks
    end
  end

  class SaveAliasesVisitorV2 < Interface::ConfigVisitor
    def initialize( external_aliases )
      @external_aliases = external_aliases
    end

    def intf_static( interface, config )
      ## Create the ip_network list, starting with position 2
      ip_networks = ip_network_list( 2 )
      external = config.ip_networks[0]
      if external.nil?
        config.ip_networks = ip_networks
      else
        ## Put it at the beginning
        config.ip_networks = [ external ] + ip_networks 
      end
      
      nil
    end

    def intf_dynamic( interface, config )
      config.ip_networks = ip_network_list( 1 )

      nil
    end

    def intf_bridge( interface, config )
      "External Interface is presently configured as a bridge"
    end

    def intf_pppoe( interface, config )
      config.ip_networks = ip_network_list( 1 )
      nil
    end

    private
    def ip_network_list( position )
      @external_aliases.map do |ea|
          network = IpNetwork.new
          network.parseNetwork( ea["network_string"] )
          network.position, position = position, position + 1
          network
      end
    end
  end


  def static( interface, panel_id )
    static = interface.intf_static
    static = IntfStatic.new if static.nil?
    
    network = static.ip_networks[0]

    ## There isn't a first one, need to create a new one
    if network.nil?
      network = IpNetwork.new( :allow_ping => true, :position => 1 )
      network.parseNetwork( "#{params["#{panel_id}_static_ip"]}/#{params["#{panel_id}_static_netmask"]}" )
      static.ip_networks = [ network ]
    elsif ( network.position == 1 )
      ## Replace the one that is there
      network.ip = params["#{panel_id}_static_ip"]
      network.netmask = params["#{panel_id}_static_netmask"]
      network.allow_ping = true
      network.save
    else
      ## The first one doesn't exist, need to insert one at the beginning
      network = IpNetwork.new( :allow_ping => true, :position => 1 )
      network.parseNetwork( "#{params["#{panel_id}_static_ip"]}/#{params["#{panel_id}_static_netmask"]}" )
      static.ip_networks << network
    end
    
    if interface.wan
      ## Set the default gateway and dns
      static.default_gateway = params["#{panel_id}_static_default_gateway"]
      static.dns_1 = params["#{panel_id}_static_dns_1"]
      static.dns_2 = params["#{panel_id}_static_dns_2"]
    else
      ## Add a NAT policy (this not the external interface)
      natPolicy = NatPolicy.new
      natPolicy.ip = "0.0.0.0"
      natPolicy.netmask = "0"
      natPolicy.new_source = "auto"
      static.nat_policies = [ natPolicy ]
    end

    static.save
    interface.config_type = InterfaceHelper::ConfigType::STATIC
    interface.intf_static = static
    interface.save
  end

  def bridge( interface, panel_id )
    bridge = interface.intf_bridge
    bridge = IntfBridge.new if bridge.nil?

    bridge_id = params["#{panel_id}_bridge_interface"]
    return logger.warn( "Bridge interface is not specified" ) if bridge_id.nil?

    bridge_interface = Interface.find( bridge_id )
    return logger.warn( "Unable to find the interface '#{bridge_id}'" ) if bridge_interface.nil?

    bridge.bridge_interface = bridge_interface
    bridge_interface.bridged_interfaces << bridge
    
    interface.intf_bridge = bridge
    interface.config_type = InterfaceHelper::ConfigType::BRIDGE
    interface.save
  end

  def dynamic( interface, panel_id )
    dynamic = interface.intf_dynamic
    dynamic = IntfDynamic.new if dynamic.nil?
    dynamic.allow_ping = true

    dynamic.ip = nil
    dynamic.netmask = nil
    dynamic.default_gateway = nil
    dynamic.dns_1 = nil
    dynamic.dns_2 = nil

    dynamic.save
    interface.config_type = InterfaceHelper::ConfigType::DYNAMIC
    interface.intf_dynamic = dynamic
    interface.save    
  end

  def pppoe( interface, panel_id )
    pppoe = interface.intf_pppoe
    pppoe = IntfPppoe.new if pppoe.nil?
    pppoe.username = params["#{panel_id}_pppoe_username"]
    pppoe.password = params["#{panel_id}_pppoe_password"]
    pppoe.use_peer_dns = params["#{panel_id}_pppoe_use_peer_dns"]
    pppoe.dns_1 = params["#{panel_id}_pppoe_dns_1"]
    pppoe.dns_2 = params["#{panel_id}_pppoe_dns_2"]
    pppoe.save
    interface.config_type = InterfaceHelper::ConfigType::PPPOE
    interface.intf_pppoe = pppoe
    interface.save
  end

  def static_v2( interface, config )
    static = interface.intf_static
    static = IntfStatic.new if static.nil?

    static_config = config["static"]
    
    network = static.ip_networks[0]

    ## There isn't a first one, need to create a new one
    if network.nil?
      network = IpNetwork.new( :allow_ping => true, :position => 1 )
      network.parseNetwork( "#{static_config["ip"]}/#{static_config["netmask"]}" )
      static.ip_networks = [ network ]
    elsif ( network.position == 1 )
      ## Replace the one that is there
      network.ip = static_config["ip"]
      network.netmask = static_config["netmask"]
      network.allow_ping = true
      network.save
    else
      ## The first one doesn't exist, need to insert one at the beginning
      network = IpNetwork.new( :allow_ping => true, :position => 1 )
      network.parseNetwork( "#{static_config["ip"]}/#{static_config["netmask"]}" )
      static.ip_networks << network
    end
    
    if interface.wan
      ## Set the default gateway and dns
      static.default_gateway = static_config["default_gateway"]
      static.dns_1 = static_config["dns_1"]
      static.dns_2 = static_config["dns_2"]
    else
      ## Add a NAT policy (this not the external interface)
      natPolicy = NatPolicy.new
      natPolicy.ip = "0.0.0.0"
      natPolicy.netmask = "0"
      natPolicy.new_source = "auto"
      static.nat_policies = [ natPolicy ]
    end

    static.save
    interface.config_type = InterfaceHelper::ConfigType::STATIC
    interface.intf_static = static
    interface.save
  end

  def bridge_v2( interface, config )
    bridge = interface.intf_bridge
    bridge = IntfBridge.new if bridge.nil?

    bridge_id = config["bridge"]
    return logger.warn( "Bridge interface is not specified" ) if bridge_id.nil?

    bridge_interface = Interface.find( :first, :conditions => [ "id = ?", bridge_id ] )
    return logger.warn( "Unable to find the interface '#{bridge_id}'" ) if bridge_interface.nil?

    bridge.bridge_interface = bridge_interface
    bridge_interface.bridged_interfaces << bridge
    
    interface.intf_bridge = bridge
    interface.config_type = InterfaceHelper::ConfigType::BRIDGE
    interface.save
  end

  def dynamic_v2( interface, config )
    dynamic = interface.intf_dynamic
    dynamic = IntfDynamic.new if dynamic.nil?
    dynamic.allow_ping = true

    dynamic.ip = nil
    dynamic.netmask = nil
    dynamic.default_gateway = nil
    dynamic.dns_1 = nil
    dynamic.dns_2 = nil

    dynamic.save
    interface.config_type = InterfaceHelper::ConfigType::DYNAMIC
    interface.intf_dynamic = dynamic
    interface.save    
  end

  def pppoe_v2( interface, config )
    pppoe_config = config["pppoe"]

    pppoe = interface.intf_pppoe
    pppoe = IntfPppoe.new if pppoe.nil?
    pppoe.username = pppoe_config["username"]
    pppoe.password = pppoe_config["password"]
    pppoe.use_peer_dns = pppoe_config["use_peer_dns"]
    pppoe.dns_1 = pppoe_config["dns_1"]
    pppoe.dns_2 = pppoe_config["dns_2"]
    pppoe.save

    interface.config_type = InterfaceHelper::ConfigType::PPPOE
    interface.intf_pppoe = pppoe
    interface.save
  end
end
