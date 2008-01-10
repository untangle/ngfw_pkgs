class UvmSubscriptions < ActiveRecord::Migration
  def self.up
    add_column :subscriptions, :system_id, :string
  end

  def self.down
    remove_column :subscriptions, :system_id
  end
end
