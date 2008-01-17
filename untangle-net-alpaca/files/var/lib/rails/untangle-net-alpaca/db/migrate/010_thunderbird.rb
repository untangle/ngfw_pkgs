class Thunderbird < ActiveRecord::Migration
  def self.up
    ## Table for storing the configuration for each of the interfaces
    create_table :interfaces do |table|
      ## Virtual name of the interface
      table.column :name, :string

      ## Interface index
      table.column :index, :integer

      ## True iff this is a WAN interface
      table.column :wan, :boolean

      ## MAC Address of the interface
      table.column :mac_address, :string
      
      ## O/S interface identifier (eg eth0 or en0, can be modified in some cases)
      table.column :os_name, :string
      
      ## BUS Identifier.
      table.column :bus, :string

      ## Vendor identifier.
      table.column :vendor, :string

      ## Duplexing on this interface (half, full or auto)
      ## Review : Do we want to translate?
      table.column :duplex, :string

      ## Speed of the interface (10,100,1000 or auto)
      table.column :speed, :string

      ## Configuration type[static,dynamic,bridge,etc]
      ## Review : Do we want to translate?
      table.column :config_type, :string
    end

    ## This is a single IP network.
    create_table :ip_networks do |table|
      table.column :ip, :string
      table.column :netmask, :string
      table.column :allow_ping, :boolean
      table.column :position, :integer
    end

    ## This is a single NAT policy.
    create_table :nat_policies do |table|
      table.column :ip, :string
      table.column :netmask, :string
      table.column :new_source, :string
      table.column :position, :integer
    end

    ## static interface configuration.
    create_table :intf_statics do |table|
      table.column :interface_id, :integer
      ## Set to 0 for automatic
      table.column :mtu, :integer
      table.column :forward_traffic, :boolean
      
      ## This is only visible on a WAN interface.
      table.column :default_gateway, :string
      table.column :dns_1, :string
      table.column :dns_2, :string
    end

    ## Join between an IP network and a static configuration.
    create_table :intf_statics_ip_networks, :id => false do |table|
      table.column :intf_static_id, :integer
      table.column :ip_network_id, :integer
    end

    ## Join between a static configuration and a NAT Policy.
    create_table :intf_statics_nat_policies, :id => false do |table|
      table.column :intf_static_id, :integer
      table.column :nat_policy_id, :integer
    end

    ## dynamic interface configuration.
    create_table :intf_dynamics do |table|
      table.column :interface_id, :integer

      ## The following are overrides, set to nil to not use
      table.column :ip, :string
      table.column :netmask, :string
      table.column :default_gateway, :string

      ## These are delicate because of the way dns may or may not be handled.
      table.column :dns_1, :string
      table.column :dns_2, :string

      ## Set to -1 for automatic
      table.column :mtu, :integer

      table.column :forward_traffic, :boolean
      table.column :allow_ping, :boolean
    end

    ## Join between an IP network and a static configuration.
    create_table :intf_dynamics_ip_networks, :id => false do |table|
      table.column :intf_dynamic_id, :integer
      table.column :ip_network_id, :integer
    end

    ## Bridge interface configuration
    create_table :intf_bridges do |table|
      table.column :interface_id, :integer

      ## Interface to bridge to
      table.column :bridge_interface_id, :integer
    end

    ## Hostname parameters
    create_table :hostname_settings do |table|
      table.column :hostname, :string
    end

    ## File Overrides
    create_table :file_overrides do |table|
      table.column :position, :integer
      table.column :enabled, :boolean
      table.column :writable, :boolean
      table.column :path, :string
      table.column :description, :string
    end

    ## Locale selection
    ## Pretty much just one locale, could do it per user when that gets going.
    create_table :locale_settings do |table|
      table.column :key, :string
    end

    ## DHCP Server settings
    create_table :dhcp_server_settings do |table|
      table.column :enabled, :boolean
      table.column :start_address, :string
      table.column :end_address, :string

      ## Length of the lease in seconds.
      table.column :lease_duration, :int
      table.column :gateway, :string
      table.column :netmask, :string
    end

    create_table :dhcp_static_entries do |table|
      table.column :position, :integer
      table.column :mac_address, :string
      table.column :ip_address, :string
      table.column :description, :string
    end

    ## DNS Server settings
    create_table :dns_server_settings do |table|
      table.column :enabled, :boolean
      table.column :suffix, :string
    end

    create_table :dns_static_entries do |table|
      table.column :position, :integer
      table.column :hostname, :string
      table.column :ip_address, :string
      table.column :description, :string
    end

    ## REVIEW : These are goings away
    create_table :rules do |table|
      ## parameter type (s-addr, protocol, etc)
      table.column :parameter, :string
      table.column :value, :string
    end

    ## uvm subscription
    create_table :subscriptions do |table|
      table.column :position, :integer
      table.column :enabled, :boolean
      table.column :filter, :string
      table.column :description, :string
      table.column :subscribe, :boolean
      table.column :system_id, :string
      table.column :is_custom, :boolean
    end

    ## redirect rules
    create_table :redirects do |table|
      table.column :position, :integer
      table.column :enabled, :boolean

      ## non-null if this is a system rule, system rules cannot
      ## be deleted or modified by a user, only enabled / disabled.
      table.column :system_id, :string

      table.column :new_ip, :string
      ## this is the encapsulated packet id, aka port.
      table.column :new_enc_id, :string
      table.column :filter, :string
      table.column :description, :string
      table.column :is_custom, :boolean
    end

    ## firewall rules
    create_table :firewalls do |table|
      table.column :position, :integer
      table.column :enabled, :boolean

      ## non-null if this is a system rule, system rules cannot
      ## be deleted or modified by a user, only enabled / disabled.
      table.column :system_id, :string
      
      table.column :target, :string
      table.column :filter, :string

      ## Review : Internationalization
      table.column :description, :string

      table.column :is_custom, :boolean
    end

    ##Table for dynamic dns ddclient settings
    create_table :ddclient_settings do |table|
      table.column :enabled,        :boolean
      table.column :run_ipup,        :boolean
      table.column :use_ssl,         :boolean
      table.column :daemon, :integer
      table.column :service,        :string
      table.column :protocol,        :string
      table.column :server,          :string
      table.column :login,           :string
      table.column :password,        :string
      table.column :hostname,        :string
    end

    ## Create a table for all of the UVM settings
    create_table :uvm_settings do |table|
      ## An orderered list of the interface indices, separated by a comma.
      table.column :interface_order, :string
    end

    ##Table for pppoe settings
    create_table :intf_pppoes do |table|
      table.column :interface_id,    :integer
      table.column :use_peer_dns,    :boolean
      table.column :username,        :string
      table.column :password,        :string
      table.column :dns_1,        :string
      table.column :dns_2,        :string
      table.column :secret_field, :string
    end

    ## Create a table for all of the alpaca settings.
    create_table :alpaca_settings do |table|
      ## The configuration level
      table.column :config_level, :integer
    end

    ##Table for static arps
    create_table :static_arps do |table|
      table.column :rule_id,         :integer
      table.column :hostname,          :string
      table.column :hw_addr,         :string
      table.column :name,            :string
      table.column :category,        :string
      table.column :description,     :string
      table.column :live,            :boolean
      table.column :alert,           :boolean
      table.column :log,             :boolean
    end

    ##Table for static routes
    create_table :network_routes do |table|
      table.column :rule_id,         :integer
      table.column :target,          :string
      table.column :netmask,         :string
      table.column :gateway,         :string
      table.column :name,            :string
      table.column :category,        :string
      table.column :description,     :string
      table.column :live,            :boolean
      table.column :alert,           :boolean
      table.column :log,             :boolean
      table.column :settings_id,     :integer
    end
    
    FileOverride.new( :enabled => true, :writable => true, :description => "Network Configuration",
                      :path => "/etc/network/interfaces" ).save
    FileOverride.new( :enabled => true, :writable => true,
                      :description => "Box Hostname",
                      :path => "/etc/hostname" ).save
    FileOverride.new( :enabled => true, :writable => true, :description => "DNS Server Configuration",
                      :path => "/etc/resolv.conf" ).save
    FileOverride.new( :enabled => true, :writable => true, 
                      :description => "Caching DNS / DHCP server.",
                      :path => "/etc/dnsmasq.conf" ).save
    FileOverride.new( :enabled => true, :writable => true, 
                      :description => "Caching DNS / DHCP server.",
                      :path => "/etc/untangle-net-alpaca/dnsmasq-hosts" ).save
    FileOverride.new( :enabled => true, :writable => true, 
                      :description => "Dynamic DNS Configuration",
                      :path => "/etc/ddclient.conf" ).save
    FileOverride.new( :enabled => true, :writable => true, 
                      :description => "Dynamic DNS Configuration",
                      :path => "/etc/default/ddclient" ).save
    FileOverride.new( :enabled => true, :writable => true,
                      :description => "PPP Passwords",
                      :path => "/etc/ppp/pap-secrets" ).save
    FileOverride.new( :enabled => true, :writable => true, 
                      :description => "ARP Table",
                      :path => "/etc/untangle-net-alpaca/arps" ).save
    FileOverride.new( :enabled => true, :writable => true, 
                      :description => "Routing Table",
                      :path => "/etc/untangle-net-alpaca/routes" ).save
    FileOverride.new( :enabled => true, :writable => true, 
                      :description => "IPTables Rules",
                      :path => "/etc/untangle-net-alpaca/iptables-rules.d/.*" ).save
    FileOverride.new( :enabled => true, :writable => true, 
                      :description => "Network state (caution).",
                      :path => "/etc/network/run/ifstate" ).save
    FileOverride.new( :enabled => false, :writable => false, 
                      :description => "Sample Catchall rule.",
                      :path => "/etc/.*" ).save
  end

  def self.down
    drop_table :interfaces
    drop_table :ip_networks
    drop_table :nat_policies
    drop_table :intf_statics
    drop_table :intf_statics_ip_networks
    drop_table :intf_statics_nat_policies
    drop_table :intf_dynamics
    drop_table :intf_dynamics_ip_networks
    drop_table :intf_bridges
    drop_table :hostname_settings
    drop_table :file_overrides
    drop_table :locale_settings
    drop_table :dhcp_server_settings
    drop_table :dhcp_static_entries
    drop_table :dns_server_settings
    drop_table :dns_static_entries
    drop_table :rules
    drop_table :subscriptions
    drop_table :redirects
    drop_table :firewalls
    drop_table :ddclient_settings
    drop_table :uvm_settings
    drop_table :intf_pppoes
    drop_table :alpaca_settings
    drop_table :static_arps
    drop_table :network_routes
  end
end
