class WizardController < ApplicationController
  InterfaceKey = "interface-config"

  class SimpleStageHandler
    def name
      ""
    end
  end

  class WizardStage
    def initialize( id, name, is_array = false, handler = nil )
      @id, @name, @is_array, @handler = id, name, is_array, handler 
      @handler = SimpleStageHandler.new if @handler.nil?
    end

    ## ID that is to be used when this is referenced in list.
    def list_id
      "sl-#{@id}"
    end

    ## Name of the partial used to render this stage
    def partial
      @id.sub( /-[0-9]+$/, "" ).gsub( "-", "_" )
    end

    attr_reader :id, :name, :is_array, :handler
  end

  class InterfaceStageHandler
    def initialize( interface, index )
      @interface = interface
      
      ## Review : Don't like that this is in two places here and InterfaceController.
      mapping = InterfaceController::DefaultInterfaceMapping[@interface.os_name]
      mapping = [ @interface.os_name, index ] if mapping.nil?
      
      @name, @index = mapping      
    end

    attr_reader :index, :interface, :name
  end

  WizardStages = 
    [ WizardStage.new( "welcome", "Welcome" ),
      WizardStage.new( "interface-test", "Detection" ),
      WizardStage.new( InterfaceKey, "%s", true ),
      WizardStage.new( "review", "Review" ),
      WizardStage.new( "finish", "Finished" )
    ].freeze

  def index
    @title = "Setup Wizard"

    @interfaces = networkManager.interfaces

    ## These indexes don't have to be sequential (just for sorting)
    index = InterfaceController::DefaultInterfaceMapping.size 
    interfaceHandlers = @interfaces.map { |i| InterfaceStageHandler.new( i, index += 1 ) }
    interfaceHandlers.sort! { |a,b| a.index <=> b.index }

    ## Have to sort these 
    @stages = expandStages( InterfaceKey => interfaceHandlers )

    ## This should be in a global place
    @cidr_options = OSLibrary::NetworkManager::CIDR.map { |k,v| [ format( "%-3s %s", k, v ) , k ] }

    @cidr_options.sort! { |a,b| a[1].to_i <=> b[1].to_i }
  end
  
  def save
    ## Iterate all of the interfaces
    interfaceList = params[:interfaceList]

    @error = nil
    return @error = "Invalid interface list" if ( interfaceList.nil?  || interfaceList.empty? )

    ## These are all of the interfaces that are presently available
    interfaces = networkManager.interfaces
    
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
      return @error = "Unknown interface #{interface} '#{os_name}' '#{name}'" if ( os_name.nil? || name.nil? )
      
      a = interfaces.select { |intf| intf.os_name == os_name }
      return @error = "The interface #{os_name} is not available" if ( a.empty? || ( a.size > 1 ))
      a = a[0]
      
      interfaces.delete( a )

      n_intf = Interface.new
      
      ## Setup all of the parameters about the interface
      n_intf.name, n_intf.index, n_intf.os_name = name, index += 1, os_name
      n_intf.mac_address, n_intf.bus, n_intf.vendor = a.mac_address, a.bus, a.vendor

      n_intf.wan = ( n_intf.index == 1 )
      
      ## Set the configuration
      case config_type
      when InterfaceHelper::ConfigType::STATIC then static( n_intf, interface )
      when InterfaceHelper::ConfigType::DYNAMIC then dynamic( n_intf, interface )
      when InterfaceHelper::ConfigType::BRIDGE then bridge( n_intf, interface )
      else return @error = "Unknown configuration type #{config_type}"
      end
    end

    spawn do
      networkManager.commit
    end
  end

  private

  def networkManager
    ## REVIEW DebianSarge is hardcoded, need to move this out.
    OSLibrary.getOS( "DebianSarge" ).manager( "network_manager" )
  end

  ## This is the navigational form  
  def expandStages( keys )
    WizardStages.collect do |p| 
      next p unless p.is_array
      values = []
      handlers = keys[p.id]
      next nil if handlers.nil?

      handlers.size.times { |n| values << WizardStage.new( "#{p.id}-#{n}", p.name, false, handlers[n] ) }
      values
    end.flatten.delete_if { |p| p.nil? }
  end

  def static( interface, interface_stage_id )
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
