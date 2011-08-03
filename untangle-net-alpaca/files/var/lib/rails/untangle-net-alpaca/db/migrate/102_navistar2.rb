# $Id: 102_navistar2.rb,v 1.00 2011/07/27 14:55:15 dmorris Exp $
class Navistar2 < Alpaca::Migration

  def self.up
    newrule = Firewall.find( :first, :conditions => [ "system_id = ?", "route-bridge-traffic-bc218f02" ] )

    # If rules already exist this is an upgrade
    # This rule should not be enabled on upgrades
    # but it is enabled by default on new installs
    if !newrule.nil? 
      # Disable this rule (because this is an upgrade)
      newrule.enabled = false
      newrule.save
    end
  end
  
  def self.down

  end

end
