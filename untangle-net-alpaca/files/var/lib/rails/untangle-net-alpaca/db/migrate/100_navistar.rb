
class Navistar < Alpaca::Migration
  def self.up
    drop_table :arp_eater_networks
    drop_table :arp_eater_settings

    # update to new interface order
    uvm_settings = UvmSettings.find( :first )
    uvm_settings = UvmSettings.new if uvm_settings.nil?
    if !uvm_settings.nil? and uvm_settings.interface_order == "1,3,8,2"
      uvm_settings.interface_order = UvmHelper::DefaultOrder
      uvm_settings.save
    end
    if !uvm_settings.nil? and uvm_settings.interface_order == "8"
      uvm_settings.interface_order = UvmHelper::DefaultOrder
      uvm_settings.save
    end
    if !uvm_settings.nil? and uvm_settings.interface_order == "1,3,4,5,6,7,8,2"
      uvm_settings.interface_order = UvmHelper::DefaultOrder
      uvm_settings.save
    end
  end
  
  def self.down
    # original creation format (040)
    create_table :arp_eater_settings do |table|
      table.column :enabled, :boolean, :default => false
      table.column :gateway, :string
      table.column :timeout_ms, :integer
      table.column :rate_ms, :integer
      table.column :broadcast, :boolean
      table.column :interface, :string
    end
    create_table :arp_eater_networks do |table|
      table.column :enabled, :boolean, :default => false
      table.column :description, :string
      table.column :spoof, :boolean
      table.column :passive, :boolean, :default => true
      table.column :ip, :string
      table.column :netmask, :string
      table.column :gateway, :string
      table.column :timeout_ms, :integer
      table.column :rate_ms, :integer
    end

    # later updates (080)
    add_column :arp_eater_networks, :is_spoof_host_enabled, :boolean, :default => true
    add_column :arp_eater_settings, :nat_hosts, :string, :default => ""
  end
end
