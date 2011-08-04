# $Id: 102_navistar2.rb,v 1.00 2011/07/27 14:55:15 dmorris Exp $
class Navistar2 < Alpaca::Migration

  def self.up
    alpaca_settings = AlpacaSettings.find( :first )

    # If rules already exist this is an upgrade
    # This rule should not be enabled on upgrades
    # but it is enabled by default on new installs
    if !alpaca_settings.nil?
      print "This is an Upgrade\n"
      newrule = Firewall.find( :first, :conditions => [ "system_id = ?", "route-bridge-traffic-bc218f02" ] )
      if !newrule.nil? 
        print "Rule found - disabling\n"
        # Disable this rule (because this is an upgrade)
        newrule.enabled = false
        newrule.save
      else
        print "Rule not found - adding a disabled one\n"
        add_firewall_rule( :description => "Route all bridge traffic.",
                           :target => "pass", :is_custom => true,
                           :enabled => false,
                           :system_id => "route-bridge-traffic-bc218f02" )
      end
    end
  end
  
  def self.down

  end

end
