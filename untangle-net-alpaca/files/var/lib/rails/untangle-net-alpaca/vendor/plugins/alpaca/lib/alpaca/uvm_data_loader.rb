require "logger"
require 'dbi'

class Alpaca::UvmDataLoader
  class EthernetMedia
    @@enumeration = {}
    def initialize( key, speed, duplex )
      @key = key
      @speed = speed
      @duplex = duplex

      ## Register itself with the enumeration
      @@enumeration[key] = self
    end

    def self.get_value( key )
      @@enumeration[key.to_i]
    end

    Auto = EthernetMedia.new( 0, "auto", "auto" )
    FullDuplex100 = EthernetMedia.new( 1, 100, "full" )
    HalfDuplex100 = EthernetMedia.new( 2, 100, "half" )
    FullDuplex10  = EthernetMedia.new( 3, 10,  "full" )
    HalfDuplex10  = EthernetMedia.new( 4, 10,  "half" )

    attr_reader :key, :speed, :duplex
  end

  class NetworkSettings
    def initialize( is_enabled, default_route, dns_1, dns_2 )
      @is_enabled, @default_route, @dns_1, @dns_2 = is_enabled, default_route, dns_1, dns_2 
    end
    
    def to_s
      "<network-nettings: on[#{@is_enabled}] gw[#{@default_route}] dns1[#{@dns_1}] dns2[#{@dns_2}]>"
    end
    
    attr_reader :is_enabled, :default_route, :dns_1, :dns_2
  end

  LOG_FILE = '/var/log/untangle-net-alpaca/alpaca-upgrade.log'
  def initialize
    @dbh = nil
    @logger = Logger.new( LOG_FILE, 10, 1048576 )
  end
  
  ## Load the networking settings from the UVM and convert them into alpaca settings
  def load_settings
    @dbh = DBI.connect('DBI:Pg:uvm', 'postgres')
    begin
      load_network_settings
    ensure
      @dbh.disconnect if @dbh
    end
  end

  private

  def load_network_settings
    @dbh.execute( "SELECT * FROM u_network_settings LIMIT 1" ) do |result|
      result.fetch_all.each do |s|
        @network_settings = 
          NetworkSettings.new( s["is_enabled"], s["default_route"], s["dns_1"], s["dns_2"] )
      end
    end

    ## Delete all of the interfaces on the box (this really should run from scratch)
    Interface.destroy_all
    
    ## Load all of the interfaces on the box
    interfaces = InterfaceHelper.loadInterfaces
    
    return logger.warn( "No interfaces are available, exiting" ) if interfaces.empty?
    
    ## Sort the interfaces by their index
    interfaces.sort! { |a,b| a.index <=> b.index }

    ## A hash of network space ids to interfaces
    bridge_hash = {}

    ## Load them in order
    interfaces.each do |interface|
      if ( interface.wan )
        @external_interface = interface
        if interface.index != InterfaceHelper::ExternalIndex
          @logger.warn( "WAN is not the external interface" )
        end
        
        @logger.debug( "Configuring the external interface" )
        ## Configure the external/wan interface
        configure_external_interface( interface, bridge_hash )
      else
        @logger.debug( "Configuring #{interface}" )
        ## Configure any of the other interfaces
        configure_interface( interface, bridge_hash )
      end
    end
  end
  
  def configure_external_interface( interface, bridge_hash )
    query  = "SELECT network_space, media, is_dhcp_enabled, mtu "
    query += " FROM u_network_intf JOIN u_network_space "
    query += " ON u_network_intf.network_space = u_network_space.rule_id  "
    query += " WHERE u_network_intf.argon_intf = 0"
    mtu = 0
    ns = 0
    @dbh.execute( query ) do |result|
      ## Assuming an interface exists for the external interface.
      row = result.fetch 
      
      ## Update the bridge hash
      ns = row["network_space"].to_i
      bridge_hash[ns] = interface

      ## Configure the media
      m = EthernetMedia.get_value( row["media"] )
      m = EhternetMedia::Auto if m.nil?
      interface.duplex, interface.speed = m.duplex, m.speed

      ## Save the MTU just in case
      mtu = row["mtu"]

      ## First check if it is configured for DHCP.
      if row["is_dhcp_enabled"]
        dynamic = IntfDynamic.new( :mtu => mtu )
        configure_ip_networks( dynamic, ns )
        interface.intf_dynamic = dynamic
        interface.config_type = InterfaceHelper::ConfigType::DYNAMIC
        interface.save
        return
      end
    end

    ## Next check if it is configured for PPPoE
    query = "select * from u_pppoe_connection LIMIT 1"
    @dbh.execute( query ) do |result|
      p = result.fetch
      
      unless p.nil? || !p["live"]
        ## PPPoE settings
        interface.intf_pppoe = IntfPppoe.new( :username => p["username"], :password => p["password"] )
        interface.config_type = InterfaceHelper::ConfigType::PPPOE

        ## XXXX Have to insert the aliases for PPPoE.
        interface.save
        return
      end
    end

    ## Must be configured for a static address
    static = IntfStatic.new
    static.dns_1 = @network_settings.dns_1
    static.dns_2 = @network_settings.dns_2
    static.default_gateway =  @network_settings.default_route
    static.mtu = mtu

    configure_ip_networks( static, ns )

    ## Save the interface as a static
    interface.intf_static = static
    interface.config_type = InterfaceHelper::ConfigType::STATIC
    interface.save
  end

  def configure_interface( interface, bridge_hash )
    ## Two choices, bridge with an already configured interface, or create a new
    ## static.

    mtu = 0
    ns = 0
    
    query  = "SELECT network_space, media, mtu, dmz_host_enabled, dmz_host, "
    query += " nat_address, nat_space, is_nat_enabled "
    query += " FROM u_network_intf JOIN u_network_space "
    query += " ON u_network_intf.network_space = u_network_space.rule_id  "
    query += " WHERE u_network_intf.argon_intf = ?"

    nat_address = nil
    dmz_host = nil
    
    ## First check if it is bridged with another configured interface
    @dbh.execute( query, interface.index - 1 ) do |result|
      row = result.fetch
      
      if row.nil?
        logger.warn( "Nothing is known about the interface #{interface.name}" )
        return
      end

      ## Configure the media
      m = EthernetMedia.get_value( row["media"] )
      m = EhternetMedia::Auto if m.nil?
      interface.duplex, interface.speed = m.duplex, m.speed

      ns = row["network_space"]
      mtu = row["mtu"]
      bridge_interface = bridge_hash[ns]

      ## Always use the external interface if the settings are not on.
      bridge_interface = @external_iterface unless @network_settings.is_enabled
      unless bridge_interface.nil?
        bridge = IntfBridge.new
        bridge.bridge_interface = bridge_interface
        bridge_interface.bridged_interfaces << bridge
        interface.intf_bridge = bridge
        interface.config_type = InterfaceHelper::ConfigType::BRIDGE
        interface.save
        return
      end

      nat_address = get_nat_address( row )
      @dmz_host = get_dmz_host( row )
    end
    
    ## Must be configured for a static address
    static = IntfStatic.new
    static.mtu = mtu
    
    ## Regisiter this interface with the bridge hash
    bridge_hash[ns] = interface

    ## setup the static addresses and aliases
    configure_ip_networks( static, ns )

    ## Configure the NAT policy
    unless nat_address.nil?
      ## Add a NAT policy (this not the external interface)
      nat_policy = NatPolicy.new
      nat_policy.ip = "0.0.0.0"
      nat_policy.netmask = "0"
      nat_policy.new_source = nat_address
      static.nat_policies = [ nat_policy ]
    end

    ## Save the interface as a static
    interface.intf_static = static
    interface.config_type = InterfaceHelper::ConfigType::STATIC
    interface.save
  end


  def configure_ip_networks( config, ns )
    ## Load the ip networks
    query = "select network FROM u_ip_network WHERE space_id=? ORDER BY position"

    position = 1
    
    @dbh.execute( query, ns ) do |result|
      config.ip_networks = []
      result.fetch_all.each do |ipn| 
        ip_network = IpNetwork.new
        ip_network.parseNetwork( ipn["network"] )
        ip_network.position, position = position, position + 1
        
        @logger.debug( "Added the network: #{ip_network}" )
        config.ip_networks << ip_network
      end
    end
  end

  ## Given a row of data, return the address it should be NATd to.
  def get_nat_address( row )
    ## Don't NAT if NAT is not enabled.
    return nil unless row["is_nat_enabled"] == true
    
    nat_address = row["nat_address"]

    ## Use the specified address if it is enabled.    
    return nat_address unless ApplicationHelper::null?( nat_address )

    ## Otherwise use auto (review)
    return "auto"
  end

  def get_dmz_host( row )
    ## Don't use it if it is not enabled.
    return nil unless row["dmz_host_enabled"] == true
    
    dmz_host = row["dmz_host"]
    return nil if ApplicationHelper::null?( dmz_host )

    return dmz_host
  end
  

end
