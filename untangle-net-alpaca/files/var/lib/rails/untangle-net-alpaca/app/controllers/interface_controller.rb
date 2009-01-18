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
class InterfaceController < ApplicationController  
  def index
    list
    render :action => 'list'
  end

  def list
    @title = "Interface List"
    @description = "List of all of the available interfaces."

    @new_interfaces = []
    @deleted_interfaces = []
    
    @interfaces = Interface.find(:all)

    if ( @interfaces.nil? || @interfaces.empty? )
      @interfaces = InterfaceHelper.loadInterfaces
      ## Save all of the new interfaces
      @interfaces.each { |interface| interface.save }
    else
      @new_interfaces, @deleted_interfaces = InterfaceHelper.load_new_interfaces
    end

    @interfaces.sort! { |a,b| a.index <=> b.index }

    if ! Interface.valid_dhcp_server?
      flash[:warning] = "DHCP Server is configured on a subnet that is not on any configured interfaces."
    end
    session[:last_controller_before_refresh] = "interface"
  end

  def get_interface_list
    settings = {}
    
    new_interfaces = []
    deleted_interfaces = []

    interfaces = Interface.find( :all )
    
    if ( interfaces.nil? || interfaces.empty? )
      interfaces = InterfaceHelper.loadInterfaces
      ## Save all of the new interfaces
      interfaces.each { |interface| interface.save }
    else
      new_interfaces, deleted_interfaces = InterfaceHelper.load_new_interfaces
    end

    ## Add the current interface status to all of the interfaces
    interfaces.sort { |a,b| a.index <=> b.index }

    settings["new_interfaces"] = new_interfaces
    settings["deleted_interfaces"] = deleted_interfaces

    ## xxx so not legit, anti-legit
    settings["interfaces"] = ActiveSupport::JSON.decode( interfaces.to_json( :methods => :interface_status_v2 ))

    json_result( settings )
  end

  def set_interface_list
     s = json_params

    interface_list = s["interfaces"]
    
    interfaces = Interface.find( :all )

    ids = interfaces.collect { |i| i.id }.sort
    new_ids =interface_list.collect { |n| n["id"] }.sort
    puts "IDS: #{ids.join}"
    puts "NDS: #{new_ids.join}"
    return json_error( "Invalid interface List" ) if ( ids != new_ids )

    interface_map = {}
    interface_list.each do |n| 
      interface_map[n["id"].to_s] = [ n["os_name"], n["mac_address"], n["bus"], n["vendor"]]
    end
    
    interfaces.each do |i|
      n = interface_map[i.id.to_s]
      i.os_name, i.mac_address, i.bus, i.vendor = n

      ## Delete all non-critical unmapped interfaces.
      unless ( InterfaceHelper.is_critical_interface( i ) || i.is_mapped? )
        i.destroy
      else
        i.save
      end
    end

    ## Actually commit the changes
    spawn do
      networkManager.commit
    end
    
    json_result
  end

  alias_method :e_list, :extjs

  def get_settings
    settings = {}

    interface_id = params[:id]
    return json_error( "Invalid interface id '%s'" % ( interface_id )) if interface_id.nil?
    interface = Interface.find( interface_id )
    return json_error( "Unknown interface '%s'" % ( interface_id )) if interface.nil?

    settings["interface"] = interface
    
    static_settings = interface.intf_static
    static_settings = IntfStatic.new if static_settings.nil?
    settings["static"] = static_settings
    
    ## Retrieve the dynamic configuration, creating a new one if necessary.
    dynamic_settings = interface.intf_dynamic
    dynamic_settings = IntfDynamic.new if dynamic_settings.nil?
    settings["dynamic"] = dynamic_settings
    
    ## Retrieve the dynamic configuration, creating a new one if necessary.
    pppoe_settings = interface.intf_pppoe
    pppoe_settings = IntfPppoe.new if pppoe_settings.nil?
    settings["pppoe"] = pppoe_settings

    ## Retrieve the bridge configuration, creating a new one if necessary.
    bridge_settings = interface.intf_bridge
    bridge_settings = IntfBridge.new if bridge_settings.nil?
    settings["bridge"] = bridge_settings
        
    settings["dhcp_status"] = os["dhcp_manager"].get_dhcp_status( interface )

    cond = [ "config_type IN (?) AND id != ?" ]
    cond << InterfaceHelper::BRIDGEABLE_CONFIGTYPES
    cond << interface.id
    
    ## Create a selection map
    settings["bridgeable_interfaces"] = Interface.find( :all, :conditions => cond ).collect do |interface|
      ## XXX config_type and name will need internationalization
      [ interface.id, "#{interface.name} (#{interface.config_type})" ]
    end
    
    settings["static_aliases"] = static_settings.ip_networks
    settings["dynamic_aliases"] = dynamic_settings.ip_networks
    settings["pppoe_aliases"] = pppoe_settings.ip_networks
    settings["config_types"] = InterfaceHelper::CONFIGTYPES

    settings["media_types"] = InterfaceHelper::EthernetMedia.order.map { |m| [ m.key, m.name ] }

    media = "#{interface.speed}#{interface.duplex}"
    if InterfaceHelper::EthernetMedia.get_value( media ).nil?
      media = InterfaceHelper::EthernetMedia.get_default() 
    end

    settings["media"] = media
    
    json_result( settings )
  end

  def set_settings
    s = json_params

    interface_id = params[:id]
    return json_error( "Invalid interface id '%s'" % ( interface_id )) if interface_id.nil?
    interface = Interface.find( interface_id )
    return json_error( "Unknown interface '%s'" % ( interface_id )) if interface.nil?
    
    interface.update_attributes( s["interface"] )
    
    static_settings = interface.intf_static
    static_settings = IntfStatic.new if static_settings.nil?
    static_settings.update_attributes( s["static"] )
    
    ## Retrieve the dynamic configuration, creating a new one if necessary.
    dynamic_settings = interface.intf_dynamic
    dynamic_settings = IntfDynamic.new if dynamic_settings.nil?
    dynamic_settings.update_attributes( s["dynamic"] )    
    
    ## Retrieve the dynamic configuration, creating a new one if necessary.
    pppoe_settings = interface.intf_pppoe
    pppoe_settings = IntfPppoe.new if pppoe_settings.nil?
    pppoe_settings.update_attributes( s["pppoe"] )

    ## Retrieve the bridge configuration, creating a new one if necessary.
    bridge_settings = interface.intf_bridge
    bridge_settings = IntfBridge.new if bridge_settings.nil?
    bridge_settings.update_attributes( s["bridge"] )
            
    static_settings.ip_networks = create_ip_networks( s["static_aliases"] )
    dynamic_settings.ip_networks = create_ip_networks( s["dynamic_aliases"] )
    pppoe_settings.ip_networks = create_ip_networks( s["pppoe_aliases"] )

    static_settings.save
    dynamic_settings.save
    pppoe_settings.save

    interface.intf_static = static_settings
    interface.intf_dynamic = dynamic_settings
    interface.intf_pppoe = pppoe_settings
    
    interface.save

    spawn { networkManager.commit }
    
    json_result
  end

  alias_method :e_config, :extjs

  def config
    load_config do
      @title = "Interface Configuration"
      
      ## Retrieve the static configuration, creating a new one if necessary.
      static

      ## Retrieve the dynamic configuration, creating a new one if necessary.
      dynamic

      ## Retrieve the bridge configuration, creating a new one if necessary.
      bridge

      ## Retrieve the pppoe configuration, creating a new one if necessary.
      pppoe

      @config_type_id = @interface.config_type

      @config_types = InterfaceHelper::CONFIGTYPES.map { |type| [ type, type ] }

      @hide_types = InterfaceHelper::CONFIGTYPES.dup
      @hide_types.delete( @interface.config_type )
    end
  end

  ## Rewire the interfaces.
  def intf_order_save
    ## Nothing to do on cancel
    return redirect_to( :action => 'list' ) if ( params[:commit] == "Cancel" )
    
    ## These are the original values
    original = params[:interfaceOrigList]

    ## This is the new mapping
    order = params[:interfaceOrderList]
    
    ## nothing to do if the two lists are identical
    # REVIEW : Should this force a commit regardless of whether or not they are the same
    return redirect_to( :action => 'list' ) if original == order

    ## Easy check if the sizes are different
    ## xxx needs some error messaging here
    return redirect_to( :action => 'list' ) unless original.sort == order.sort

    ## Check that all items are uniq (these two checks guarantees both are uniq.)
    ## xxx needs some error messaging here
    return redirect_to( :action => 'list' ) unless original.uniq.size == original.size
    
    ## Get all of the interfaces
    interfaces = Interface.find( :all )

    ## used to test the lists have all of the ids
    ids = interfaces.collect { |i| i.id }.sort

    ## make sure they have all of the interfaces (inefficient call of sort twice, but lists are small)
    ## xxx needs some error messaging here
    return redirect_to( :action => 'list' ) unless original.sort != ids
    
    ## now actually do the remapping
    ## copy out the stuff that is moved.
    physicalData = {}
    interfaces.each { |i| physicalData[i.id.to_s] = [ i.os_name, i.mac_address, i.bus, i.vendor ] }
    
    ## xxx this should definitely be a transaction
    [ original, order ].transpose.each do |original_id,order_id|
      i = Interface.find( original_id )
      logger.debug( "Remapping #{i} to #{physicalData[order_id]}" )
      i.os_name, i.mac_address, i.bus, i.vendor = physicalData[order_id]

      ## Delete all non-critical unmapped interfaces.
      unless ( InterfaceHelper.is_critical_interface( i ) || i.is_mapped? )
        i.destroy
      else
        i.save
      end
    end

    ## Actually commit the changes
    spawn do
      networkManager.commit
    end
    
    return redirect_to( :action => 'list' )
  end

  def intf_save_director
    return redirect_to( :action => 'list' ) if ( params[:commit] == "Cancel" )
    
    if params[:config_type] == "static"
      intf_static_save
    elsif params[:config_type] == "dynamic"
      intf_dynamic_save
    elsif params[:config_type] == "bridge"
      intf_bridge_save
    elsif params[:config_type] == "pppoe"
      intf_pppoe_save
    end 
  end

  def intf_static_save
    save do
      ## Get the static interface
      static = @interface.intf_static
      
      ## Create a new one if it is nil
      static = IntfStatic.new if static.nil?
      
      ## save the networks
      networkStringHash = params[:networks]
      ## indices is used to guarantee they are done in proper order.
      indices = params[:networkIndices]
      
      ## clear out all of the ip networks.
      static.ip_networks = []
      position = 1
      unless indices.nil?
        indices.each do |key,value|
          network = IpNetwork.new
          network.parseNetwork( networkStringHash[key] )
          network.position, position = position, position + 1
          static.ip_networks << network
        end
      end
      
      ## save the nat policies
      natNetworkHash = params[:natNetworks]
      natNewSourceHash = params[:natNewSources]
      
      ## indices is used to guarantee they are done in proper order.
      indices = params[:natIndices]
      
      ## Delete all of the nat policies
      static.nat_policies = []
      
      position = 1
      unless indices.nil?
        indices.each do |key|
          natPolicy = NatPolicy.new
          logger.debug( "index: #{key}" )
          natPolicy.parseNetwork( natNetworkHash[key] )
          natPolicy.new_source = natNewSourceHash[key]
          natPolicy.position, position = position, position + 1
          static.nat_policies << natPolicy
        end
      end
      
      static.update_attributes(params[:static])
      
      static.save
      
      @interface.intf_static = static
      @interface.config_type = InterfaceHelper::ConfigType::STATIC
      @interface.save
      
      ## Actually commit the changes
      spawn do
        networkManager.commit
      end
      
      ## Indicate the command was successful
      true
    end
  end

  def intf_dynamic_save
    save do
      ## Get the dynamic configuration
      dynamic = @interface.intf_dynamic
      
      ## Create a new one if it is nil
      dynamic = IntfDynamic.new if dynamic.nil?
      
      ## save the networks
      networkStringHash = params[:networks]
      ## allow ping is checkbox, so it may not have values for each index.
      allowPingHash = params[:allowPing]
      ## indices is used to guarantee they are done in proper order.
      indices = params[:networkIndices]
      allowPingHash = {} if allowPingHash.nil?
      
      ## clear out all of the ip networks.
      dynamic.ip_networks = []
      position = 1
      unless indices.nil?
        indices.each do |key,value|
          network = IpNetwork.new
          network.parseNetwork( networkStringHash[key] )
          network.position, position = position, position + 1
          dynamic.ip_networks << network
        end
      end
    
      dynamic.update_attributes(params[:dynamic])
    
      dynamic.save

      @interface.intf_dynamic = dynamic
      @interface.config_type = InterfaceHelper::ConfigType::DYNAMIC
      @interface.save

      ## Actually commit the changes
      spawn do
        networkManager.commit
      end

      ## Return true
      true
    end
  end

  ## Save a bridged interface.
  def intf_bridge_save
    save do
      ## Get the dynamic configuration
      bridge = @interface.intf_bridge
      
      ## Create a new one if it is nil
      bridge = IntfBridge.new if bridge.nil?
      
      bridge.update_attributes(params[:bridge])
      
      if params[:bridge_interface].nil?
        flash[:error] = "Bridge To interface cannot be blank."
        return redirect_to( :action => "config", :id => @interface.id ) 
      end
      
      bridge_interface = Interface.find( params[:bridge_interface] )
      
      if bridge_interface.nil?
        flash[:error] = "Bridge To interface not found."
        return redirect_to( :action => "config", :id => @interface.id )
      end

      bridge.bridge_interface = bridge_interface
      bridge_interface.bridged_interfaces << bridge
      @interface.intf_bridge = bridge
      @interface.config_type = InterfaceHelper::ConfigType::BRIDGE
      @interface.save
      
      ## Review : should this save network settings first.
      ## Review : Internationalization
      if ( params[:commit] == "Configure".t )
        return redirect_to( :action => "config", :id => bridge_interface.id ) 
      end

      ## Actually commit the changes
      spawn do
        networkManager.commit
      end
      
      ## return true
      true
    end
  end

  def intf_pppoe_save
    save do
      ## Get the pppoe interface
      pppoe = @interface.intf_pppoe
      
      ## Create a new one if it is nil
      pppoe = IntfPppoe.new if pppoe.nil?
      
      ## save the networks
      networkStringHash = params[:networks]
      ## indices is used to guarantee they are done in proper order.
      indices = params[:networkIndices]

      ## clear out all of the ip networks.
      pppoe.ip_networks = []
      position = 1
      unless indices.nil?
        indices.each do |key,value|
          network = IpNetwork.new
          network.parseNetwork( networkStringHash[key] )
          network.position, position = position, position + 1
          pppoe.ip_networks << network
        end
      end

      pppoe.update_attributes(params[:pppoe])

      pppoe.save
      
      @interface.intf_pppoe = pppoe
      @interface.config_type = InterfaceHelper::ConfigType::PPPOE
      @interface.save
      
      ## Actually commit the changes
      spawn do
        networkManager.commit
      end
      
      ## Indicate the command was successful
      true
    end
  end

  
  ## Change the configuration type
  def change_config_type
    @config_type = params[ :config_type ]
    
    raise "invalid config type" unless InterfaceHelper::CONFIGTYPES.include?( @config_type )

    @hide_types = InterfaceHelper::CONFIGTYPES.dup
    @hide_types.delete( @config_type )
  end

  def create_ip_network
    @list_id = params[ :list_id ]
    raise "no row id" if @list_id.nil?
    raise "invalid list id syntax" if /^ip-network-list-[a-z]*$/.match( @list_id ).nil?

    ## Review : How to set defaults
    @ip_network = IpNetwork.new
    @ip_network.ip = "1.2.3.4"
    @ip_network.netmask = "24"
    @ip_network.allow_ping = true
  end

  def remove_network
    @rowId = params[ :id ]

    raise "no row id" if @rowId.nil?

    raise "invalid row id syntax" if /^ip-row-[0-9]*$/.match( @rowId ).nil?
  end

  def create_nat_policy
    @list_id = params[ :list_id ]
    raise "invalid list id syntax" if /^nat-policy-list-[a-z]*$/.match( @list_id ).nil?

    @natPolicy = NatPolicy.new
    @natPolicy.ip = "1.2.3.4"
    @natPolicy.netmask = "24"
    @natPolicy.new_source = "auto"
  end

  def remove_nat_policy
    @rowId = params[ :id ]
    
    raise "no row id" if @rowId.nil?

    raise "invalid row id syntax" if /^nat-policy-row-[0-9]*$/.match( @rowId ).nil?
  end

  def commit
    spawn do
      os["network_manager"].commit
    end
    return redirect_to( :action => 'list' )
  end

  def test_internet_connectivity
    results = networkManager.internet_connectivity?
    if results[0]
      flash[:notice] = "Successfully connected to the Internet."
    else
      flash[:warning] = "Failed to connect to the Internet. #{results[1]} failed."
    end
    index
  end

  private

  def static
    ## Retrieve the static configuration, creating a new one if necessary.
    @static = @interface.intf_static
    @static = IntfStatic.new if @static.nil?
  end

  def dynamic
    ## Retrieve the dynamic configuration, creating a new one if necessary.
    @dynamic = @interface.intf_dynamic
    @dynamic = IntfDynamic.new if @dynamic.nil?
    @dhcp_status = os["dhcp_manager"].get_dhcp_status( @interface )
  end

  def bridge
    ## Retrieve the bridge configuration, creating a new one if necessary.
    @bridge = @interface.intf_bridge
    @bridge = IntfBridge.new if @bridge.nil?
    
    if @bridge.bridge_interface.nil?
      @bridge_interface_id = nil
    else
      @bridge_interface_id = @bridge.bridge_interface.id
    end
    
    conditions = [ "config_type IN (?) AND id != ?" ]
    conditions << InterfaceHelper::BRIDGEABLE_CONFIGTYPES
    conditions << @interface.id
    
    ## Create a selection map
    @bridge_interfaces = Interface.find( :all, :conditions => conditions ).collect do |interface|
      ## XXX config_type and name will need internationalization
      [ "#{interface.name} (#{interface.config_type})", interface.id ]
    end
  end

  def pppoe
    ## Retrieve the dynamic configuration, creating a new one if necessary.
    @pppoe = @interface.intf_pppoe
    @pppoe = IntfPppoe.new if @pppoe.nil?
  end

  
  ## Load all physical devices

  ## Load the necessary values for a config page
  def load_config
    interface_id = params[:id]
    return redirect_to( :action => 'list' ) if interface_id.nil?
    @interface = Interface.find( interface_id )
    return redirect_to( :action => 'list' ) if @interface.nil?

    yield
  end

  ## Load the necessary values for a save page
  def save
    return redirect_to( :action => 'list' ) unless ( params[:commit] == "Save" )
    interface_id = params[:id]
    ## XXXX These are terrible redirects
    return redirect_to( :action => 'list' ) if interface_id.nil?
    @interface = Interface.find( interface_id )
    return redirect_to( :action => 'list' ) if @interface.nil?

    ## Update the ethernet media.    
    @interface.speed, @interface.duplex = InterfaceHelper.get_speed_duplex( params[:ethernet_media] )
    
    success = yield

    logger.debug( "Unable to save settings" ) unless success
    
    redirect_to( :action => 'list' )
  end

  def create_ip_networks( networks )
    position = 0
    return [] if networks.nil?
    networks.map do |entry|
      network = IpNetwork.new({ "ip" => entry["ip"], "netmask" => entry["netmask"] })
      network.position = position
      position += 1
      network
    end
  end

  def networkManager
    os["network_manager"]
  end
end
