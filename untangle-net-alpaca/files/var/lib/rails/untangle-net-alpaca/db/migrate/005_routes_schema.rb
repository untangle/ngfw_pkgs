class RoutesSchema < ActiveRecord::Migration
  def self.up
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
      table.column :settings_id,     :boolean
    end
  end

  def self.down
    drop_table :network_routes
  end
end
