class ArpsSchema < ActiveRecord::Migration
  def self.up
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
  end

  def self.down
    drop_table :static_arps
  end
end
