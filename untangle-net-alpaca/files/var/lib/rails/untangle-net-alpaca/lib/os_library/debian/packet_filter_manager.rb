#
# $HeadURL$
# Copyright (c) 2007-2008 Untangle, Inc.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License, version 2,
# as published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but
# AS-IS and WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE, TITLE, or
# NONINFRINGEMENT.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA.
#
class OSLibrary::Debian::PacketFilterManager < OSLibrary::PacketFilterManager
  include Singleton
  
  IPTablesCommand = "${IPTABLES}"
  
  Service = "/etc/init.d/untangle-net-alpaca-iptables"

  ConfigDirectory = "/etc/untangle-net-alpaca/iptables-rules.d"
  
  ## If the names of these config files are ever changed, make sure to delete the
  ## old ones.
  
  ## Set to 10, just in case some script wants to do something before flush
  ## For instance, the UVM will want to flush the tune target first, because
  ## it contains all of the queuing rules.
  FlushConfigFile      = "#{ConfigDirectory}/010-flush"
  ChainsConfigFile     = "#{ConfigDirectory}/100-init-chains"
  NetworkingConfigFile = "#{ConfigDirectory}/200-networking"
  FirewallConfigFile   = "#{ConfigDirectory}/400-firewall"

  ## This will block any traffic trying to penetrate NAT.
  NatFirewallConfigFile = "#{ConfigDirectory}/700-nat-firewall"
  RedirectConfigFile   = "#{ConfigDirectory}/600-redirect"

  ModuleConfigFile = "/etc/untangle-net-alpaca/modules.conf"

  ## Mark to indicate that the packet shouldn't be caught by the UVM.
  MarkBypass   = 0x01000000
  
  ## Mark indicating that the packet shouldn't hit the conntrack table.
  MarkNoTrack  = 0x02000000

  ## Mark that causes the firewall to reject a packet.
  MarkFwReject = 0x04000000

  ## Mark that causes the firewall to drop a packet.
  MarkFwDrop   =   0x08000000
  MarkFirstAlias = 0x10000000
  
  ## Mark that indicates a  packet is destined to one of the machines IP addresses
  MarkInput    = 0x00010000

  ## Mark that the packet filter used to indicate that this packet should only be filter
  ## if it is destined to the local box.
  MarkFwInput  = 0x40000000
  MarkClearFwInput = ( 0xFFFFFFFF ^ MarkFwInput )

  MarkFwPass = 0x80000000
  MarkClearFwPass = ( 0xFFFFFFFF ^ MarkFwPass )

  ## Mark that indicates that the packet should be 
  MarkCaptivePortal = 0x800000

  MultiWanMask  = 0x0000FF00
  MultiWanShift = 8

  def register_hooks
    os["network_manager"].register_hook( 100, "packet_filter_manager", "write_files", :hook_write_files )

    os["dns_server_manager"].register_hook( 100, "packet_filter_manager", "commit", :hook_commit )
    
    ## Run whenever the address is updated.
    ## REVIEW : This may just be moved into a script
    ## RESOLUTION : the restart has been moved into a script, any rule modification
    ## requires additional scripts will be done in a .d directory.
  end
  
  class Chain
    def initialize( name, table, start_chains, init = "" )
      @name, @table = name, table
      ## This is done as an eval so that functions like args can be used
      ## in the scrpt
      @init = eval( "String.new( \"#{init}\" )" )
      
      ## Prepend
      unless start_chains.nil?
        start_chains = [ start_chains ].flatten
        start_chains.each do |chain|
          @init = "#{IPTablesCommand} -t #{table} -A #{chain} -j #{name}\n" + @init
        end
      end
    end
    
    def to_s
      name
    end

    def args
      "-t #{table} -A #{name}"
    end

    attr_reader :name, :table, :init

    MarkInterface = Chain.new( "markintf", "mangle", "PREROUTING", <<'EOF' )
## Clear out all of the bits for the interface mark
#{IPTablesCommand} #{args} -j MARK --and-mark 0xFFFF0000
#{IPTablesCommand} #{args} -j CONNMARK --restore-mark --mask #{MultiWanMask}
EOF

    ## Chain Used for natting in the prerouting table.
    PostNat = Chain.new( "alpaca-post-nat", "nat", "POSTROUTING", <<'EOF' )
