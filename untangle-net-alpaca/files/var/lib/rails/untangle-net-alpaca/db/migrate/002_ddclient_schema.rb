class DdclientSchema < ActiveRecord::Migration
  def self.up
    ##Table for dynamic dns ddclient settings
    create_table :ddclient_settings do |table|
      table.column :enabled,        :boolean
      table.column :run_ipup,        :boolean
      table.column :use_ssl,         :boolean
      table.column :daemon, :integer
      table.column :service,        :string
      table.column :protocol,        :string
      table.column :server,          :string
      table.column :login,           :string
      table.column :password,        :string
      table.column :hostname,        :string
    end
  end

  def self.down
    drop_table :ddclient_settings
  end
end
