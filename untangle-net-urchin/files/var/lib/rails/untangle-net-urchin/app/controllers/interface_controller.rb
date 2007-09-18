require_dependency "os_library"

class InterfaceController < ApplicationController
  layout "main"

  ## DDD These are subject to internationalization DDD
  DefaultInterfaceMapping = {
    # default Display name plus the index
    "eth0" => [ "External", 1 ],
    "eth1" => [ "Internal", 2 ],
    "eth2" => [ "DMZ", 3 ]
  }

  def index
    list
    render :action => 'list'
  end

  def list
    OSLibrary.getOS( "DebianSarge" ).manager( "network_manager" ).interfaces
    logger.debug( "Looking up the distro #{OSLibrary.getOS( "DebianSarge" ).distribution}" )
    
    @title = "Interface List"
    @description = "List of all of the available interfaces."
    
    @interfaces = Interface.find(:all)

    if ( @interfaces.nil? || @interfaces.empty? )       
      @interfaces = loadInterfaces
      ## Save all of the new interfaces
      @interfaces.each { |interface| interface.save }
    end

    @interfaces.sort! { |a,b| a.index <=> b.index }
  end

  def reload
    ## DDD This makes it really hard to remap interfaces and save settings. DDD ###
    ## DDD since the settings are stored inside of the interface.           DDD ###
    Interface.destroy_all

    return redirect_to( :action => 'list' )
  end

  def static
    interface_id = params[:id]
    return redirect_to( :action => 'list' ) if interface_id.nil?
    @interface = Interface.find( interface_id )
    return redirect_to( :action => 'list' ) if interface_id.nil?
    @title = "Static Interface Configuration"
    
    ## Retrieve the static configuration, creating a new one if necessary.
    @staticConfig = @interface.intf_static
    @staticConfig = IntfStatic.new if @staticConfig.nil?
  end

  def dynamic
    interface_id = params[:id]
    return redirect_to( :action => 'list' ) if interface_id.nil?
    @interface = Interface.find( interface_id )
    return redirect_to( :action => 'list' ) if interface_id.nil?
    @title = "Dynamic Interface Configuration"
    
    ## Retrieve the static configuration, creating a new one if necessary.
    @dynamic = @interface.intf_dynamic
    @dynamic = IntfDynamic.new if @dynamic.nil?
  end

  def bridge
    config do
      @title = "Bridge Interface Configuration"
    
      ## Retrieve the static configuration, creating a new one if necessary.
      @bridge = @interface.intf_bridge
      @bridge = IntfBridge.new if @bridge.nil?

      conditions = [ "config_type IN (?) AND id != ?" ]
      conditions << InterfaceHelper::BRIDGEABLE_CONFIGTYPES
      conditions << @interface.id
      
      ## Create a selection map
      @bridgeInterfaces = Interface.find( :all, :conditions => conditions ).collect do |interface|
        ## XXX config_type and name will need internationalization
        [ "#{interface.name} (#{interface.config_type})", interface.id ]
      end
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
      i.save
    end
    
    return redirect_to( :action => 'list' )
  end

  def intf_static_save
    return redirect_to( :action => 'list' ) if ( params[:commit] == "Cancel" )

    interface_id = params[:id]
    ## XXXX These are terrible redirects
    return redirect_to( :action => 'list' ) if interface_id.nil?
    @interface = Interface.find( interface_id )
    return redirect_to( :action => 'list' ) if @interface.nil?

    ## Get the static interface
    staticConfig = @interface.intf_static
    
    ## Create a new one if it is nil
    staticConfig = IntfStatic.new if staticConfig.nil?
    
    ## save the networks
    networkStringHash = params[:networks]
    ## allow ping is checkbox, so it may not have values for each index.
    allowPingHash = params[:allowPing]
    ## indices is used to guarantee they are done in proper order.
    indices = params[:networkIndices]
    allowPingHash = {} if allowPingHash.nil?
    
    ## clear out all of the ip networks.
    staticConfig.ip_networks = []
    unless indices.nil?
      indices.each do |key,value|
        network = IpNetwork.new
        network.parseNetwork( networkStringHash[key] )
        network.allow_ping = ( allowPingHash[key] )
        staticConfig.ip_networks << network
      end
    end
    
    ## save the nat policies
    natNetworkHash = params[:natNetworks]
    natNewSourceHash = params[:natNewSources]

    ## indices is used to guarantee they are done in proper order.
    indices = params[:natIndices]

    ## Delete all of the nat policies
    staticConfig.nat_policies = []
    
    unless indices.nil?
      indices.each do |key|
        natPolicy = NatPolicy.new
        logger.debug( "index: #{key}" )
        natPolicy.parseNetwork( natNetworkHash[key] )
        natPolicy.new_source = natNewSourceHash[key]
        staticConfig.nat_policies << natPolicy
      end
    end

    staticConfig.update_attributes(params[:static])
    
    staticConfig.save

    @interface.intf_static = staticConfig
    @interface.config_type = InterfaceHelper::ConfigType::STATIC
    @interface.save

    return redirect_to( :action => 'list' )
  end

  def intf_dynamic_save
    interface_id = params[:id]
    return redirect_to( :action => 'list' ) if interface_id.nil?
    @interface = Interface.find( interface_id )
    return redirect_to( :action => 'list' ) if @interface.nil?
    
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
    unless indices.nil?
      indices.each do |key,value|
        network = IpNetwork.new
        network.parseNetwork( networkStringHash[key] )
        network.allow_ping = ( allowPingHash[key] )
        dynamic.ip_networks << network
      end
    end
    
    dynamic.update_attributes(params[:dynamic])
    
    dynamic.save

    @interface.intf_dynamic = dynamic
    @interface.config_type = InterfaceHelper::ConfigType::DYNAMIC
    @interface.save

    return redirect_to( :action => 'list' )
  end

  ## Save a bridged interface.
  def intf_bridge_save
    save do
      ## Get the dynamic configuration
      bridge = @interface.intf_bridge
      
      ## Create a new one if it is nil
      bridge = IntfBridge.new if bridge.nil?
      
      bridge.update_attributes(params[:bridge])
      
      break false if params[:bridge_interface].nil?
      
      bridge_interface = Interface.find( params[:bridge_interface] )
      
      break false if bridge_interface.nil?

      bridge.bridge_interface = bridge_interface
      bridge_interface.bridged_interfaces << bridge
      @interface.intf_bridge = bridge
      @interface.config_type = InterfaceHelper::ConfigType::BRIDGE
      @interface.save
      
      if ( params[:commit] == "Configure" )
        return redirect_to( :action => bridge_interface.config_type, :id => bridge_interface.id ) 
      end
      
      true
    end
  end
    
  def create_new_network
    @network = IpNetwork.new
    @network.ip = "0.0.0.0"
    @network.netmask = "255.255.255.0"
    @network.allow_ping = true
  end

  def remove_network
    @rowId = params[ :id ]

    ## should validate the syntax
    raise "no row id" if @rowId.nil?
  end

  def create_nat_policy
    @natPolicy = NatPolicy.new
    @natPolicy.ip = "1.2.3.4"
    @natPolicy.netmask = "24"
    @natPolicy.new_source = "auto"
  end

  def remove_nat_policy
    @rowId = params[ :id ]
    
    ## should validate the syntax
    raise "no row id" if @rowId.nil?
  end

  private
  
  ## Load all physical devices

  ## DDD some of this code may be debian specific DDD
  def loadInterfaces
    ## Create an empty array
    interfaceArray = []

    ## Find all of the physical interfaces
    currentIndex = DefaultInterfaceMapping.size - 1
    devices=`find /sys/devices -name 'net:*' | sed 's|.*net:||'`

    ## This is test code to fake a third interface
    devices << "dummy0" if File.exists?( "/sys/class/net/dummy0" )

    devices.each do |sys_device_path| 
      name=sys_device_path.strip
      interface = Interface.new
      parameters = DefaultInterfaceMapping[name]

      ## Save the os name
      interface.os_name = name

      ## Use the os name if it doesn't have a predefined virtual name
      parameters = [ name, currentIndex += 1 ] if parameters.nil?
      interface.name  = parameters[0]
      interface.index = parameters[1]
      interface.config_type = InterfaceHelper::ConfigType::STATIC

      ## Set the mac address
      File.open( "/sys/class/net/#{name}/address", "r" ) { |f| interface.mac_address = f.readline.strip }
      
      ## Add the interface.
      interfaceArray << interface
    end

    ## Update the index for each one
    interfaceArray.each do |interface|
      
    end
    
    interfaceArray
  end

  ## Load the necessary values for a config page
  def config
    interface_id = params[:id]
    return redirect_to( :action => 'list' ) if interface_id.nil?
    @interface = Interface.find( interface_id )
    return redirect_to( :action => 'list' ) if interface_id.nil?

    yield
  end

  ## Load the necessary values for a save page
  def save
    return redirect_to( :action => 'list' ) if ( params[:commit] == "Cancel" )
    interface_id = params[:id]
    ## XXXX These are terrible redirects
    return redirect_to( :action => 'list' ) if interface_id.nil?
    @interface = Interface.find( interface_id )
    return redirect_to( :action => 'list' ) if @interface.nil?
    
    success = yield

    logger.debug( "Unable to save settings" ) unless success
    
    redirect_to( :action => 'list' )
  end
end
