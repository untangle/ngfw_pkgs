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
class Alpaca::Components::InterfaceComponent < Alpaca::Component
  class InterfaceTestStage < Alpaca::Wizard::Stage
    def initialize( interface_list )
      super( "interface-test", "Detection".t, 200 )
      @interface_list = interface_list
    end

    attr_reader :interface_list
  end

  class InterfaceStage < Alpaca::Wizard::Stage
    def initialize( id, interface )
      super( id, interface.name, 300 )
      @interface = interface
    end

    def partial
      "interface_config"
    end
    
    def wan
      @interface.wan
    end

    attr_reader :interface
  end

  class InterfaceReview
    def initialize( name, os_name, config_type, value )
      @name, @os_name, @config_type, @value = name, os_name, config_type, value 
    end
    
    attr_reader :name, :os_name, :config_type, :value 
  end

  ## Register all of the menu items.
  def register_menu_items( menu_organizer, config_level )
    menu_organizer.register_item( "/extjs/interfaces", menu_item( 100, "Interfaces", :action => "list" ))
  end

  ## Insert the desired stages for the wizard.
  def wizard_insert_stages( builder )
    interface_list = Array.new( InterfaceHelper.loadInterfaces )

    interface_list.delete_if { |interface| !interface.is_mapped? }
    
    ## Register the detection stage
    builder.insert_piece( InterfaceTestStage.new( interface_list ))

    ## Register all of the interfaces
    interface_list.each do |interface|
      s = InterfaceStage.new( "interface-config-#{interface.index}", interface )
      builder.insert_piece( s )
    end
  end

  def wizard_generate_review( review )
    interfaceList = params[:interfaceList]
    
    raise "Invalid interface list" if ( interfaceList.nil?  || interfaceList.empty? )

    is_first = true
    il = []
    ## Create a new interface for each one (they are ordered)
    interfaceList.each do |interface|
      ## Retrive the os_name
      os_name = params["#{interface}.os_name"]

      ## Retrive the name
      name = params["#{interface}.name"]

      ## Retrieve the config type
      config_type = params["#{interface}.type"]
      
      value = ""
      case config_type
      when InterfaceHelper::ConfigType::STATIC 
        value = "#{params["#{interface}-static.address"]}/#{params["#{interface}-static.netmask"]}"
        if is_first
          review["default_gateway"] = params["#{interface}-static.default_gateway"]
          review["dns_1"] = params["#{interface}-static.dns_1"]
          review["dns_2"] = params["#{interface}-static.dns_2"]

          review["default_gateway"] = "&nbsp;" if ApplicationHelper.null?( review["default_gateway"] )
          review["dns_1"] = "&nbsp;" if ApplicationHelper.null?( review["dns_1"] )
          review["dns_2"] = "&nbsp;" if ApplicationHelper.null?( review["dns_2"] )
        end
      when InterfaceHelper::ConfigType::DYNAMIC
        value = "automatic"
        if is_first
          review["default_gateway"], review["dns_1"], review["dns_2"] = [ "auto", "auto", "auto" ]
        end
      when InterfaceHelper::ConfigType::BRIDGE
        value = params["#{interface}-bridge.bridge_interface"]
      else raise "Unknown configuration type #{config_type}"  
      end
      is_first = false
      il << InterfaceReview.new( name, os_name, config_type, value )
    end

    review["interface-list"] = il
  end

  def wizard_insert_closers( builder )
    ## Validate the settings
    builder.insert_piece( Alpaca::Wizard::Closer.new( 0 ) { validate } )
    builder.insert_piece( Alpaca::Wizard::Closer.new( 1100 ) { save } )
    builder.insert_piece( Alpaca::Wizard::Closer.new( 2100 ) { commit } )
  end
  
  private

  def validate
    ## Iterate all of the interfaces
    interfaceList = params[:interfaceList]
      
    raise "Invalid interface list" if ( interfaceList.nil?  || interfaceList.empty? )
  end

  ## Save the settings
  def save
    ## Iterate all of the interfaces
    interfaceList = params[:interfaceList]
    
    raise "Invalid interface list" if ( interfaceList.nil?  || interfaceList.empty? )

    ## These are all of the interfaces that are presently available
    interfaces = InterfaceHelper.loadInterfaces
    
    ## This is the list of ruby objects to be saved
    n_interfaceList = []

    ## Start numbering them from 1
    index = 0

    ## Review : This is bad, it is just bad.
    Interface.destroy_all
    IntfStatic.destroy_all
    IntfBridge.destroy_all
    IntfDynamic.destroy_all

    ## Create a new interface for each one (they are ordered)
    interfaceList.each do |interface|
      ## Retrive the os_name
      os_name = params["#{interface}.os_name"]

      ## Retrive the name
      name = params["#{interface}.name"]

      ## Retrieve the config type
      config_type = params["#{interface}.type"]

      ## interface is some gnarsty key
      ## REVIEW : move this into the validate side.
      raise "Unknown interface #{interface} '#{os_name}' '#{name}'" if ( os_name.nil? || name.nil? )

      a = interfaces.select { |intf| ( intf.os_name == os_name ) && ( intf.name == name ) }
      raise "The interface #{os_name}, #{name} is not available" if ( a.size != 1 )
      ## Remove this interface
      interfaces  = interfaces - a
      n_intf = a[0]
      
      ## Set the configuration
      case config_type
      when InterfaceHelper::ConfigType::STATIC then static( n_intf, interface )
      when InterfaceHelper::ConfigType::DYNAMIC then dynamic( n_intf, interface )
      when InterfaceHelper::ConfigType::BRIDGE then bridge( n_intf, interface )
      ## REVIEW : Move this into the validation part
      else raise "Unknown configuration type #{config_type}"  
      end
    end
    
    ## Search for the remaining interfaces.
    interfaces.each do |interface|
      if ( interface.is_mapped? )
        raise "The interface #{interface.name}, #{interface.os_name} was not configured in the wizard"
      end
      
      ## Otherwize, just set it to static and save.
      interface.config_type = InterfaceHelper::ConfigType::STATIC
      interface.intf_static = IntfStatic.new
      interface.save
    end
  end

  def commit
    os["network_manager"].commit
  end

  def static( interface, interface_stage_id )
    static = IntfStatic.new
    network = IpNetwork.new( :position => 1, :allow_ping => true )
    network.ip = params["#{interface_stage_id}-static.address"]
    network.netmask = params["#{interface_stage_id}-static.netmask"]
    static.ip_networks << network
    
    if interface.index == 1
      ## Set the default gateway and dns
      static.default_gateway = params["#{interface_stage_id}-static.default_gateway"]
      static.dns_1 = params["#{interface_stage_id}-static.dns_1"]
      static.dns_2 = params["#{interface_stage_id}-static.dns_2"]
    else
      ## Add a NAT policy (this not the external interface)
      natPolicy = NatPolicy.new( :ip => "0.0.0.0", :netmask => "0", :new_source => "auto", :position => 1 )
      static.nat_policies << natPolicy
    end

    static.save
    interface.config_type = InterfaceHelper::ConfigType::STATIC
    interface.intf_static = static
    interface.save
  end

  def dynamic( interface, interface_stage_id )
    dynamic = IntfDynamic.new
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

  def bridge( interface, interface_stage_id )
    bridge = IntfBridge.new
    os_name = params["#{interface_stage_id}-bridge.bridge_interface"]
    raise "Bridge interface is not specified" if os_name.nil?
    
    bridge_interface = Interface.find( :first, :conditions => [ "os_name = ?", os_name ] )
    raise "Unable to find the interface '#{os_name}'" if bridge_interface.nil?
    
    bridge.bridge_interface = bridge_interface
    bridge_interface.bridged_interfaces << bridge

    interface.intf_bridge = bridge
    interface.config_type = InterfaceHelper::ConfigType::BRIDGE
    interface.save
  end
end
