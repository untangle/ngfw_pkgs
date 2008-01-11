class PppoeSchema < ActiveRecord::Migration
  def self.up
    ##Table for pppoe settings
    create_table :intf_pppoes do |table|
      table.column :interface_id,    :integer
      table.column :use_peer_dns,    :boolean
      table.column :username,        :string
      table.column :password,        :string
      table.column :dns_1,        :string
      table.column :dns_2,        :string
    end
  end

  def self.down
    drop_table :intf_pppoes
  end
end
