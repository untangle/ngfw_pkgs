class Network < ActiveRecord::Migration
  def self.up
    ## Table for storing the configuration for each of the interfaces
    create_table :interfaces do |table|
      ## Virtual name of the interface
      table.column :name, :string

      ## Interface index
      table.column :index, :integer

      ## MAC Address of the interface
      table.column :mac_address, :string
      
      ## BUS Identifier.
      table.column :bus_id, :string

      ## Duplexing on this interface (half, full or auto)
      table.column :duplex, :string

      ## Speed of the interface (10,100,1000 or auto)
      table.column :speed, :string

      ## Configuration type[static,dynamic,bridge,etc]
      table.column :type, :string
    end

    ## This is a single IP network.
    create_table :ip_networks do |table|
      table.column :ip, :string
      table.column :netmask, :string
      table.column :allow_ping, :string
    end

    ## static interface configuration.
    create_table :intf_statics do |table|
      table.column :interface_id, :integer

      table.column :mtu, :integer
      table.column :media, :string
      table.column :speed, :string
      table.column :forward_traffic, :boolean
      table.column :allow_ping, :boolean
    end

    ## Join between an IP network and a static configuration.
    create_table :intf_statics_ip_networks, :id => false do |table|
      table.column :intf_static_id, :integer
      table.column :ip_network_id, :integer
    end

    ## dynamic interface configuration.
    create_table :intf_dynamics do |table|
      table.column :interface_id, :integer

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
  end

  def self.down
    drop_table :interfaces
    drop_table :ip_networks
    drop_table :intf_statics
    drop_table :intf_statics_ip_networks
    drop_table :intf_dynamics
    drop_table :intf_dynamics_ip_networks
    drop_table :intf_bridges
    drop_table :hostnames
  end
end
