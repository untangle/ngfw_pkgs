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
  UpdateInterfaces = "update_interfaces"

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

    settings["interfaces"] = interfaces.map do |interface|
      interface_hash = interface.attributes
      interface_hash["interface_status_v2"] = interface.interface_status_v2
      interface_hash
    end

    json_result( :values => settings )
  end

  def test_internet_connectivity_v2
    json_result( :values => networkManager.internet_connectivity_v2? )
  end

  def set_interface_order
     s = json_params

    interface_list = s["interfaces"]
    
    interfaces = Interface.find( :all )

    ids = interfaces.collect { |i| i.id }.sort
    new_ids =interface_list.collect { |n| n["id"] }.sort

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
  
  ## Add and remove new physical interfaces
  def set_interface_list
    s = json_params
        
    new_interfaces, deleted_interfaces = InterfaceHelper.load_new_interfaces

    new_interface_list = s["new_interfaces"]
    deleted_interface_list = s["deleted_interfaces"]

    new_interface_list = [] if new_interface_list.nil?
    deleted_interface_list = [] if deleted_interface_list.nil?

    if ( new_interface_list.size != new_interfaces.size || 
         deleted_interface_list.size != deleted_interfaces.size )
      return json_error( "There has been a change in the interfaces, please refresh the interfaces page and try again." )
    end

    if (( new_interfaces.size + deleted_interfaces.size ) == 0 ) 
      return json_result
    end

    ## Verify that the new and deleted interfaces line up.
    ma_1 = new_interface_list.map { |i| i["mac_address"] }.sort
    ma_2 = new_interfaces.map { |i| i.mac_address }.sort
    unless ( ma_1 == ma_2 )
      return json_error( "There has been a change in the interfaces, please refresh the interfaces page and try again." )
    end

    ma_1 = deleted_interface_list.map { |i| i["mac_address"] }.sort
    ma_2 = deleted_interfaces.map { |i| i.mac_address }.sort
    unless ( ma_1 == ma_2 )
      return json_error( "There has been a change in the interfaces, please refresh the interfaces page and try again." )
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
    json_result
  end
  
  alias_method :refresh, :extjs

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
    settings["current_mtu"] = interface.current_mtu.strip
    
    settings["static_nat_policies"] = static_settings.nat_policies

    media = "#{interface.speed}#{interface.duplex}"
    if InterfaceHelper::EthernetMedia.get_value( media ).nil?
      media = InterfaceHelper::EthernetMedia.get_default().key
    end
    
    settings["media"] = media
    
    json_result( :values => settings )
  end
      
  def set_settings
    s = json_params

    interface_id = params[:id]
    return json_error( "Invalid interface id '%s'" % ( interface_id )) if interface_id.nil?
    interface = Interface.find( interface_id )
    return json_error( "Unknown interface '%s'" % ( interface_id )) if interface.nil?
    
    interface_attributes = s["interface"] 
    interface_attributes.delete( "wan" )
    interface_attributes.delete( "name" )
    interface_attributes.delete( "bus" )
    interface_attributes.delete( "os_name" )
    interface_attributes.delete( "mac_address" )
    interface_attributes.delete( "index" )
    interface_attributes.delete( "vendor" )
    
    interface.update_attributes( interface_attributes )
    
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
    bridge_id = s["bridge"]["bridge_interface_id"]
    bridge_interface = Interface.find( :first, :conditions => [ "id = ?", bridge_id ] )

    if ( s["interface"]["config_type"] == "bridge" )
      if bridge_interface.nil?
        return json_error( "Bridge Interface cannot be null" )
      end
    end

    unless bridge_interface.nil?
      bridge_settings.bridge_interface = bridge_interface
      bridge_interface.bridged_interfaces << bridge_settings
    end
      
    static_settings.ip_networks = create_ip_networks( s["static_aliases"] )
    dynamic_settings.ip_networks = create_ip_networks( s["dynamic_aliases"] )
    pppoe_settings.ip_networks = create_ip_networks( s["pppoe_aliases"] )

    ## Add in the nat policies
    ## Delete all of the nat policies
    static_settings.nat_policies = []
      
    position = 1
    nat_policies = s["static_nat_policies"]
    unless nat_policies.nil?
      static_settings.nat_policies = nat_policies.map do |np|
        nat_policy = NatPolicy.new({ "ip" => np["ip"], "netmask" => np["netmask"], 
                                     "new_source" => np["new_source"], "position" => position })
        position += 1
        nat_policy
      end
    end

    static_settings.save
    dynamic_settings.save
    pppoe_settings.save
    bridge_settings.save

    interface.intf_static = static_settings
    interface.intf_dynamic = dynamic_settings
    interface.intf_pppoe = pppoe_settings
    interface.intf_bridge = bridge_settings

    media = InterfaceHelper::EthernetMedia.get_value( s["media"] )
    media = InterfaceHelper::EthernetMedia.get_default if media.nil?
    interface.speed, interface.duplex = media.speed, media.duplex
    
    interface.save

    spawn { networkManager.commit }
    
    json_result
  end

  alias_method :e_config, :extjs

  def e_index
    return redirect_to( :action => 'e_list' )
  end

  def commit
    spawn do
      os["network_manager"].commit
    end
    return redirect_to( :action => 'list' )
  end

  private

  def create_ip_networks( networks )
    position = 1
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
