class UvmSchema < ActiveRecord::Migration
  def self.up
    ## Create a table for the interface ordering
    create_table :uvm_settings do |table|
      ## An orderered list of the interface indices, separated by a comma.
      table.column :interface_order, :string
    end
  end
end
