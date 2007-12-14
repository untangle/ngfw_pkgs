class Alpaca::Components::InterfaceComponent < Alpaca::Component
  class InterfaceTestStage < Alpaca::Wizard::Stage
    def initialize( interface_list )
      super( "interface-test", "Detection".t, 200 )
      @interface_list = interface_list
    end

    attr_reader :interface_list
  end

  class InterfaceStage < Alpaca::Wizard::Stage
    def initialize( id, interface, wan )
      name = InterfaceHelper::DefaultInterfaceMapping[interface.os_name]
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

  class InterfaceReview
    def initialize( name, os_name, config_type, value )
      @name, @os_name, @config_type, @value = name, os_name, config_type, value 
    end
    
    attr_reader :name, :os_name, :config_type, :value 
  end

  ## Register all of the menu items.
  def register_menu_items( menu_organizer, config_level )
    return unless ( config_level >= AlpacaSettings::Level::Advanced )

    menu_organizer.register_item( "/main/interfaces", menu_item( 200, "Interfaces", :action => "list" ))
    
    ## Retrieve all of the interfaces
    interfaces = Interface.find(:all)
    interfaces.sort! { |a,b| a.index <=> b.index }
    
    interfaces.each do |i|
      mi = menu_item( i.index, i.name, :action => "config", :id => i.id )
      menu_organizer.register_item( "/main/interfaces/#{i.os_name}", mi )
    end    
  end

  ## Insert the desired stages for the wizard.
  def wizard_insert_stages( builder )
    interface_list = os["network_manager"].interfaces

    ## Sort the interface list
    interface_list.sort! do |a,b|
      a_mapping = InterfaceHelper::DefaultInterfaceMapping[a.os_name]
      b_mapping = InterfaceHelper::DefaultInterfaceMapping[b.os_name]
      
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

          review["default_gateway"] = "unset" if ApplicationHelper.null?( review["default_gateway"] )
          review["dns_1"] = "unset" if ApplicationHelper.null?( review["dns_1"] )
          review["dns_2"] = "unset" if ApplicationHelper.null?( review["dns_2"] )
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
