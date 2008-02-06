## Script run at startup to register all of the sytem rules.

## Review: This should be broken into individual modules.

module Alpaca::SystemRules
  
  class RuleManager
    include Singleton

    ## A hash of all of the different type of system rules, used at startup.
    ## ( <class> -> <array-of-rules.
    def initialize
      @global_rules = {}
    end

    def add_redirect_rule( v )
      add_rule( Redirect, v )
    end
    
    def add_firewall_rule( v )
      add_rule( Firewall, v )
    end
    
    def add_bypass_rule( v )
      add_rule( Subscription, v )
    end

    ## Call once at the end to delete all of the existing rules and replace them
    ## with the new ones (the enable flags are saved)
    def save_rules
      ## Review
      ## If something goes wrong here, settings could be lost.
      [ Redirect, Firewall, Subscription ].each do |t|
        t.destroy_all( "system_id IS NOT NULL" )
      end

      ## Iterate each of the types, and save all of its rules.
      @global_rules.each do |t,rules|
        rules.each { |rule| rule.save }
      end
    end

    private
    
    ## Generic function for adding various types of functions.
    def add_rule( t, v )
      rules = @global_rules[t]
      @global_rules[t] = rules = [] if rules.nil?
      
      current = t.find( :first, :conditions => [ "system_id = ?", v[:system_id]] )
      
      v[:enabled] = true if v[:enabled].nil?

      rule = t.new( v )
      rule.enabled = current.enabled unless current.nil?

      rule.position = rules.length + 1

      ## Append the rule
      rules << rule
    end
  end
  
  def self.insert_system_rules
    rm = RuleManager.instance
    
    rm.add_firewall_rule( :description => "Allow DHCP Requests from the internal interface.",
                          :filter => "", :is_custom => true,
                          :system_id => "accept-dhcp-internal-e92de349" )

    ## Disabled by default.
    rm.add_firewall_rule( :description => "Allow DHCP Requests from the DMZ interface..",
                          :filter => "", :enabled => false, :is_custom => true,
                          :system_id => "accept-dhcp-dmz-7a5a003c" )
    
    rm.add_firewall_rule( :description => "Block all DHCP Requests to the local DHCP Server.",
                          :filter => "", :is_custom => true,
                          :system_id => "block-dhcp-remaining-58b3326c" )

    rm.add_firewall_rule( :description => "Control DHCP Traffic from non-internal interfaces.",
                          :filter => "", :is_custom => true,
                          :system_id => "control-dhcp-cb848bea" )

    rm.add_firewall_rule( :description => "Accept DHCP traffic to the local DHCP client.",
                          :filter => "", :is_custom => true,
                          :system_id => "accept-dhcp-client-43587bff" )

    rm.add_firewall_rule( :description => "Accept DNS traffic from the Internal and VPN interfaces to the local DNS Server.",
                          :filter => "d-local::true&&s-intf::2,8&&d-port::53&&protocol::udp",
                          :target => "pass",
                          :system_id => "accept-dns-internal-cbd25823" )
    
    rm.add_firewall_rule( :description => "Accept DNS traffic to the local DNS Server from all interfaces.",
                          :filter => "d-local::true&&d-port::53&&protocol::udp",
                          :target => "pass", :enabled => false,
                          :system_id => "accept-dns-45de53dd" )

    rm.add_firewall_rule( :description => "Accept SNMP traffic from the Internal interface.",
                          :filter => "d-local::true&&s-intf::2&&d-port::161&&protocol::udp",
                          :target => "pass",
                          :system_id => "accept-snmp-internal-0b50244c" )
    
    rm.add_firewall_rule( :description => "Accept SNMP traffic from all interfaces.",
                          :filter => "d-local::true&&d-port::161&&protocol::udp",
                          :target => "pass", :enabled => false,
                          :system_id => "accept-snmp-029571bd" )

    rm.add_firewall_rule( :description => "Accept OpenVPN traffic from all interfaces.",
                          :filter => "d-local::true&&d-port::1194&&protocol::udp",
                          :target => "pass",
                          :system_id => "accept-openvpn-4ebba2eb" )

    rm.add_firewall_rule( :description => "Accept SSH traffic from all interfaces.",
                          :filter => "d-local::true&&d-port::22&&protocol::tcp",
                          :target => "pass",
                          :system_id => "accept-ssh-40be25e3" )

    rm.add_firewall_rule( :description => "Accept ICMP on all interfaces.",
                          :filter => "d-local::true&&protocol::icmp",
                          :target => "pass",
                          :system_id => "accept-icmp-30d37e70" )

    ## This rule is custom because it is added to the NAT firewall rather than to
    ## basic firewall.
    rm.add_firewall_rule( :description => "Block all local traffic.",
                          :filter => "d-local::true",
                          :target => "drop", :is_custom => true,
                          :system_id => "block-all-local-04a98864" )

    ## Bypass Rules
    rm.add_bypass_rule( :description => "Bypass DHCP Traffic",
                        :system_id => DhcpHelper::RuleSystemID,
                        :filter => "s-port::67,68&&d-port::67,68&&protocol::udp",
                        :subscribe => false )

    ## Add a bypass rule to pass IPSec traffic.
    rm.add_bypass_rule( :description => "Bypass IPsec VPN Traffic",
                        :enabled => true,
                        :system_id => "bypass-ipsec-vpn-traffic-0f37eb65",
                        :filter => "d-port::500&&protocol::udp",
                        :subscribe => false )

    ## Add a bypass rule to pass PPTP traffic.
    rm.add_bypass_rule( :description => "Bypass PPTP Traffic",
                        :enabled => true,
                        :system_id => "bypass-pptp-traffic-4eabdb61",
                        :filter => "d-port::1723&&protocol::tcp",
                        :subscribe => false )

    ## Add a bypass rule to allow VOIP traffic on IAX and SIP.
    rm.add_bypass_rule( :description => "Bypass  VOIP Traffic (SIP)",
                        :enabled => true,
                        :system_id => "bypass-voip-sip-traffic-2df1273f",
                        :filter => "d-port::5060&&protocol::tcp,udp",
                        :subscribe => false )

    rm.add_bypass_rule( :description => "Bypass  VOIP Traffic (IAX)",
                        :enabled => true,
                        :system_id => "bypass-voip-iax--traffic-8e97ab87",
                        :filter => "d-port::4569&&protocol::udp",
                        :subscribe => false )

    ## Always call this last
    rm.save_rules
  end
end
