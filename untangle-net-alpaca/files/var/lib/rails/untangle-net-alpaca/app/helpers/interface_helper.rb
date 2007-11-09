require "ipaddr"

module InterfaceHelper
  def self.validateNetmask( errors, netmask )
    ## not an ip address.
    begin
      IPAddr.new( "1.2.3.4/#{netmask}" )
    rescue
      errors.add( "Invalid Netmask '#{netmask}'" )
    end
  end
  
  ## Save the settings
  def self.wizard_save( params, session, request )
    ## Iterate all of the interfaces
    interfaceList = params[:interfaceList]
    
    raise "Invalid interface list" if ( interfaceList.nil?  || interfaceList.empty? )

    ## These are all of the interfaces that are presently available
    interfaces = Alpaca::OS.current_os["network_manager"].interfaces
    
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
      raise "Unknown interface #{interface} '#{os_name}' '#{name}'" if ( os_name.nil? || name.nil? )
      
      a = interfaces.select { |intf| intf.os_name == os_name }
      raise "The interface #{os_name} is not available" if ( a.empty? || ( a.size > 1 ))
      a = a[0]
      
      interfaces.delete( a )

      n_intf = Interface.new
      
      ## Setup all of the parameters about the interface
      n_intf.name, n_intf.index, n_intf.os_name = name, index += 1, os_name
      n_intf.mac_address, n_intf.bus, n_intf.vendor = a.mac_address, a.bus, a.vendor
      n_intf.wan = ( n_intf.index == 1 )
      
      ## Set the configuration
      case config_type
      when InterfaceHelper::ConfigType::STATIC then static( params, n_intf, interface )
      when InterfaceHelper::ConfigType::DYNAMIC then dynamic( params, n_intf, interface )
      when InterfaceHelper::ConfigType::BRIDGE then bridge( params, n_intf, interface )
      else raise "Unknown configuration type #{config_type}"
      end
    end
  end

  ## REVIEW :: These Strings need to be internationalized.
  class ConfigType
    STATIC="static"
    DYNAMIC="dynamic"
    BRIDGE="bridge"
  end

  ## Array of all of the available config types
  CONFIGTYPES = [ ConfigType::STATIC, ConfigType::DYNAMIC, ConfigType::BRIDGE ].freeze

  ## An array of the config types that you can bridge with
  BRIDGEABLE_CONFIGTYPES = [ ConfigType::STATIC, ConfigType::DYNAMIC ].freeze

  def self.static( params, interface, interface_stage_id )
    static = IntfStatic.new
    network = IpNetwork.new
    network.ip = params["#{interface_stage_id}-static.address"]
    network.netmask = params["#{interface_stage_id}-static.netmask"]
    network.allow_ping = true
    static.ip_networks << network
    
    if interface.index == 1
      ## Set the default gateway and dns
      static.default_gateway = params["#{interface_stage_id}-static.default_gateway"]
      static.dns_1 = params["#{interface_stage_id}-static.dns_1"]
      static.dns_2 = params["#{interface_stage_id}-static.dns_2"]
    else
      ## Add a NAT policy (this not the external interface)
      natPolicy = NatPolicy.new
      natPolicy.ip = "0.0.0.0"
      natPolicy.netmask = "0"
      natPolicy.new_source = "auto"
      static.nat_policies << natPolicy
    end

    static.save
    interface.config_type = InterfaceHelper::ConfigType::STATIC
    interface.intf_static = static
    interface.save
  end

  def self.dynamic( params, interface, interface_stage_id )
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

  def self.bridge( params, interface, interface_stage_id )
    bridge = IntfBridge.new
    os_name = params["#{interface_stage_id}-bridge.bridge_interface"]
    return logger.warn( "Bridge interface is not specified" ) if os_name.nil?
    
    bridge_interface = Interface.find( :first, :conditions => [ "os_name = ?", os_name ] )
    return logger.warn( "Unable to find the interface '#{os_name}'" ) if bridge_interface.nil?
    
    bridge.bridge_interface = bridge_interface
    bridge_interface.bridged_interfaces << bridge

    interface.intf_bridge = bridge
    interface.config_type = InterfaceHelper::ConfigType::BRIDGE
    interface.save
  end
end
