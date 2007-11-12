class Alpaca::Components::InterfaceComponent < Alpaca::Component
  ## Register all of the menu items.
  def register_menu_items( menu_organizer )
    ## REVIEW : should be a more elegant way of specifying the URL.
    menu_organizer.register_item( "/main/interfaces", Alpaca::Menu::Item.new( 200, "Interfaces", "/interface/list" ))


    ## Retrieve all of the interfaces
    interfaces = Interface.find(:all)
    interfaces.sort! { |a,b| a.index <=> b.index }

    interfaces.each do |i|
      menu_item = Alpaca::Menu::Item.new( i.index, i.name, "/interface/config/#{i.id}" )
      menu_organizer.register_item( "/main/interfaces/#{i.os_name}", menu_item )
    end    
  end

  class InterfaceTestStage < Alpaca::Wizard::Stage
    def initialize( interface_list )
      super( "interface-test", "Detection".t, 200 )
      @interface_list = interface_list
    end

    attr_reader :interface_list
  end

  class InterfaceStage < Alpaca::Wizard::Stage
    def initialize( id, interface, wan )
      name = InterfaceController::DefaultInterfaceMapping[interface.os_name]
      name = [ interface.os_name ] if name.nil?
      name = name[0]
      super( id, name, 300 )
      @interface, @wan = interface, wan
    end

    def partial
      "interface_config"
    end
    attr_reader :interface, :wan
  end

  ## Insert the desired stages for the wizard.
  def wizard_insert_stages( builder )
    interface_list = os["network_manager"].interfaces

    ## Sort the interface list
    interface_list.sort! do |a,b|
      a_mapping = InterfaceController::DefaultInterfaceMapping[a.os_name]
      b_mapping = InterfaceController::DefaultInterfaceMapping[b.os_name]
      
      next a.os_name <=> b.os_name if ( a_mapping.nil? && b_mapping.nil? )
      next -1 if !a_mapping.nil? && b_mapping.nil?
      next 1 if a_mapping.nil? && !b_mapping.nil?

      ## Both are non-nil
      a_mapping[1] <=> b_mapping[1]
    end

    ## Register the detection stage
    builder.insert_piece( InterfaceTestStage.new( interface_list ))

    ## Register all of the interfaces
    index = 0
    interface_list.each do |interface| 
      s = InterfaceStage.new( "interface-config-#{index+=1}", interface, index == 1 )
      builder.insert_piece( s )
    end
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
      ## REVIEW : move this into the validate side.
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
      when InterfaceHelper::ConfigType::STATIC then static( n_intf, interface )
      when InterfaceHelper::ConfigType::DYNAMIC then dynamic( n_intf, interface )
      when InterfaceHelper::ConfigType::BRIDGE then bridge( n_intf, interface )
      ## REVIEW : Move this into the validation part
      else raise "Unknown configuration type #{config_type}"  
      end
    end
  end

  def commit
    os["network_manager"].commit
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
