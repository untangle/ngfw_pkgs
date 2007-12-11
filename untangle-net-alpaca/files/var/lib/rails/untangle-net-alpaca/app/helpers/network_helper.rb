module NetworkHelper
  ## Helper class to represent all of the information about an interface
  ## configuration
  class InterfaceConfig
    def initialize( interface, static, bridge, bridgeable_interfaces, pppoe )
      @interface, @static, @bridge = interface, static, bridge
      @bridgeable_interfaces = bridgeable_interfaces
      @pppoe = pppoe
    end

    def config_types
      ## Just create a copy (CONFIGTYPES is frozen)
      config_types = InterfaceHelper::CONFIGTYPES.map { |type| type }
      
      if @interface.wan
        config_types = 
          config_types - [ InterfaceHelper::ConfigType::BRIDGE ]
      else
        config_types = 
          config_types - [ InterfaceHelper::ConfigType::DYNAMIC, InterfaceHelper::ConfigType::PPPOE ]
      end

      ## This is what a select expects
      config_types.map { |type| [ type, type ] }
    end
    
    attr_reader :interface, :static, :bridge, :bridgeable_interfaces, :pppoe
  end

  class StaticConfig
    def initialize( ip = "", netmask = 24, default_gateway = "", dns_1 = "", dns_2 = "" )
      @ip, @netmask, @default_gateway, @dns_1, @dns_2 = ip, netmask, default_gateway, dns_1, dns_2
    end

    attr_reader :ip, :netmask, :default_gateway, :dns_1, :dns_2
  end
  
  ## Create an interface config for a particular interface
  ## @param interface The interface to build the config for.
  ## @param interface_list List of interfaces that are configurable
  def self.build_interface_config( interface, interface_list )
    s = interface.intf_static
    static = nil
    if s.nil?
      ## Just use the defaults
      static = StaticConfig.new
    else
      network = s.ip_networks[0]
      ip = ""
      netmask = 24
      ip, netmask = network.ip, network.netmask unless network.nil?
      if interface.wan
        default_gateway = s.default_gateway unless ApplicationHelper.null?( s.default_gateway )
        dns_1 = s.dns_1 unless ApplicationHelper.null?( s.dns_1 )
        dns_2 = s.dns_2 unless ApplicationHelper.null?( s.dns_2 )
      end

      static = StaticConfig.new( ip, netmask, default_gateway, dns_1, dns_2 )
    end

    bridge = interface.intf_bridge
    bridge = bridge.bridge_interface.id unless bridge.nil? || bridge.bridge_interface.nil?

    bridgeable_interfaces = 
      interface_list.map { |i| [ i.name, i.id ] }.delete_if{ |n| n[1] == interface.id }

    pppoe = interface.intf_pppoe
    pppoe = IntfPppoe.new if pppoe.nil?


    ## Return the new interface config.
    InterfaceConfig.new( interface, static, bridge, bridgeable_interfaces, pppoe )
  end
end
