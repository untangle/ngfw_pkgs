class UvmSubscriptions < ActiveRecord::Migration
  def self.up
    add_column :subscriptions, :system_id, :string

    s = Subscription.find( :first, :conditions => [ "system_id = ?", DhcpHelper::RuleSystemID ] )
    s = Subscription.new( :system_id => DhcpHelper::RuleSystemID ) if s.nil?
    s.filter = "s-port::67,68&&d-port::67,68&&protocol::udp"
    s.subscribe = false
    s.enabled = true
    s.description = "Pass DHCP traffic."
    s.position = 200
    s.save    
  end

  def self.down
    remove_column :subscriptions, :system_id
  end
end
