class UvmSchema < ActiveRecord::Migration
  def self.up
    ## Create a table for all of the UVM settings
    create_table :uvm_settings do |table|
      ## An orderered list of the interface indices, separated by a comma.
      table.column :interface_order, :string
    end
  end

  def self.down
    drop_table :uvm_settings
  end
end
