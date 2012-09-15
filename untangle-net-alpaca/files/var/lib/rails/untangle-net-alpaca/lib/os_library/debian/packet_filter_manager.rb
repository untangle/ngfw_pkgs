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
  EBTablesCommand = "${EBTABLES}"
  
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
  MarkLocal    = 0x00010000
  MaskLocalAndFirstAlias = 0x10010000

  ## Mark that the packet filter used to indicate that this packet should only be filter
  ## if it is destined to the local box.
  MarkFwInput  = 0x40000000
  MarkClearFwInput = ( 0xFFFFFFFF ^ MarkFwInput )

  MarkFwPass = 0x80000000
  MarkClearFwPass = ( 0xFFFFFFFF ^ MarkFwPass )

  DstIntfMask  = 0x0000FF00
  DstIntfShift = 8
  SrcIntfMask  = 0x000000FF
  BothIntfMask = 0x0000FFFF

  def register_hooks
    os["network_manager"].register_hook( 100, "packet_filter_manager", "write_files", :hook_write_files )

    os["dns_server_manager"].register_hook( 100, "packet_filter_manager", "commit", :hook_commit )
    
    ## Run whenever the address is updated.
    ## REVIEW : This may just be moved into a script
    ## RESOLUTION : the restart has been moved into a script, any rule modification
    ## requires additional scripts will be done in a .d directory.
  end
  
  class Chain
    def initialize( name, table, start_chains, conditions = "", init = "" )
      @name, @table = name, table
      ## This is done as an eval so that functions like args can be used
      ## in the scrpt
      @init = eval( "String.new( \"#{init}\" )" )
      
      ## Prepend
      unless start_chains.nil?
        start_chains = [ start_chains ].flatten
        start_chains.each do |chain|
          @init = "#{IPTablesCommand} -t #{table} -A #{chain} #{conditions} -j #{name}\n" + @init
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

    MarkInterface = Chain.new( "mark-intf", "mangle", "PREROUTING", "-m addrtype --src-type unicast --dst-type unicast", <<'EOF' )
## Set the interface marks on packets
## Note this only sets the marks on the packets AFTER the session is established
## The connmark stores the src/dest marks for the SESSION
## This will determine the direction of the packet inside that session
## If its an ORIGINAL packet, it will simply restore the intf marks from the connmark
## If its a REPLY packet, it will reverse the intf marks from the connmark
#{IPTablesCommand} #{args} -j MARK --and-mark 0xFFFF0000 -m comment --comment \"Zero out source and destination interface marks\"

## Don use connmark to mark the src/dst intf of broadcast (especially DHCP) packets
## All broadcast packets share the same conntrack
## so DHCP for example all looks like: 0.0.0.0:67 -> 255.255.255.255:68
## so the connmark is not accurate for interface marks
## So to be safe, lets just ignore all traffic that isn't between two unicast addresses
## Everything else will be marked using the slower mark-src-intf and mark-dst-intf
# WARNING The invert check in dst-type does not work in 2.6.26 - it always matches
# So I've commented out these two lines and instead only called this change on unicast packets
# #{IPTablesCommand} #{args} -m addrtype ! --dst-type unicast  -j RETURN -m comment --comment \"Do not use connmark on non unicast sessions, just return\"
# #{IPTablesCommand} #{args} -m addrtype ! --src-type unicast -j RETURN -m comment --comment \"Do not use connmark on non unicast sessions, just return\"

## This rule says if the packet is in the original direction, just copy the intf marks from the connmark/session mark
## The rule actually says REPLY and not ORIGINAL and thats because ctdir seems to match backwards
## The following rule is marked XXX because it seems backwards
#{IPTablesCommand} #{args} -m conntrack --ctdir REPLY -j CONNMARK --restore-mark --mask #{BothIntfMask} -m comment --comment \"If packet is in original direction, copy mark from connmark to packet (XXX)\"

EOF

    MarkSrcInterface = Chain.new( "mark-src-intf", "mangle", "PREROUTING", "", <<'EOF' )
## This chain marks the src intf on the packet
##
## If the src is already marked, just return
#{IPTablesCommand} #{args} -m mark ! --mark 0/#{SrcIntfMask} -j RETURN -m comment --comment \"Return if source interface mark is already set\"
EOF

    MarkDstInterface = Chain.new( "mark-dst-intf", "mangle", "FORWARD", "", <<'EOF' )
