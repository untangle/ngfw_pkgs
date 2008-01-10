class CustomSystemRules < ActiveRecord::Migration
  def self.up
    ## Add in a column so that system rules can have a custom flag
    ## which means that another manager will generate them.
    add_column :redirects, :is_custom, :boolean
    add_column :subscriptions, :is_custom, :boolean
    add_column :firewalls, :is_custom, :boolean
  end

  def self.down
    remove_column :redirects, :is_custom
    remove_column :subscriptions, :is_custom
    remove_column :firewalls, :is_custom
  end
end