## Save the state for bypassed traffic
#{IPTablesCommand} -t mangle -A POSTROUTING -m conntrack --ctstate NEW -m connmark --mark 0/#{MultiWanMask} -j CONNMARK --save-mark --mask #{MultiWanMask}

## Do not NAT packets destined to local host.
#{IPTablesCommand} #{args} -o lo -j RETURN
## Do not NAT packets that are destined to the VPN.
#{IPTablesCommand} #{args} -o tun0 -j RETURN
EOF

    ## Chain used to redirect traffic
    Redirect = Chain.new( "alpaca-redirect", "nat", "PREROUTING", <<'EOF' )
EOF

    ## Chain used for actually blocking and dropping data
    FirewallBlock = Chain.new( "alpaca-firewall", "filter", [ "INPUT" ], <<'EOF' )
## Do not block traffic that has the INPUT mark set.
#{IPTablesCommand} -t #{table} -A FORWARD -m mark --mark 0/#{MarkFwInput} -j #{name}

## Ignore any traffic that isn't marked
#{IPTablesCommand} #{args} -m mark --mark 0/#{MarkFwReject | MarkFwDrop} -j RETURN

## Drop any traffic that is marked to drop
#{IPTablesCommand} #{args} -m mark --mark #{MarkFwDrop}/#{MarkFwDrop} -j DROP

## Reset any tcp traffic that is marked to reject.
#{IPTablesCommand} #{args} -p tcp -m mark --mark #{MarkFwReject}/#{MarkFwReject} \
  -j REJECT --reject-with tcp-reset

## Reject all other traffic with ICMP port unreachable
#{IPTablesCommand} #{args} -m mark --mark #{MarkFwReject}/#{MarkFwReject} -j REJECT
EOF

    FirewallNat = Chain.new( "alpaca-nat-firewall", "filter", nil, <<'EOF' )
EOF
    
    ## Chain where all of the firewalls rules should go
    FirewallRules = Chain.new( "firewall-rules", "mangle", "PREROUTING", <<'EOF' )
## mark all sessions with the firewall pass tag
#{IPTablesCommand} #{args} -j MARK --or-mark #{MarkFwPass}
## Ignore any traffic that is related to an existing session
#{IPTablesCommand} #{args} -i lo -j RETURN
#{IPTablesCommand} #{args} -m state --state ESTABLISHED -j RETURN
#{IPTablesCommand} #{args} -m state --state RELATED -j RETURN
EOF
    
    ## Goto chains used to indicate that a packet should be rejected or dropped.
    FirewallMarkReject = Chain.new( "alpaca-pf-reject", "mangle", nil, <<'EOF' )
## Clear the INPUT mark
#{IPTablesCommand} #{args} -j MARK --and-mark #{MarkClearFwInput}
#{IPTablesCommand} #{args} -j MARK --and-mark #{MarkClearFwPass}
## Mark the packets
#{IPTablesCommand} #{args} -j MARK --or-mark #{MarkFwReject}
EOF

    FirewallMarkDrop = Chain.new( "alpaca-pf-drop", "mangle", nil, <<'EOF' )
## Clear the INPUT mark
#{IPTablesCommand} #{args} -j MARK --and-mark #{MarkClearFwInput}
#{IPTablesCommand} #{args} -j MARK --and-mark #{MarkClearFwPass}
## Mark the packets
#{IPTablesCommand} #{args} -j MARK --or-mark #{MarkFwDrop}
EOF

    ## Jumps chains used to indicate that a packet should be rejected or dropped on the INPUT chain
    FirewallMarkInputReject = Chain.new( "alpaca-pfi-reject", "mangle", nil, <<'EOF' )
## Mark the packets
#{IPTablesCommand} #{args} -j MARK --or-mark #{MarkFwReject | MarkFwInput}
EOF

    FirewallMarkInputDrop = Chain.new( "alpaca-pfi-drop", "mangle", nil, <<'EOF' )
## Mark the packets
#{IPTablesCommand} #{args} -j MARK --or-mark #{MarkFwDrop | MarkFwInput}
EOF
    
    ## Chain where traffic should go to be marked for bypass.
    BypassMark = Chain.new( "bypass-mark", "mangle", nil, <<'EOF' )
## Mark the packets
#{IPTablesCommand} #{args} -j MARK --or-mark #{MarkBypass}
## Connmark the packets
#{IPTablesCommand} #{args} -j CONNMARK --set-mark #{MarkBypass}/#{MarkBypass}
EOF

    ## Chain where all of the Bypass Rules go (This shouldn't be  defined unless
    ## There is a UVM, but it should only be a minor performance hit
    BypassRules = Chain.new( "bypass-rules", "mangle", "PREROUTING", <<'EOF' )