## This chain marks the dst intf on the packet
##
## If the dst is already marked AND the packet is not a new session, just return
## Or more simply: Continue to mark the packet if it isn't marked OR if its new session 
## We will continue to mark new sessions because splitd may have already marked the packet for a specific WAN
## However, if the packet is not destined for a WAN but a local network, we need to remark it here
#{IPTablesCommand} #{args} -m mark ! --mark 0/#{DstIntfMask} -m conntrack ! --ctstate NEW -j RETURN -m comment --comment \"Return if destination interface mark is already set (unless session is new)\"
EOF

    MarkLocal = Chain.new( "mark-local", "mangle", "PREROUTING", "", <<'EOF' )
## This chain marks the local and first alias marks on the packet and connmark
##
EOF

    MarkLocalOutput = Chain.new( "mark-local-output", "mangle", "OUTPUT", "", <<'EOF' )
## This chain marks the local and first alias marks on the packet and connmark
##
EOF

    ## Chain Used for natting in the prerouting table.
    PostNat = Chain.new( "alpaca-post-nat", "nat", "POSTROUTING", "", <<'EOF' )
## Save the state for new sessions
#{IPTablesCommand} -t mangle -A POSTROUTING -m conntrack --ctstate NEW -m connmark --mark 0/#{DstIntfMask} -j CONNMARK --save-mark --mask #{DstIntfMask} -m comment --comment \"Save destination interface mark if not already saved\"


## Do not NAT packets destined to local host.
#{IPTablesCommand} #{args} -o lo -j RETURN -m comment --comment \"Do not NAT loopback packets\"
## Do not NAT packets that are destined to the VPN.
#{IPTablesCommand} #{args} -o tun0 -j RETURN -m comment --comment \"Do not NAT packets to the OpenVPN interface\"
EOF

    ## Chain used to redirect traffic
    Redirect = Chain.new( "alpaca-redirect", "nat", "PREROUTING", "", <<'EOF' )
EOF

    ## Chain used for actually blocking and dropping data
    FirewallBlock = Chain.new( "alpaca-firewall", "filter", [ "INPUT" ], "", <<'EOF' )
## Do not block traffic that has the INPUT mark set.
#{IPTablesCommand} -t #{table} -A FORWARD -m mark --mark 0/#{MarkFwInput} -j #{name} -m comment --comment \"Allow packets with INPUT mark set\"

## Ignore any traffic that isn't marked
#{IPTablesCommand} #{args} -m mark --mark 0/#{MarkFwReject | MarkFwDrop} -j RETURN -m comment --comment \"Ignore unmarked traffic\"

## Drop any traffic that is marked to drop
#{IPTablesCommand} #{args} -m mark --mark #{MarkFwDrop}/#{MarkFwDrop} -j DROP -m comment --comment \"Drop traffic with drop mark set\"

## Reset any tcp traffic that is marked to reject.
#{IPTablesCommand} #{args} -p tcp -m mark --mark #{MarkFwReject}/#{MarkFwReject} -j REJECT --reject-with tcp-reset -m comment --comment \"Reject traffic with reject mark set\"

## Reject all other traffic with ICMP port unreachable
#{IPTablesCommand} #{args} -m mark --mark #{MarkFwReject}/#{MarkFwReject} -j REJECT -m comment --comment \"Reject all remaining packets\"
EOF

    FirewallNat = Chain.new( "alpaca-nat-firewall", "filter", nil, "", <<'EOF' )
EOF
    
    ## Chain where all of the firewalls rules should go
    FirewallRules = Chain.new( "firewall-rules", "mangle", "PREROUTING", "", <<'EOF' )
## mark all sessions with the firewall pass tag
#{IPTablesCommand} #{args} -j MARK --or-mark #{MarkFwPass} -m comment --comment \"Set firewall pass mark\"
## Ignore any traffic that is related to an existing session
#{IPTablesCommand} #{args} -i lo -j RETURN -m comment --comment \"Allow loopback packets\"
#{IPTablesCommand} #{args} -m state --state ESTABLISHED -j RETURN -m comment --comment \"Allow all packets in an allowed session\"
#{IPTablesCommand} #{args} -m state --state RELATED -j RETURN -m comment --comment \"Allow all packets in an related allowed session\"
EOF
    
    ## Goto chains used to indicate that a packet should be rejected or dropped.
    FirewallMarkReject = Chain.new( "alpaca-pf-reject", "mangle", nil, "", <<'EOF' )
