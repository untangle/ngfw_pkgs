require "ipaddr"

module InterfaceHelper
  ExternalIndex = 1
  InternalIndex = 2
  DmzIndex = 3

  ## DDD These are subject to internationalization DDD
  ## REVIEW : These are also linux specific.
  DefaultInterfaceMapping = {
    # default Display name plus the index
    "eth0" => [ "External", ExternalIndex ],
    "eth1" => [ "Internal", InternalIndex ],
    "eth2" => [ "DMZ", DmzIndex ]
  }

  def self.validateNetmask( errors, netmask )
    ## not an ip address.
    begin
      IPAddr.new( "1.2.3.4/#{netmask}" )
    rescue
      errors.add( "Invalid Netmask '#{netmask}'" )
    end
  end

  ## REVIEW :: These Strings need to be internationalized.
  class ConfigType
    STATIC="static"
    DYNAMIC="dynamic"
    BRIDGE="bridge"
    PPPOE="pppoe"
  end

  ## Array of all of the available config types
  CONFIGTYPES = [ ConfigType::STATIC, ConfigType::DYNAMIC, ConfigType::BRIDGE, ConfigType::PPPOE ].freeze

  ## An array of the config types that you can bridge with
  BRIDGEABLE_CONFIGTYPES = [ ConfigType::STATIC, ConfigType::DYNAMIC ].freeze

  ## DDD some of this code may be debian specific DDD
  def self.loadInterfaces
    ## Create an empty array
    interfaceArray = []

    ## Find all of the physical interfaces
    currentIndex = DefaultInterfaceMapping.size - 1

    ia = networkManager.interfaces

    raise "Unable to detect any interfaces" if ia.nil?
    
    ## True iff the list found a WAN interface.
    foundWAN = false

    ia.each do |i| 
      interface = Interface.new

      ## Save the parameters from the physical interface.
      interface.os_name, interface.mac_address, interface.bus = i.os_name, i.mac_address, i.bus

      parameters = DefaultInterfaceMapping[i.os_name]
      ## Use the os name if it doesn't have a predefined virtual name
      parameters = [ i.os_name, currentIndex += 1 ] if parameters.nil?
      interface.name, interface.index  = parameters

      ## default it to a static config
      interface.config_type = InterfaceHelper::ConfigType::STATIC

      if ( interface.index == 1 )
        interface.wan = true
        foundWAN = true
      else
        interface.wan = false
      end
      
      ## Add the interface.
      interfaceArray << interface
    end

    ## If it hasn't found the WAN interface, set the one with the lowest index
    ## to the WAN interface.
    interfaceArray.min { |a,b| a.index <=> b }.wan = true unless foundWAN

    interfaceArray
  end

  def self.networkManager
    Alpaca::OS.current_os["network_manager"]
  end

end