## Accept any packets that are connmarked with the bypass mark
#{IPTablesCommand} #{args} -m connmark --mark #{MarkBypass}/#{MarkBypass} -g #{Chain::BypassMark}
EOF

    ## These are only used in classy NAT mode.
    SNatRules = Chain.new( "snat-rules", "nat", nil, <<'EOF' )
EOF

    ## Chain used for captive portal
    CaptivePortal = Chain.new( "untangle-cpd", "mangle", "PREROUTING" )

    ## Chain used to capture / drop traffic for the captive portal.
    CaptivePortalCapture = Chain.new( "untangle-cpd-capture", "mangle", nil )

    ## Review : Should the Firewall Rules go before the redirects?
    Order = [ MarkInterface, PostNat, SNatRules,
              FirewallBlock, FirewallMarkReject, FirewallMarkDrop, 
              FirewallMarkInputReject, FirewallMarkInputDrop, FirewallNat,
              FirewallRules, 
              BypassRules, BypassMark, CaptivePortal, CaptivePortalCapture, Redirect ]
  end
  
  def hook_commit
    write_files
    run_services
  end

  def hook_write_files
    ## Clean directory
    clean_files

    ## Script to flush all of the iptables rules
    write_flush

    ## Script to initialize any custom chains we use.
    write_chains_config
    
    ## Script to initialize all of the network / NAT rules
    write_networking

    ## Script to initialize all of the filtering rules
    write_firewall
    
    # Script to initialize all of the redirect rules
    write_redirect
    
    # Write the configuration script for the modules.
    write_module_script
  end

  def hook_run_services
    raise "Unable to iptables rules." unless run_command( "#{Service} restart" ) == 0
  end

  def session_redirect_create( filter, new_ip, new_port )
    parse_session_redirect( filter, new_ip, new_port )

    `iptables -t nat -I #{Chain::Redirect} 1 #{filter} -j DNAT --to-destination #{new_ip}:#{new_port}`
    `iptables -t mangle -I #{Chain::FirewallRules} 1 #{filter} -j RETURN`    
  end

  def session_redirect_delete( filter, new_ip, new_port )
    parse_session_redirect( filter, new_ip, new_port )
    `iptables -t mangle -D #{Chain::FirewallRules} #{filter} -j RETURN`
    `iptables -t nat -D #{Chain::Redirect} #{filter} -j DNAT --to-destination #{new_ip}:#{new_port}`
  end
  
  private

  ## This is used to handle files that have been moved, this list should never get shorter!
  def clean_files
    [ "500-nat-firewall", "700-uvm" ].each do |file_name|
      os["override_manager"].rm_file( "#{ConfigDirectory}/#{file_name}" )
    end
  end
    
  def write_flush
    text = header
    
    ## The space before the for is so that emacs parses this line properly.
    text += <<EOF
## Flush all of the rules.
 for t_table in `cat /proc/net/ip_tables_names` ; do #{IPTablesCommand} -t ${t_table} -F ; done

echo > /dev/null
EOF

    os["override_manager"].write_file( FlushConfigFile, text, "\n" )
  end

  def write_chains_config
    ## insert the commands to create all of the tables
    text = header
    text << Chain::Order.map do |chain|
      <<EOF
#{IPTablesCommand} -t #{chain.table} -N #{chain.name} 2> /dev/null
#{IPTablesCommand} -t #{chain.table} -F #{chain.name}
#{chain.init}
EOF
    end.join( "\n" )
    
    os["override_manager"].write_file( ChainsConfigFile, text, "\n" )
  end
  
  def write_networking
    text = []
    fw_text = []
    
    text << header
    fw_text << header
    
    ## A little function for marking an interface.
    text << <<EOF
