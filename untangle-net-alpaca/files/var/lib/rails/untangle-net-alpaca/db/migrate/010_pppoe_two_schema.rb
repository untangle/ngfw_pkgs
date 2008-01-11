class PppoeTwoSchema < ActiveRecord::Migration
  def self.up
    ##Table for pppoe settings
    add_column :intf_pppoes, :dns_1, :string
    add_column :intf_pppoes, :dns_2, :string
  end

  def self.down
    remove_column :intf_pppoes, :dns_1, :string
    remove_column :intf_pppoes, :dns_2, :string
  end
end
