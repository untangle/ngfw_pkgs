class AlpacaMigration < ActiveRecord::Migration
  def self.up
    ## Create a table for all of the alpaca settings.
    create_table :alpaca_settings do |table|
      ## The configuration level
      table.column :config_level, :integer
    end
    
    add_column :ip_networks, :position, :integer
    add_column :nat_policies, :position, :integer
  end

  def self.down
    drop_table :alpaca_settings
    
    remove_column :ip_networks, :position
    remove_column :nat_policies, :position
  end
end