mark_local_ip()
{
   local t_ip
   local t_intf=$1
   local t_index=$2
   local t_mark
   ## Verify the interface was specified.
   test -z "${t_intf}" && return 0
   test -z "${t_index}" && return 0

   local t_first_alias="true"
   t_mark=$(( #{MarkInput} ))
      
   for t_ip in `get_ip_addresses ${t_intf}` ; do
     #{IPTablesCommand} #{Chain::MarkInterface.args} -d ${t_ip} -j MARK --or-mark ${t_mark}

     if [ "${t_first_alias}x" = "truex" ]; then
       #{IPTablesCommand} #{Chain::MarkInterface.args} -i ${t_intf} -d ${t_ip} -j MARK --or-mark $(( #{MarkFirstAlias} ))
     fi
     t_first_alias="false"
   done
}

get_pppoe_name()
{
   local t_script
   t_script=/usr/share/untangle-net-alpaca/scripts/get_pppoe_name
   if [ -x "${t_script}" ]; then
     ${t_script} $1
   else
     echo "ppp0"
   fi
}
EOF
    
    alpaca_settings = AlpacaSettings.find( :first )
    alpaca_settings = AlpacaSettings.new if alpaca_settings.nil?
    
    ## This is used to automatically NAT to a different address when using PPPoE.
    nat_automatic_target = "MASQUERADE"
    
    conditions = [ "wan=? and config_type=?", true, InterfaceHelper::ConfigType::PPPOE ]
    pppoe_interfaces = Interface.find( :all, :conditions => conditions )
    
    ## if the WAN interface is configured for PPPoE, automatically NAT to the first alias.
    unless pppoe_interfaces.nil? || pppoe_interfaces.empty?
      ## If one exists, NAT to the first user defined IP Network
      pppoe_interfaces.each do |interface|
        pppoe_config = interface.intf_pppoe
        next if pppoe_config.nil?
        
        pppoe_name = pppoe_variable_name( interface )
        text << "#{pppoe_name}=`get_pppoe_name #{interface.os_name}`"

        ip_network = pppoe_config.ip_networks[0]
        next if ip_network.nil? || ip_network.ip.nil?

        nat_automatic_target = [] unless nat_automatic_target.is_a?( Array )
        nat_automatic_target << "SNAT --to-source #{ip_network.ip} -o  ${#{pppoe_name}}" 
      end
    end
    
    interface_list = Interface.find( :all )
    
    wan_interfaces = []

    interface_list.each do |interface|
      if interface.wan and ( interface.config_type != InterfaceHelper::ConfigType::BRIDGE )
        wan_interfaces << interface
      end
    end

    ## Find all of the interfaces that are bridged to wan interfaces
    wan_interfaces.each do |interface|
      wan_interfaces += interface.bridged_interface_array
    end

    ## Remove all of the duplicates
    wan_interfaces = wan_interfaces.uniq
    non_wan_interfaces = interface_list - wan_interfaces

    if ( alpaca_settings.classy_nat_mode )
      ## This is all of the traffic that will hit the NAT rules.  The NAT rules
      ## Determine if the sessions originated from an IP that needs to be NATd
      ## So sessions may hit the NAT rules, and not be NATed.
      
      ## NAT Sessions that are DNATd.
      text << "#{IPTablesCommand} #{Chain::PostNat.args} -m conntrack --ctstate DNAT -j #{Chain::SNatRules}"
      
      ## NAT Sessions that are going out WAN Interface
      wan_interfaces.each do |wan_interface|
        if ( wan_interface.config_type == InterfaceHelper::ConfigType::BRIDGE )
          next
        end

        i_name = wan_interface.os_name
        if ( wan_interface.is_bridge? )
          i_name = OSLibrary::Debian::NetworkManager.bridge_name( wan_interface )
        end

        if ( wan_interface.config_type == InterfaceHelper::ConfigType::PPPOE )
          i_name = "${#{pppoe_variable_name(wan_interface)}}"
        end

        text << "#{IPTablesCommand} #{Chain::PostNat.args} -o #{i_name} -j #{Chain::SNatRules}"

        ## Firewall NAT rules apply to all of the traffic from WAN interfaces
        fw_text << "#{IPTablesCommand} -t filter -A FORWARD -i #{i_name} -g #{Chain::FirewallNat}"
      end

      ## Ignore DNATd traffic
      fw_text << "#{IPTablesCommand} #{Chain::FirewallNat.args} -m conntrack --ctstate DNAT -j RETURN"
      ## Ignore traffic with the passed mark
      fw_text << "#{IPTablesCommand} #{Chain::FirewallNat.args} -m mark --mark #{MarkFwPass}/#{MarkFwPass} -j RETURN"

      ## Added an exception for unNATed interfaces (these should allow traffic just like normal routed interfaces
      non_wan_interfaces.each do |interface|
        ## Drop all WAN traffic that is going to a non-wan NATed interface
        ## non-wan non-NATd interfaces should have traffic allowed like normal routed traffic
        if (interface.nat_policies != nil)
          fw_text << "#{IPTablesCommand} #{Chain::FirewallNat.args} -o #{interface.os_name} -j DROP"
        end
      end
      
      ## Drop traffic going to the VPN interface that is not allowed.
      fw_text << "#{IPTablesCommand} #{Chain::FirewallNat.args} -o tun0 -j DROP"

      text.push <<EOF

add_destination_nat_rule()
{
  local t_network=$1
  local t_new_source=$2

  local t_intf=`ip -f inet addr show to ${t_new_source} | awk '/^[0-9]/ { sub( ":","",$2 ); print $2 ; exit}'`
  local t_pppoe
  
  if [ -z "${t_intf}" ]; then
    #{IPTablesCommand} #{Chain::SNatRules.args} -s ${t_network} -j SNAT --to-source ${t_new_source}
    return
  fi

  #{IPTablesCommand} #{Chain::SNatRules.args} -o ${t_intf} -s ${t_network} -j SNAT --to-source ${t_new_source}

  [ "${t_intf#ppp}" != "${t_intf}" ] && return

  t_pppoe=`/usr/share/untangle-net-alpaca/scripts/get_pppoe_name ${t_intf}`
  [ -z "${t_pppoe}" ] && return
  [ "${t_pppoe}" = "ppp.${t_intf}" ] && return
  
  #{IPTablesCommand} #{Chain::SNatRules.args} -o ${t_pppoe} -s ${t_network} -j SNAT --to-source ${t_new_source}
}

EOF

    end
    
    text << "#{IPTablesCommand} -t mangle -I OUTPUT 1 -j CONNMARK --restore-mark --mask #{MultiWanMask}"

    

    interface_list.each do |interface|

      ## labelling
      text << marking( interface )
      
      ## Insert the commands to filter traffic
      text << filtering( interface )

      ## If the interface is not a WAN itself (WAN interfaces don't have NAT policies)
      if ( !interface.wan ) 
        ## Insert the commands to handle NAT
          if ( alpaca_settings.classy_nat_mode )
            a, b = classy_nat( wan_interfaces, interface, nat_automatic_target )
          else
            a, b = nat( wan_interfaces, interface, nat_automatic_target )
          end
      end
      text << a
      fw_text << b 
    end

    block_all = Firewall.find( :first, :conditions => [ "system_id = ?", "block-all-local-04a98864"] )

    if !block_all.nil? && block_all.enabled
      ##A little rule to block all local traffic, done here so that custom items can
      ## insert rules in between.
      fw_text << "#{IPTablesCommand} #{Chain::FirewallRules.args} -j #{Chain::FirewallMarkInputDrop.name}"
    end

    ## Allow traffic to the test IP, this is useful for people who don't know their IP.
    fw_text << "#{IPTablesCommand} #{Chain::FirewallRules.args} -p tcp --destination-port 443 -d 192.0.2.42 -j RETURN"

    ## This is a special rule to block access to the dummy bind address.  Traffic
    ## should always be redirected to the dummy interface (unless it came in over lo.)
    ## which is ignored above.
    fw_text << "#{IPTablesCommand} #{Chain::FirewallRules.args} -d 192.0.2.42 -j DROP"
    ## Clear the FwPass mark at the end
    fw_text << "#{IPTablesCommand} #{Chain::FirewallRules.args} -j MARK --and-mark #{MarkClearFwPass}"

    ## Delete all empty or nil parts
    text = text.delete_if { |p| p.nil? || p.empty? }
    fw_text = fw_text.delete_if { |p| p.nil? || p.empty? }
    
    os["override_manager"].write_file( NetworkingConfigFile, text.join( "\n" ), "\n" )
    os["override_manager"].write_file( NatFirewallConfigFile, fw_text.join( "\n" ), "\n" )
  end

  def write_firewall
    rules = Firewall.find( :all, :conditions => [ "system_id IS NULL AND enabled='t'" ] )
    rules += Firewall.find( :all, :conditions => [ "system_id IS NOT NULL AND enabled='t'" ] )
    
    text = header + "\n"

    rules.each do |rule|
      begin
        filters, chain = OSLibrary::Debian::Filter::Factory.instance.filter( rule.filter )
        
        next text << handle_custom_firewall_rule( rule ) if rule.is_custom
        
        target = nil
        case rule.target
        when "pass"
          target = "-j RETURN"
          
        when "drop"
          target = "-g #{Chain::FirewallMarkDrop.name}"
          target = "-j #{Chain::FirewallMarkInputDrop.name}" if /d-local::true/.match( rule.filter )
          
        when "reject"
          target = "-g #{Chain::FirewallMarkReject.name}"
          target = "-j #{Chain::FirewallMarkInputReject.name}" if /d-local::true/.match( rule.filter )
        end
        
        next if target.nil?
            
        filters.each do |filter|
          ## Nothing to do if the filtering string is empty.
          break if filter.strip.empty?
          text << "#{IPTablesCommand} #{Chain::FirewallRules.args} #{filter} #{target}\n"
        end
      rescue
        logger.warn( "The packet filter rule '#{rule.id}' '#{rule.filter}' could not be parsed: #{$!}" )
      end
    end

    os["override_manager"].write_file( FirewallConfigFile, text, "\n" )    
  end

  def write_redirect
    rules = Redirect.find( :all, :conditions => [ "system_id IS NULL AND enabled='t'" ] )
    rules += Redirect.find( :all, :conditions => [ "system_id IS NOT NULL AND enabled='t'" ] )

    text = header
    rules.each do |rule|
      begin
        filters, chain = OSLibrary::Debian::Filter::Factory.instance.filter( rule.filter )

        ## Always use PREROUTING nat.
        chain = "PREROUTING"
        
        destination = rule.new_ip
        new_enc_id = rule.new_enc_id

        next if rule.is_custom

        next if ApplicationHelper.null?( destination )
        
        ## Try to parse the new ip
        raise "unable to parse the destination #{destination}" if IPAddr.parse( "#{destination}/32" ).nil?
        
        unless ApplicationHelper.null?( new_enc_id )
          raise "Invalid port redirect '#{new_enc_id}'" unless RuleHelper.is_valid_port?( new_enc_id )
          destination += ":#{new_enc_id}"
        end
            
        filters.each do |filter|
          ## Nothing to do if the filtering string is empty.
          break if filter.strip.empty?
          text << "#{IPTablesCommand} #{Chain::Redirect.args} #{filter} -j DNAT --to-destination #{destination}\n"
        end
      rescue
        logger.warn( "The port forward rule '#{rule.filter}' could not be parsed: #{$!}" )
        logger.warn( $!.backtrace.join( "\n" ) )
      end
    end

    os["override_manager"].write_file( RedirectConfigFile, text, "\n" )    
  end

  ## REVIEW Need some way of labelling bridges, this means it needs an index.
  ## bridges right now are somewhat of a virtual concept (see is_bridge in interface).
  ## so indexing them is tough.
  ## Interface labelling
  def marking( interface )
    match = "-i #{interface.os_name}"
    
    ## This is the name used to retrieve the ip addresses.
    name = interface.os_name

    pppoe_name = pppoe_variable_name( interface )

    rules = []

    ## use the pppoe name if this is a PPPoE interface.
    if ( interface.config_type == InterfaceHelper::ConfigType::PPPOE )
      match = "-i ${#{pppoe_name}}"
    elsif interface.is_bridge?
      match = "-m physdev --physdev-in #{interface.os_name}"
    end
    
    ## This is the name that is used to retrieve the local addresses.
    if interface.is_bridge?
      name = OSLibrary::Debian::NetworkManager.bridge_name( interface )
    end
    
    index = interface.index
    #mask = 1 << ( index - 1 )
    mask = index

    rules << "#{IPTablesCommand} #{Chain::MarkInterface.args} #{match} -j MARK --or-mark #{mask}"

    if interface.wan
      rules << "#{IPTablesCommand} #{Chain::MarkInterface.args} #{match} -m conntrack --ctstate NEW -j CONNMARK --set-mark #{index << MultiWanShift}/#{MultiWanMask}"
    end
    
    if ( interface.config_type != InterfaceHelper::ConfigType::BRIDGE )
      rules << "mark_local_ip #{name} #{index}"
    end
    
    ## Append a mark for the ppp local addresses.
    if ( interface.config_type == InterfaceHelper::ConfigType::PPPOE )
      rules << "mark_local_ip ${#{pppoe_name}} #{index}"
    end

    rules.join( "\n" )
  end
  
  def write_module_script
    alpaca_settings = AlpacaSettings.find( :first )
    alpaca_settings = AlpacaSettings.new if alpaca_settings.nil?

    text = [ header ]
    modules_enabled = alpaca_settings.modules_enabled 
    unless ApplicationHelper.null?( modules_enabled )
      text << "ENABLED_MODULES='#{modules_enabled}'"
    end

    modules_disabled = alpaca_settings.modules_disabled 
    unless ApplicationHelper.null?( modules_disabled )
      text << "DISABLED_MODULES='#{modules_disabled}'"
      modules_disabled.split.each do |m|
        text << "DISABLE_MODULE_#{m}='true'"
      end
    end

    os["override_manager"].write_file( "#{ModuleConfigFile}", text.join( "\n" ), "\n" )
  end
  
  def filtering( interface )
    
  end
  
  ## REVIEW This doesn't support discontiguous netmasks (like 255.0.255.0) (but neither does ifconfig, so who cares)
  ## REVIEW should put 0.0.0.0/0 at the bottom.
  ## REVIEW how should auto work, right now it just uses MASQUERADE.

  ## When the nat_automatic_target is not MASQUERAGE, then this adds
  ## two NAT rules.  One for SNAT if it is destined out this interface
  ## and one for MASQUERADE if it isn't.  This is a special case where
  ## the user has an alias.  You can't always SNAT it because then it
  ## couldn't load balance at all.
  def nat( wan_interfaces, interface, nat_automatic_target )
    ## static is the only config type that supports NATing
    config = interface.current_config

    return nil if ( config.nil? || !config.is_a?( IntfStatic ))
    
    ## Nothing to nat if there are no NAT policies
    nat_policies = config.nat_policies
    return nil if ( nat_policies.nil? || nat_policies.empty? )

    ## Determine the name of the interface
    rules = []
    fw_rules = []

    nat_policies.each do |policy|      
      ## Global netmask, use the addresses for the interface
      if ( policy.netmask == "0" || policy.netmask == "0.0.0.0" )
        config.ip_networks.each do |ip_network|
          add_nat_rule( rules, fw_rules, interface, policy, nat_automatic_target, ip_network.ip, ip_network.netmask )
        end
      else
        add_nat_rule( rules, fw_rules, interface, policy, nat_automatic_target, policy.ip, policy.netmask )
      end
    end

    [ rules.join( "\n" ), fw_rules.join( "\n" ) ]
  end

  def add_nat_rule( rules, fw_rules, interface, policy, nat_automatic_target, network, netmask )
    os_name = interface.os_name
    os_name = OSLibrary::Debian::NetworkManager.bridge_name( interface ) if interface.is_bridge?    

    ## REVIEW : Need to handle the proper ports.
    ## REVIEW : Need to use the correct interface marks, but that needs a bridge mark
    network = "#{network}/#{OSLibrary::NetworkManager.parseNetmask( netmask )}"

    if ( policy.new_source == NatPolicy::Automatic )
      if nat_automatic_target != "MASQUERADE"
        nat_automatic_target.each do |target|
          rules << "#{IPTablesCommand} #{Chain::PostNat.args} -m conntrack ! --ctorigdst #{network} -s #{network} -j #{target}"
        end
      end
      
      rules << "#{IPTablesCommand} #{Chain::PostNat.args} -m conntrack ! --ctorigdst #{network} -s #{network} -j MASQUERADE"
    else
      rules << "#{IPTablesCommand} #{Chain::PostNat.args} -m conntrack ! --ctorigdst #{network} -s #{network} -j SNAT --to-source #{policy.new_source}"
    end

    fw_rules << "#{IPTablesCommand} #{Chain::FirewallRules.args} -i ! #{os_name} -d #{network} -j DROP"
  end
  
  def classy_nat( wan_interfaces, interface, nat_automatic_target )
    ## static is the only config type that supports NATing
    config = interface.current_config

    return nil if ( config.nil? || !config.is_a?( IntfStatic ))
    
    ## Nothing to nat if there are no NAT policies
    nat_policies = config.nat_policies
    return nil if ( nat_policies.nil? || nat_policies.empty? )

    ## Determine the name of the interface
    rules = []
    fw_rules = []
    
    nat_policies.each do |policy|
      if ( policy.new_source == NatPolicy::Automatic )
        
      else
        
      end

      ## Global netmask, use the addresses for the interface
      if ( policy.netmask == "0" || policy.netmask == "0.0.0.0" )
        config.ip_networks.each do |ip_network|
          add_classy_nat_rule( rules, fw_rules, interface, policy, nat_automatic_target, ip_network.ip, ip_network.netmask )
        end
      else
        add_classy_nat_rule( rules, fw_rules, interface, policy, nat_automatic_target, policy.ip, policy.netmask )
      end
    end

    [ rules.join( "\n" ), fw_rules.join( "\n" ) ]    
  end

  def add_classy_nat_rule( rules, fw_rules, interface, policy, nat_automatic_target, network, netmask )
    os_name = interface.os_name
    os_name = OSLibrary::Debian::NetworkManager.bridge_name( interface ) if interface.is_bridge?    

    network = "#{network}/#{OSLibrary::NetworkManager.parseNetmask( netmask )}"

    if ( policy.new_source == NatPolicy::Automatic )
      if nat_automatic_target != "MASQUERADE"
        nat_automatic_target.each do |target|
          rules << "#{IPTablesCommand} #{Chain::SNatRules.args} -s #{network} -j #{target}"
        end
      end
      
      rules << "#{IPTablesCommand} #{Chain::SNatRules.args} -s #{network} -j MASQUERADE"
    else
      rules << "add_destination_nat_rule #{network} #{policy.new_source}"
    end
  end

  def pppoe_variable_name( interface )
    return "PPPOE_INTERFACE_#{interface.os_name.upcase}"
  end

  def header
    <<EOF
#!/bin/dash

## #{Time.new}
## Auto Generated by the Untangle Net Alpaca
## If you modify this file manually, your changes
## may be overriden

EOF
  end

  def parse_session_redirect( filter, new_ip, new_port )
    raise "Invalid filter: '#{filter}'" if /^[-a-zA-Z0-9._ ]*$/.match( filter ).nil?
    
    raise "Invalid destination '#{new_ip}'" if IPAddr.parse_ip( new_ip ).nil?

    ## Convert new_port to a number
    new_port_string = new_port.to_s
    
    new_port = new_port.to_i.to_s
    raise "Invalid redirect port '#{new_port_string}'" unless ( new_port == new_port_string )
  end

  def handle_custom_firewall_rule( rule )
    case rule.system_id

    when "accept-dhcp-internal-e92de349"
      ## Accept traffic to the DHCP server on the Internal interface
      #mark = 1 << ( InterfaceHelper::InternalIndex - 1 )
      mark = InterfaceHelper::InternalIndex
      return "#{IPTablesCommand} -t filter -I INPUT 1 -p udp -m mark --mark #{mark}/#{mark} -m multiport --destination-ports 67 -j RETURN\n"

    when "accept-dhcp-dmz-7a5a003c"
      ## Accept traffic to the DHCP server on the DMZ interface
      #mark = 1 << ( InterfaceHelper::DmzIndex - 1 )
      mark = InterfaceHelper::DmzIndex
      return "#{IPTablesCommand} -t filter -I INPUT 1 -p udp -m mark --mark #{mark}/#{mark} -m multiport --destination-ports 67 -j RETURN\n"

    when "block-dhcp-remaining-58b3326c"
      ## Block remaining DHCP traffic to the server.
      return "#{IPTablesCommand} -t filter -A INPUT -p udp -m multiport --destination-port 67 -j DROP\n"

    when "control-dhcp-cb848bea"
      ## Limit DHCP traffic to the Internal interface
      dhcp_server_settings = DhcpServerSettings.find( :first )

      ## No need to control DHCP if we are not running a server
      return "" if ( dhcp_server_settings.nil? || !dhcp_server_settings.enabled )

      i = Interface.find( :first, :conditions => [ "\"index\" = ?", InterfaceHelper::InternalIndex ] )
      return "" if i.nil? || i.os_name.nil?

      ## Drop dhcp responses from being forwarded to the internal interface.
      return "#{IPTablesCommand} -t mangle -A FORWARD -p udp -m multiport --destination-ports 67,68 -m physdev --physdev-is-bridged --physdev-out #{i.os_name} -j DROP\n" +
        "#{IPTablesCommand} -t mangle -A FORWARD -p udp -m multiport --destination-ports 67,68 -m physdev --physdev-is-bridged --physdev-in #{i.os_name} -j DROP\n"

    when "accept-dhcp-client-43587bff"
      ## Accept all traffic to the local DHCP client
      return "#{IPTablesCommand} -t filter -I INPUT 1 -p udp -m multiport --destination-ports 68 -j RETURN\n"
    else return ""
    end
  end
end
