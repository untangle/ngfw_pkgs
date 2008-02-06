class UvmController < ApplicationController  
  DnsServerSettingsDefaults = { :suffix => "example.com", :enabled => true }

  def manage
    @subscriptions = Subscription.find( :all, :conditions => [ "system_id IS NULL" ] )
    @system_subscription_list = Subscription.find( :all, :conditions => [ "system_id IS NOT NULL" ] )

    render :action => 'manage'
  end

  alias :index :manage

  def create_subscription
    ## Reasonable defaults
    @subscription = Subscription.new( :enabled => true, :subscribe => false, 
                                      :position => -1, :description => "", 
                                      :filter => "d-port::&&protocol::tcp" )
  end

  def edit
    @row_id = params[:row_id]
    raise "unspecified row id" if @row_id.nil?
    
    ## This is questionable
    @subscription = Subscription.new
    @subscription.description = params[:description]
    @subscription.subscribe = params[:subscribe]
    @subscription.enabled = params[:enabled]

    @interfaces, @parameter_list = RuleHelper::get_edit_fields( params )
  end
  
  def save
    ## Review : Internationalization
    if ( params[:commit] != "Save".t )
      redirect_to( :action => "manage" )
      return false
    end
    
    save_user_rules
    
    ## Now update the system rules
    save_system_rules

    ## Commit all of the packet filter rules.
    os["packet_filter_manager"].commit
    
    ## Review : should have some indication that is saved.
    redirect_to( :action => "manage" )
  end

  ## XMLRPC calls.
  def generate_rules
    ## Execute all of the packet filter rules.
    os["packet_filter_manager"].run_services
    nil
  end
  
  def write_files
    ## Load all of the interfaces if the settings haven't been initialized yet.
    if ( Interface.find( :first ).nil? )
      new_interfaces, deleted_interfaces = InterfaceHelper.load_new_interfaces
      new_interfaces.each { |i| i.save }
    end

    ## Write all of the configuration files for the packet filter rules
    ## This also causes the uvm manager to write a few files.
    os["packet_filter_manager"].write_files

    nil
  end

  def session_redirect_create( filter, new_ip, new_port )
    logger.debug( "Creating a new session redirect: #{filter} #{new_ip} #{new_port}" )
    
    os["packet_filter_manager"].session_redirect_create( filter, new_ip, new_port )
    true
  end

  def session_redirect_delete( filter, new_ip, new_port )
    logger.debug( "Deleting a new session redirect: #{filter} #{new_ip} #{new_port}" )
    os["packet_filter_manager"].session_redirect_delete( filter, new_ip, new_port )
    true
  end

  def save_hostname( hostname, save_suffix = false )
    logger.debug( "Saving the hostname: '#{hostname}'" )

    hostname_settings = HostnameSettings.find( :first )
    hostname_settings = HostnameSettings.new if hostname_settings.nil?
    hostname_settings.hostname = hostname
    hostname_settings.save

    ## Update the domain name suffix.
    if save_suffix
      suffix = hostname.sub( /^[^\.]*\./, "" )
      update_dns_server_settings( :suffix => suffix )
    end
    
    os["hostname_manager"].commit
    true
  end

  ## Set the settings up as if this was for the wizard (UVM wizard not the alpaca wizard)
  def wizard_start
    interfaces = InterfaceHelper.loadInterfaces

    internal, external = nil, nil
    interfaces.each do |interface|
      case interface.index
        when InterfaceHelper::ExternalIndex then external = interface
        when InterfaceHelper::InternalIndex then internal = interface
      end
    end
    
    raise "Missing internal or external interface" if external.nil? || internal.nil?

    Interface.destroy_all
    ## Have to save them in order to get valid indices for bridging.
    interfaces.each { |interface| interface.save }

    interfaces.each do |interface|
      case interface.index
      when InterfaceHelper::ExternalIndex 
        ## Configure the external interface for DHCP
        interface.intf_dynamic = IntfDynamic.new
        interface.config_type = InterfaceHelper::ConfigType::DYNAMIC
        
      when InterfaceHelper::InternalIndex 
        ## Configure the internal interface as a static
        static = IntfStatic.new
        static.ip_networks = [ IpNetwork.new( :ip => "192.168.2.1", :netmask => "24", :position => 1 )]
        static.nat_policies = [ NatPolicy.new( :ip => "0.0.0.0", :netmask => "0", :new_source => "auto" )]
        interface.intf_static = static
        interface.config_type = InterfaceHelper::ConfigType::STATIC
      else
        ## Bridge all other interfaces with external
        bridge = IntfBridge.new
        bridge.bridge_interface = external
        external.bridged_interfaces << bridge
        interface.intf_bridge = bridge
        interface.config_type = InterfaceHelper::ConfigType::BRIDGE
      end 

      ## Save the changes to the interface
      interface.save
    end
    
    DhcpServerSettings.destroy_all
    DhcpServerSettings.new( :enabled => true, :start_address => "192.168.2.100", :end_address => "192.168.2.200" ).save

    os["network_manager"].commit

    nil
  end

  def wizard_external_interface_static( ip, netmask, default_gateway, dns_1, dns_2 )
    if netmask.include?( "255." )
      netmask = OSLibrary::NetworkManager::CIDR.index( netmask )
    end
    wizard_manage_interface( InterfaceHelper::ExternalIndex ) do |external_interface|
      static = IntfStatic.new
      static.ip_networks = [ IpNetwork.new( :ip => ip, :netmask => netmask, :position => 1 )]
      static.default_gateway, static.dns_1, static.dns_2 = default_gateway, dns_1, dns_2
      external_interface.intf_static = static
      external_interface.config_type = InterfaceHelper::ConfigType::STATIC
    end
  end

  def wizard_external_interface_dynamic
    wizard_manage_interface( InterfaceHelper::ExternalIndex ) do |external_interface|
      external_interface.intf_dynamic = IntfDynamic.new
      external_interface.config_type = InterfaceHelper::ConfigType::DYNAMIC
    end
  end

  def wizard_external_interface_pppoe( username, password )
    wizard_manage_interface( InterfaceHelper::ExternalIndex ) do |external_interface|
      external_interface.intf_pppoe = IntfPppoe.new( :username => username, :password => password )
      external_interface.config_type = InterfaceHelper::ConfigType::PPPOE
    end
  end

  def wizard_internal_interface_bridge
    wizard_manage_interface( InterfaceHelper::InternalIndex ) do |internal_interface|
      wizard_manage_interface( InterfaceHelper::ExternalIndex, false ) do |external_interface|
        bridge = IntfBridge.new
        bridge.bridge_interface = external_interface
        external_interface.bridged_interfaces << bridge
        internal_interface.intf_bridge = bridge
        internal_interface.config_type = InterfaceHelper::ConfigType::BRIDGE
      end

      ## Disable DHCP and DNS.
      DhcpServerSettings.destroy_all
      DhcpServerSettings.new( :enabled => false, :start_address => "", :end_address => "" ).save

      update_dns_server_settings( :enabled => false )
    end
  end
    
  def wizard_internal_interface_nat( ip, netmask )
    if netmask.include?( "255." )
      netmask = OSLibrary::NetworkManager::CIDR.index( netmask )
    end
    
    wizard_manage_interface( InterfaceHelper::InternalIndex ) do |internal_interface|
      static = IntfStatic.new
      static.ip_networks = [ IpNetwork.new( :ip => ip, :netmask => netmask, :position => 1 )]
      static.nat_policies = [ NatPolicy.new( :ip => "0.0.0.0", :netmask => "0", :new_source => "auto" )]
      internal_interface.intf_static = static
      internal_interface.config_type = InterfaceHelper::ConfigType::STATIC

      ## Enable DHCP and DNS
      DhcpServerSettings.destroy_all
      dhcp_server_settings = DhcpServerSettings.new
      wizard_calculate_dhcp_range( ip, netmask, dhcp_server_settings )
      dhcp_server_settings.save

      update_dns_server_settings( :enabled => true )
    end    
  end

  def scripts
    RuleHelper::Scripts + [ "subscription_manager" ]
  end

  private
  def save_user_rules
    sub_list = []
    subscriptions = params[:subscriptions]
    enabled = params[:enabled]
    subscribe = params[:subscribe]
    filters = params[:filters]
    description = params[:description]

    position = 0
    unless subscriptions.nil?
      subscriptions.each do |key|
        sub = Subscription.new
        sub.system_id = nil
        sub.enabled, sub.filter, sub.subscribe = enabled[key], filters[key], subscribe[key]
        sub.description, sub.position, position = description[key], position, position + 1
        sub_list << sub
      end
    end

    Subscription.destroy_all( "system_id IS NULL" );
    sub_list.each { |sub| sub.save }
  end

  def save_system_rules
    rules = params[:system_subscriptions]
    enabled = params[:system_enabled]
    
    unless rules.nil?
      rules.each do |key|
        ## Skip anything with an empty or null key.
        next if ApplicationHelper.null?( key )

        sub = Subscription.find( :first, :conditions => [ "system_id = ?", key ] )
        next if sub.nil?
        sub.enabled = enabled[key]
        sub.save
      end
    end
  end

  def wizard_manage_interface( interface_index, commit = true )
    interface = Interface.find( :first, :conditions => [ "\"index\" = ?", interface_index ] )
    
    raise "Missing an interface" if interface.nil?
    yield interface

    ## Destroy all of the static entries (just safest to always do this).
    DhcpStaticEntry.destroy_all
    DnsStaticEntry.destroy_all

    interface.save
    
    ## Only commit if told to.
    os["network_manager"].commit if commit

    nil
  end
  
  def wizard_calculate_dhcp_range( ip, netmask, dhcp_server_settings )
    ip = IPAddr.parse( ip )
    netmask = IPAddr.parse( "255.255.255.255/#{netmask}" )

    dhcp_server_settings.enabled = false
    dhcp_server_settings.start_address = "192.168.1.100"
    dhcp_server_settings.end_address = "192.168.1.200"

    ## This will only configure /24 or larger network, the logic for
    ## smaller networks is complicated and isn't really worth it.
    unless ( ip.nil? || netmask.nil? )
      start_address, end_address = nil, nil
      if (( netmask & IPAddr.parse( "0.0.0.255" )) == IPAddr.parse( "0.0.0.0" ))
        ## /24 or larger network
        mask = ip & netmask
        if (( mask | IPAddr.parse( "0.0.0.100" )).to_i > ip.to_i )
          start_address = mask | IPAddr.parse( "0.0.0.100" )
          end_address = mask | IPAddr.parse( "0.0.0.200" )
        else
          start_address = mask | IPAddr.parse( "0.0.0.16" )
          end_address = mask | IPAddr.parse( "0.0.0.99" )
        end
      end
            
      unless ( start_address.nil? || end_address.nil? )
        dhcp_server_settings.enabled = true
        dhcp_server_settings.start_address = start_address.to_s
        dhcp_server_settings.end_address = end_address.to_s
      end
    end
  end
  
  def update_dns_server_settings( params )
    dns_server_settings = DnsServerSettings.find( :first )
    dns_server_settings = DnsServerSettings.new( DnsServerSettingsDefaults ) if dns_server_settings.nil?
    dns_server_settings.update_attributes( params )
    dns_server_settings.save
  end
end