## Clear the INPUT mark
#{IPTablesCommand} #{args} -j MARK --and-mark #{MarkClearFwInput} 
#{IPTablesCommand} #{args} -j MARK --and-mark #{MarkClearFwPass}
## Mark the packets
#{IPTablesCommand} #{args} -j MARK --or-mark #{MarkFwReject}
EOF

    FirewallMarkDrop = Chain.new( "alpaca-pf-drop", "mangle", nil, "", <<'EOF' )
## Clear the INPUT mark
#{IPTablesCommand} #{args} -j MARK --and-mark #{MarkClearFwInput} -m comment --comment \"Clear input mark bit\"
#{IPTablesCommand} #{args} -j MARK --and-mark #{MarkClearFwPass} -m comment --comment \"Clear pass mark bit\"
## Mark the packets
#{IPTablesCommand} #{args} -j MARK --or-mark #{MarkFwDrop} -m comment --comment \"Set drop mark bit\"
EOF

    ## Jumps chains used to indicate that a packet should be rejected or dropped on the INPUT chain
    FirewallMarkInputReject = Chain.new( "alpaca-pfi-reject", "mangle", nil, "", <<'EOF' )
## Mark the packets
#{IPTablesCommand} #{args} -j MARK --or-mark #{MarkFwReject | MarkFwInput} -m comment --comment \"Set input and reject mark bits\"
EOF

    FirewallMarkInputDrop = Chain.new( "alpaca-pfi-drop", "mangle", nil, "", <<'EOF' )
## Mark the packets
#{IPTablesCommand} #{args} -j MARK --or-mark #{MarkFwDrop | MarkFwInput} -m comment --comment \"Set input and drop mark bits\"
EOF
    
    ## Chain where traffic should go to be marked for bypass.
    BypassMark = Chain.new( "bypass-mark", "mangle", nil, "", <<'EOF' )
## Mark the packets
#{IPTablesCommand} #{args} -j MARK --or-mark #{MarkBypass} -m comment --comment \"Set bypass mark on packet\"
## Connmark the packets
#{IPTablesCommand} #{args} -j CONNMARK --set-mark #{MarkBypass}/#{MarkBypass} -m comment --comment \"Set bypass mark on session\"
EOF

    ## Chain where all of the Bypass Rules go (This shouldn't be  defined unless
    ## There is a UVM, but it should only be a minor performance hit
    BypassRules = Chain.new( "bypass-rules", "mangle", "PREROUTING", "", <<'EOF' )
## Accept any packets that are connmarked with the bypass mark
#{IPTablesCommand} #{args} -m connmark --mark #{MarkBypass}/#{MarkBypass} -g #{Chain::BypassMark} -m comment --comment \"Transfer bypass mark from session to packet\"
EOF

    ## These are only used in classy NAT mode.
    SNatRules = Chain.new( "snat-rules", "nat", nil, "", <<'EOF' )
