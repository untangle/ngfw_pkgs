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
    @title = "Interface List"
    @description = "List of all of the available interfaces."
    
    @interfaces = Interface.find_all

    if ( @interfaces.nil? || @interfaces.empty? )       
      @interfaces = loadInterfaces
      ## Save all of the new interfaces
      @interfaces.each { |interface| interface.save }
    end
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
    if @staticConfig.nil?
      @staticConfig = IntfStatic.new 
    end
  end

  def create_new_network
    @network = IpNetwork.new
    @network.ip = "0.0.0.0"
    @network.netmask = "255.255.255.0"
    @network.allow_ping = false
  end

  def remove_network
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
    currentIdex = DefaultInterfaceMapping.size - 1
    `find /sys/devices -name 'net:*'`.each do |sys_device_path| 
      name=sys_device_path.sub( /.*net:/, "" ).strip
      interface = Interface.new
      parameters = DefaultInterfaceMapping[name]

      ## Use the os name if it doesn't have a predefined virtual name
      parameters = [ name, currentIndex += 1 ] if parameters.nil?
      interface.name  = parameters[0]
      interface.index = parameters[1]

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
end
