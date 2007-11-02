class Network < ActiveRecord::Migration
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
    end

    ## This is a single NAT policy.
    create_table :nat_policies do |table|
      table.column :ip, :string
      table.column :netmask, :string
      table.column :new_source, :string
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
    create_table :hostnames do |table|
      table.column :name, :string      
    end

    ## File Overrides
    create_table :file_overrides do |table|
      table.column :position, :integer
      table.column :enabled, :boolean
      table.column :writable, :boolean
      table.column :path, :string
    end

    ## Locale selection
    ## Pretty much just one locale, could do it per user when that gets going.
    create_table :locale_settings do |table|
      table.column :key, :string
    end

    ## DHCP Server settings
    create_table :dhcp_server_settings do |table|
      table.column :enabled, :boolean
      table.column :start, :string
      table.column :end, :string
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
    drop_table :hostnames
    drop_table :file_overrides
    drop_table :locale_settings
    drop_table :dhcp_server_settings
    drop_table :dhcp_static_entries
    drop_table :dns_server_settings
    drop_table :dns_static_entries
  end
end