EOF

    Order = [ MarkInterface, MarkSrcInterface, MarkDstInterface, MarkLocal, MarkLocalOutput, PostNat, SNatRules,
              FirewallBlock, FirewallMarkReject, FirewallMarkDrop, 
              FirewallMarkInputReject, FirewallMarkInputDrop, FirewallNat,
              FirewallRules, 
              BypassRules, BypassMark, Redirect ]
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
    raise "Unable to iptables rules." unless run_command( "#{Service} restart packet-filter-manager" ) == 0
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

 #{EBTablesCommand} -t broute -F

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
   local t_intf_name=$1
   local t_intf_index=$2
   local t_first_alias="true"

   ## Verify the interface was specified. 
   test -z "${t_intf_name}" && return 0
   test -z "${t_intf_index}" && return 0

   for t_ip in `get_ip_addresses ${t_intf_name}` ; do

     # Set this mark if the traffic is going to any one of Untangles IPs
     #{IPTablesCommand} #{Chain::MarkLocal.args} -d ${t_ip} -j MARK --or-mark $(( #{MarkLocal} )) -m comment --comment \"Set local mark on packets destined to local IP ${t_ip}\"

     if [ "${t_first_alias}x" = "truex" ]; then
       # Set this mark if the traffic is going to the first alias of the interface in question

       # This rule matches on the source interface mark
       #{IPTablesCommand} #{Chain::MarkLocal.args} -m mark --mark ${t_intf_index}/#{SrcIntfMask} -d ${t_ip} -j MARK --or-mark $(( #{MarkFirstAlias} )) -m comment --comment \"Set first alias mark on packets destined to first alias ${t_ip} coming from that interface\"

       # This rule matches the interface name (this is so bridged interfaces match their master)
       #{IPTablesCommand} #{Chain::MarkLocal.args} -i ${t_intf_name} -d ${t_ip} -j MARK --or-mark $(( #{MarkFirstAlias} )) -m comment --comment \"Set first alias mark on packets destined to first alias ${t_ip} coming from that interface\"
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
    
    ##
    ## If this rule is enabled then add the following ebtables rule which forces all traffic going over a bridge
    ## to actually traverse the routing code instead
    ##
    if Firewall.find( :first, :conditions => [ "system_id = ? and enabled='t'", "route-bridge-traffic-bc218f02" ] )
      # dont broute DHCP (it gets dropped then because it routes based on IP which we dont have yet)
      text << "## Don't BROUTE DHCP"
      text << "#{EBTablesCommand} -t broute -I BROUTING -p ipv4 --ip-protocol udp --ip-dport 67:68 -j ACCEPT"
      text << "#{EBTablesCommand} -t broute -I BROUTING -p ipv4 --ip-protocol udp --ip-sport 67:68 -j ACCEPT"
      # broute everything else
      text << "## ACCEPT here means to BROUTE the packet - BROUTE all IPv4 (http://ebtables.sourceforge.net/examples/basic.html#ex_redirect) "
      text << "#{EBTablesCommand} -t broute -A BROUTING -p ipv4 -j redirect --redirect-target ACCEPT"
      text << ""
    end

    if ( alpaca_settings.classy_nat_mode )
      ## This is all of the traffic that will hit the NAT rules.  The NAT rules
      ## Determine if the sessions originated from an IP that needs to be NATd
      ## So sessions may hit the NAT rules, and not be NATed.
      
      ## NAT Sessions that are DNATd.
      text << "#{IPTablesCommand} #{Chain::PostNat.args} -m conntrack --ctstate DNAT -j #{Chain::SNatRules} -m comment --comment \"Source NAT all sessions that are DNATed (hairpin support)\"" 
      
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

        text << "#{IPTablesCommand} #{Chain::PostNat.args} -o #{i_name} -j #{Chain::SNatRules} -m comment --comment \"Source NAT all session going out WAN #{i_name}\""

        ## Firewall NAT rules apply to all of the traffic from WAN interfaces
        fw_text << "#{IPTablesCommand} -t filter -A FORWARD -i #{i_name} -g #{Chain::FirewallNat} -m comment --comment \"Filter traffic coming from WAN #{i_name}\""
      end

      ## Ignore DNATd traffic
      fw_text << "#{IPTablesCommand} #{Chain::FirewallNat.args} -m conntrack --ctstate DNAT -j RETURN -m comment --comment \"Allow DNATd traffic\""
      ## Ignore traffic with the passed mark
      fw_text << "#{IPTablesCommand} #{Chain::FirewallNat.args} -m mark --mark #{MarkFwPass}/#{MarkFwPass} -j RETURN -m comment --comment \"Allow traffic with pass mark set\""

      ## Added an exception for unNATed interfaces (these should allow traffic just like normal routed interfaces
      non_wan_interfaces.each do |interface|
        begin
          ## Drop all WAN traffic that is going to a non-wan NATed interface
          ## non-wan non-NATd interfaces should have traffic allowed like normal routed traffic
          if (!interface.current_config.nil? and 
              !interface.current_config.nat_policies.nil? and 
              !interface.current_config.nat_policies.empty?)
            fw_text << "#{IPTablesCommand} #{Chain::FirewallNat.args} -o #{interface.os_name} -j DROP -m comment --comment \"Block incoming traffic to non-wan #{interface}\""
          else
            # Do not filter, if no NAT policy, just be a normal router and allow traffic
            fw_text << "# #{IPTablesCommand} #{Chain::FirewallNat.args} -o #{interface.os_name} -j DROP # commented out to allow incoming traffic to non-wan #{interface} (no nat policies)"
          end
        rescue
          logger.warn( "The interface '#{interface.os_name}' has bad nat_policies: #{$!}" )
          logger.warn( $!.backtrace.join( "\n" ) )
        end
      end
      
      ## Drop traffic going to the VPN interface that is not allowed.
      fw_text << "#{IPTablesCommand} #{Chain::FirewallNat.args} -o tun0 -j DROP -m comment --comment \"Drop traffic going out OpenVPN interface\""

      text.push <<EOF

