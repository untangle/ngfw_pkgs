class NetworkController < ApplicationController
  def index
    manage
    render :action => 'manage'
  end

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
      @dhcp_status = os["dhcp_manager"].get_dhcp_status( interface ) if interface.wan
      NetworkHelper.build_interface_config( interface, @interface_list )
    end

    ## This should be in a global place
    @cidr_options = OSLibrary::NetworkManager::CIDR.map { |k,v| [ format( "%-3s %s", k, v ) , k ] }
    @cidr_options.sort! { |a,b| a[1].to_i <=> b[1].to_i }    
  end

  def save
    return redirect_to( :action => 'manage' ) unless ( params[:commit] == "Save" )
    
    ## Retrieve all of the interfaces
    interface_list = params[:interface_list]

    interface_id_list = params[:interface_id_list]

    ## Convert the interface ids to numbers
    interface_id_list = interface_id_list.map do |interface_id|
      i = interface_id.to_i
      return redirect_to( :action => 'fail_0' ) if i.to_s != interface_id
      i
    end

    ## Verify the list exists.
      return redirect_to( :action => 'fail_1' ) if interface_list.nil?
    
    ## Verify the list lines up with the existing interfaces
    interfaces = Interface.find( :all )

    ## Verify the list matches.
    return redirect_to( :action => 'fail_2' ) if ( interfaces.size != interface_list.size )

    interface_map = {}
    interfaces = interfaces.each{ |interface| interface_map[interface.id] = interface }
    
    ## Verify every id is represented
    interface_id_list.each do |interface_id|
      return redirect_to( :action => 'fail_4' ) if interface_map[interface_id].nil?
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
      ## REVIEW : Move this into the validation part
      else raise "Unknown configuration type #{config_type}"  
      end
    end

    spawn do
      os["network_manager"].commit
    end
    
    return redirect_to( :action => 'manage' )
  end

  def scripts
    [ "network" ]
  end

  def stylesheets
    [ "borax/list-table", "borax/network" ]
  end

  private 
  def static( interface, panel_id )
    static = interface.intf_static
    static = IntfStatic.new if static.nil?
    
    network = static.ip_networks[0]

    ## There isn't a first one, need to create a new one
    if network.nil?
      network = IpNetwork.new( :allow_ping => true, :position => 1 )
      network.parseNetwork( "#{params["#{panel_id}_static_ip"]}/#{params["#{panel_id}_static_netmask"]}" )
      static.ip_networks = [ network ]
    else
      ## Replace the one that is there
      network.ip = params["#{panel_id}_static_ip"]
      network.netmask = params["#{panel_id}_static_netmask"]
      network.allow_ping = true
      network.save
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
end