add_destination_nat_rule()
{
  local t_network=$1
  local t_new_source=$2

  local t_intf=`ip -f inet addr show to ${t_new_source} | awk '/^[0-9]/ { sub( ":","",$2 ); print $2 ; exit}'`
  local t_pppoe
  
  if [ -z "${t_intf}" ]; then
    #{IPTablesCommand} #{Chain::SNatRules.args} -s ${t_network} -j SNAT --to-source ${t_new_source} -m comment --comment \"NAT traffic from ${t_network} going anyway\"
    return
  fi

  #{IPTablesCommand} #{Chain::SNatRules.args} -o ${t_intf} -s ${t_network} -j SNAT --to-source ${t_new_source} -m comment --comment \"NAT traffic from ${t_network} going to ${t_intf}\"

  [ "${t_intf#ppp}" != "${t_intf}" ] && return

  t_pppoe=`/usr/share/untangle-net-alpaca/scripts/get_pppoe_name ${t_intf}`
  [ -z "${t_pppoe}" ] && return
  [ "${t_pppoe}" = "ppp.${t_intf}" ] && return
  
  #{IPTablesCommand} #{Chain::SNatRules.args} -o ${t_pppoe} -s ${t_network} -j SNAT --to-source ${t_new_source} -m comment --comment \"NAT traffic from ${t_network} going out PPPoE\"
}

EOF

    end
    
    # XXX what is this?
    text << "#{IPTablesCommand} -t mangle -I OUTPUT 1 -j CONNMARK --restore-mark --mask #{DstIntfMask} -m comment --comment \"Restore destination interface mark (XXX WHY)\""

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

    # Mark the packet using the connmark (both local and first alias).
    text << "#{IPTablesCommand} #{Chain::MarkLocal.args} -j CONNMARK --restore-mark --mask $(( #{MaskLocalAndFirstAlias} )) -m comment --comment \"Restore local and first alias mark from session\""
    # If the packet is not the first packet in a sesison, return (its already been marked above using the connmark if its local)
    text << "#{IPTablesCommand} #{Chain::MarkLocal.args} -m conntrack ! --ctstate NEW -j RETURN -m comment --comment \"Return for packets already marked above, NEW packets will continue to be marked\""
    # Add the local/first alias marks for each interface
    interface_list.each do |interface|
      text << local_rules( interface )
    end
    # save the connmark
    text << "#{IPTablesCommand} #{Chain::MarkLocal.args} -j CONNMARK --save-mark --mask #{MaskLocalAndFirstAlias} -m comment --comment \"Save the local and first alias mark\""
    # erase the mark in the forward chain - this is we don't want to connmark port forwarded traffic as local
    text << "#{IPTablesCommand} -t mangle -I FORWARD -j     MARK --set-mark 0/#{MaskLocalAndFirstAlias} -m comment --comment \"Zero the local and first alias mark\""
    text << "#{IPTablesCommand} -t mangle -I FORWARD -j CONNMARK --set-mark 0/#{MaskLocalAndFirstAlias} -m comment --comment \"Zero the local and first alias mark\""

    # Mark the outbound packet using the connmark (both local and first alias).
    text << "#{IPTablesCommand} #{Chain::MarkLocalOutput.args} -j CONNMARK --restore-mark --mask $(( #{MaskLocalAndFirstAlias} )) -m comment --comment \"Restore the local and first alias mark\""
    # If the packet is not the first packet in a sesison, return (its already been marked above using the connmark if its local)
    text << "#{IPTablesCommand} #{Chain::MarkLocalOutput.args} -m conntrack ! --ctstate NEW -j RETURN -m comment --comment \"Return for packets already marked above, NEW packets will continue to be marked\""
    # IF the packet reaches this point, it is a new session and since its in the OUTPUT chain we know its a local-initiated session
    text << "#{IPTablesCommand} #{Chain::MarkLocalOutput.args} -j     MARK --set-mark #{MaskLocalAndFirstAlias}/#{MaskLocalAndFirstAlias} -m comment --comment \"Set local and first alias marks on all locally initiated packets\"" 
    text << "#{IPTablesCommand} #{Chain::MarkLocalOutput.args} -j CONNMARK --set-mark #{MaskLocalAndFirstAlias}/#{MaskLocalAndFirstAlias} -m comment --comment \"Set local and first alias marks on all locally initiated packets\"" 

    block_all = Firewall.find( :first, :conditions => [ "system_id = ?", "block-all-local-04a98864"] )

    if !block_all.nil? && block_all.enabled
      ##A little rule to block all local traffic, done here so that custom items can
      ## insert rules in between.
      fw_text << "#{IPTablesCommand} #{Chain::FirewallRules.args} -j #{Chain::FirewallMarkInputDrop.name} -m comment --comment \"Set input drop mark\""
    end

    ## Allow traffic to the test IP, this is useful for people who don't know their IP.
    fw_text << "#{IPTablesCommand} #{Chain::FirewallRules.args} -p tcp --destination-port 443 -d 192.0.2.42 -j RETURN -m comment --comment \"Allow traffic to 192.0.2.42 (XXX WHY)\""

    ## This is a special rule to block access to the dummy bind address.  Traffic
    ## should always be redirected to the dummy interface (unless it came in over lo.)
    ## which is ignored above.
    fw_text << "#{IPTablesCommand} #{Chain::FirewallRules.args} -d 192.0.2.42 -j DROP -m comment --comment \"Drop traffic to 192.0.2.42 (XXX WHY)\""
    ## Clear the FwPass mark at the end
    fw_text << "#{IPTablesCommand} #{Chain::FirewallRules.args} -j MARK --and-mark #{MarkClearFwPass} -m comment --comment \"Clear pass mark\""

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
          text << "#{IPTablesCommand} #{Chain::FirewallRules.args} #{filter} #{target} -m comment --comment \"Packet Filter Rule #{rule.id}\"\n"
        end
      rescue
        logger.warn( "The packet filter rule '#{rule.id}' '#{rule.filter}' could not be parsed: #{$!}" )
        logger.warn( $!.backtrace.join( "\n" ) )
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
          text << "#{IPTablesCommand} #{Chain::Redirect.args} #{filter} -j DNAT --to-destination #{destination} -m comment --comment \"Port Forward Rule #{rule.id}\"\n"
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
    match_in  = "-i #{interface.os_name}"
    match_out = "-o #{interface.os_name}"
    match_in_alt  = nil
    match_out_alt = nil
    index = interface.index
    
    rules = []

    ## use the pppoe name if this is a PPPoE interface.
    if ( interface.config_type == InterfaceHelper::ConfigType::PPPOE )
      pppoe_name = pppoe_variable_name( interface )
      match_in_alt  = "-i ${#{pppoe_name}}"
      match_out_alt = "-o ${#{pppoe_name}}"
    elsif interface.is_bridge?
      match_in_alt  = "-m physdev --physdev-in  #{interface.os_name}"
      match_out_alt = "-m physdev --physdev-is-bridged --physdev-out #{interface.os_name}"
    end

    # Set the src mark 
    rules << "#{IPTablesCommand} #{Chain::MarkSrcInterface.args} #{match_in}  -j MARK --set-mark #{index}/#{SrcIntfMask} -m comment --comment \"Set source interface mark #{index} on #{interface.os_name}\""
    # If this is a new connection save the src interface index as the client interface connmark
    rules << "#{IPTablesCommand} #{Chain::MarkSrcInterface.args} #{match_in}  -m conntrack --ctstate NEW -j CONNMARK --set-mark #{index}/#{SrcIntfMask} -m comment --comment \"Set source interface mark #{index} on #{interface.os_name}\""
    # Alternative marking technique (used in some cases like bridge of PPPoE)
    if !match_in_alt.nil?
      # Set the src mark 
      rules << "#{IPTablesCommand} #{Chain::MarkSrcInterface.args} #{match_in_alt}  -j MARK --set-mark #{index}/#{SrcIntfMask} -m comment --comment \"Set source interface mark #{index} on #{interface.os_name} - alternate rule\""
      # If this is a new connection save the src interface index as the client interface connmark
      rules << "#{IPTablesCommand} #{Chain::MarkSrcInterface.args} #{match_in_alt}  -m conntrack --ctstate NEW -j CONNMARK --set-mark #{index}/#{SrcIntfMask} -m comment --comment \"Set source interface mark #{index} on #{interface.os_name} - alternate rule\""
    end

    # Set the dst mark 
    rules << "#{IPTablesCommand} #{Chain::MarkDstInterface.args} #{match_out} -j MARK --set-mark #{index << DstIntfShift}/#{DstIntfMask} -m comment --comment \"Set destination interface mark #{index} on #{interface.os_name}\""
    # If this is a new connection save the dst interface index as the server interface connmark
    rules << "#{IPTablesCommand} #{Chain::MarkDstInterface.args} #{match_out} -m conntrack --ctstate NEW -j CONNMARK --set-mark #{index << DstIntfShift}/#{DstIntfMask} -m comment --comment \"Set destination interface mark #{index} on #{interface.os_name}\""
    # Alternative marking technique (used in some cases like bridge of PPPoE)
    if !match_out_alt.nil?
      # Set the dst mark 
      rules << "#{IPTablesCommand} #{Chain::MarkDstInterface.args} #{match_out_alt} -j MARK --set-mark #{index << DstIntfShift}/#{DstIntfMask} -m comment --comment \"Set destination interface mark #{index} on #{interface.os_name} - alternate rule\""
      # If this is a new connection save the dst interface index as the server interface connmark
      rules << "#{IPTablesCommand} #{Chain::MarkDstInterface.args} #{match_out_alt} -m conntrack --ctstate NEW -j CONNMARK --set-mark #{index << DstIntfShift}/#{DstIntfMask} -m comment --comment \"Set destination interface mark #{index} on #{interface.os_name} - alternate rule\""
    end


    # If this is a "reply" packet, set the client interface index as the dst intf on the packet mark
    # The rule actually says "ORIGINAL" and not "REPLY" and thats because ctdir seems to match backwards
    # XXX because ctdir matches backwards
    rules << "#{IPTablesCommand} #{Chain::MarkInterface.args} -m conntrack --ctdir ORIGINAL -m connmark --mark #{index}/#{SrcIntfMask} -j MARK --set-mark #{index << DstIntfShift}/#{DstIntfMask} -m comment --comment \"Set destination interface mark from connmark\""
    # If this is a "reply" packet, set the server interface index as the src intf on the packet mark
    # The rule actually says "ORIGINAL" and not "REPLY" and thats because ctdir seems to match backwards
    rules << "#{IPTablesCommand} #{Chain::MarkInterface.args} -m conntrack --ctdir ORIGINAL -m connmark --mark #{index << DstIntfShift}/#{DstIntfMask} -j MARK --set-mark #{index}/#{SrcIntfMask} -m comment --comment \"Set source interface mark from connmark\""

    rules.join( "\n" )
  end

  def local_rules( interface )
    name = interface.os_name
    pppoe_name = pppoe_variable_name( interface )
    index = interface.index

    rules = []


    rules << "mark_local_ip #{name} #{index}"

    # If its not a bridge - something might be bridged to it so insert rules for the bridged name
    if ( interface.config_type != InterfaceHelper::ConfigType::BRIDGE )
      bridge_name = OSLibrary::Debian::NetworkManager.bridge_name( interface )
      rules << "mark_local_ip #{bridge_name} #{index}"
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
          rules << "#{IPTablesCommand} #{Chain::PostNat.args} -m conntrack ! --ctorigdst #{network} -s #{network} -j #{target} -m comment --comment \"Auto NAT fixed target #{target} Rule (legacy)\"" 
        end
      end
      
      rules << "#{IPTablesCommand} #{Chain::PostNat.args} -m conntrack ! --ctorigdst #{network} -s #{network} -j MASQUERADE -m comment --comment \"Auto NAT Rule (legacy)\""
    else
      rules << "#{IPTablesCommand} #{Chain::PostNat.args} -m conntrack ! --ctorigdst #{network} -s #{network} -j SNAT --to-source #{policy.new_source} -m comment --comment \"NAT Rule (legacy)\""
    end

    fw_rules << "#{IPTablesCommand} #{Chain::FirewallRules.args} -i ! #{os_name} -d #{network} -j DROP -m comment --comment \"Drop all traffic to private subnet (not from that interface)\""
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
      ## Global netmask, use the addresses for the interface
      # XXX perhaps we should use -i intf instead of the address for the interface
      if ( policy.netmask == "0" || policy.netmask == "0.0.0.0" )
        config.ip_networks.each do |ip_network|
          add_classy_nat_rule( rules, fw_rules, interface, policy, nat_automatic_target, ip_network.ip, ip_network.netmask )
        end
      else
        add_classy_nat_rule( rules, fw_rules, interface, policy, nat_automatic_target, policy.ip, policy.netmask )
      end
    end

    # add openVPN nat rules
    wan_interfaces.each do |interface|
      # the -i test does not work here, 0xfa (250) is the openvpn interface - use the mark instead
      # rules << "#{IPTablesCommand} #{Chain::SNatRules.args} -i tun0 -o #{interface.os_name} -j MASQUERADE"

      # add a rule using the -o matcher
      rules << "#{IPTablesCommand} #{Chain::SNatRules.args} -m mark --mark 0xfa/#{SrcIntfMask} -o #{interface.os_name} -j MASQUERADE -m comment --comment \"NAT traffic from OpenVPN to WAN intf #{interface.index}\""

      # add a rule using the dst mark (sometimes previous won't work for bridged interfaces)
      rules << "#{IPTablesCommand} #{Chain::SNatRules.args} -m mark --mark #{((interface.index << DstIntfShift) | 0xfa)}/#{(DstIntfMask | SrcIntfMask)} -j MASQUERADE -m comment --comment \"NAT traffic from OpenVPN to WAN intf #{interface.index}\""
    end

      # add a rule that NAT traffic coming from the VPN and going to an unknown (0) interface
      # unfortunately this happens on some machines as the mark-dst-intf fails to match physdev and mark the interface
      # I'm unsure of why this only fails on some machine, but it does.
      # This rule will just NAT the traffic just in case
      rules << "#{IPTablesCommand} #{Chain::SNatRules.args} -m mark --mark 0x00fa/#{(DstIntfMask | SrcIntfMask)} -j MASQUERADE -m comment --comment \"NAT traffic coming from OpenVPN to unknown (0 mark) interface\""

    [ rules.join( "\n" ), fw_rules.join( "\n" ) ]    
  end

  def add_classy_nat_rule( rules, fw_rules, interface, policy, nat_automatic_target, network, netmask )
    os_name = interface.os_name
    os_name = OSLibrary::Debian::NetworkManager.bridge_name( interface ) if interface.is_bridge?    

    network = "#{network}/#{OSLibrary::NetworkManager.parseNetmask( netmask )}"

    if ( policy.new_source == NatPolicy::Automatic )
      if nat_automatic_target != "MASQUERADE"
        nat_automatic_target.each do |target|
          rules << "#{IPTablesCommand} #{Chain::SNatRules.args} -s #{network} -j #{target} -m comment --comment \"Auto NAT fixed target #{target} Rule (classy)\""
        end
      end
      
      rules << "#{IPTablesCommand} #{Chain::SNatRules.args} -s #{network} -j MASQUERADE -m comment --comment \"Auto NAT Rule (classy)\""
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
      mark = InterfaceHelper::InternalIndex
      return "#{IPTablesCommand} -t filter -I INPUT 1 -p udp -m mark --mark #{mark}/#{SrcIntfMask} -m multiport --destination-ports 67 -j RETURN -m comment --comment \"Accept DHCP on internal (system rule)\"\n"

    when "accept-dhcp-dmz-7a5a003c"
      ## Accept traffic to the DHCP server on the DMZ interface
      mark = InterfaceHelper::DmzIndex
      return "#{IPTablesCommand} -t filter -I INPUT 1 -p udp -m mark --mark #{mark}/#{SrcIntfMask} -m multiport --destination-ports 67 -j RETURN -m comment --comment \"Accept DHCP on DMZ (system rule)\"\n"

    when "block-dhcp-remaining-58b3326c"
      ## Block remaining DHCP traffic to the server.
      return "#{IPTablesCommand} -t filter -A INPUT -p udp -m multiport --destination-port 67 -j DROP -m comment --comment \"Drop dhcp to server (system rule)\"\n"

    when "control-dhcp-cb848bea"
      ## Limit DHCP traffic to the Internal interface
      dhcp_server_settings = DhcpServerSettings.find( :first )

      ## No need to control DHCP if we are not running a server
      return "" if ( dhcp_server_settings.nil? || !dhcp_server_settings.enabled )

      i = Interface.find( :first, :conditions => [ "\"index\" = ?", InterfaceHelper::InternalIndex ] )
      return "" if i.nil? || i.os_name.nil?

      ## Drop dhcp responses from being forwarded to the internal interface.
      return "#{IPTablesCommand} -t mangle -A FORWARD -p udp -m multiport --destination-ports 67,68 -m physdev --physdev-is-bridged --physdev-out #{i.os_name} -j DROP -m comment --comment \"Drop DHCP forwarded to #{i.os_name}\"\n" +
             "#{IPTablesCommand} -t mangle -A FORWARD -p udp -m multiport --destination-ports 67,68 -m physdev --physdev-in #{i.os_name} -j DROP -m comment --comment \"Drop DHCP coming from #{i.os_name}\"\n"

    when "accept-dhcp-client-43587bff"
      ## Accept all traffic to the local DHCP client
      return "#{IPTablesCommand} -t filter -I INPUT 1 -p udp -m multiport --destination-ports 68 -j RETURN -m comment --comment \"Accept DHCP traffic to DHCP server\"\n"
    else return ""
    end
  end
end
