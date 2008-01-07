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
  NatFirewallConfigFile = "#{ConfigDirectory}/500-nat-firewall"
  RedirectConfigFile   = "#{ConfigDirectory}/600-redirect"

  ## Mark to indicate that the packet shouldn't be caught by the UVM.
  MarkBypass   = 0x01000000
  
  ## Mark indicating that the packet shouldn't hit the conntrack table.
  MarkNoTrack  = 0x02000000

  ## Mark that causes the firewall to reject a packet.
  MarkFwReject = 0x04000000

  ## Mark that causes the firewall to drop a packet.
  MarkFwDrop   = 0x08000000

  ## Mark that indicates a  packet is destined to one of the machines IP addresses
  MarkInput    = 0x00000800

  def register_hooks
    os["network_manager"].register_hook( 100, "packet_filter_manager", "write_files", :hook_write_files )

    ## This is run automatically by etc/network/interfaces
    ## os["network_manager"].register_hook( 100, "packet_filter_manager", "run_services", :hook_run_services )
    
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
EOF
    ## Chain Used for natting in the prerouting table.
    PostNat = Chain.new( "alpaca-post-nat", "nat", "POSTROUTING", <<'EOF' )
## Do not NAT packets destined to local host.
#{IPTablesCommand} #{args} -o lo -j RETURN
EOF

    ## Chain used to redirect traffic
    Redirect = Chain.new( "alpaca-redirect", "nat", "PREROUTING", <<'EOF' )

EOF

    ## Chain used for actually blocking and dropping data
    FirewallBlock = Chain.new( "alpaca-firewall", "filter", [ "INPUT", "FORWARD" ], <<'EOF' )
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
    
    ## Chain where all of the firewalls rules should go
    FirewallRules = Chain.new( "firewall-rules", "mangle", "PREROUTING", "" )

    ## Goto chains used to indicate that a packet should be rejected or dropped.
    FirewallMarkReject = Chain.new( "alpaca-firewall-reject", "mangle", nil, <<'EOF' )
## Mark the packets
#{IPTablesCommand} #{args} -j MARK --or-mark #{MarkFwReject}
EOF

    FirewallMarkDrop = Chain.new( "alpaca-firewall-drop", "mangle", nil, <<'EOF' )
## Mark the packets
#{IPTablesCommand} #{args} -j MARK --or-mark #{MarkFwDrop}
EOF

    ## Chain where all of the Bypass Rules go (This shouldn't be  defined unless
    ## There is a UVM, but it should only be a minor performance hit
    BypassRules = Chain.new( "bypass-rules", "mangle", "PREROUTING", "" )

    ## Chain where traffic should go to be marked for bypass.
    BypassMark = Chain.new( "bypass-mark", "mangle", nil, <<'EOF' )
## Mark the packets
#{IPTablesCommand} #{args} -j MARK --or-mark #{MarkBypass}
EOF

    ## Review : Should the Firewall Rules go before the redirects?
    Order = [ MarkInterface, PostNat, 
      FirewallBlock, FirewallMarkReject, FirewallMarkDrop, FirewallRules,
      BypassRules, BypassMark, Redirect ]
  end
  
  def hook_commit
    write_files
    run_services
  end

  def hook_write_files
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
    
  def write_flush
    text = header
    
    ## The space before the for is so that emacs parses this line properly.
    text += <<EOF
## Flush all of the rules.
 for t_table in `cat /proc/net/ip_tables_names` ; do #{IPTablesCommand} -t ${t_table} -F ; done
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
    
    Interface.find( :all ).each do |interface|
      ## labelling
      text << marking( interface )
      
      ## Insert the commands to filter traffic
      text << filtering( interface )
      
      ## Insert the commands to handle NAT
      a, b = nat( interface )
      text << a
      fw_text << b
    end

    ## Delete all empty or nil parts
    text = text.delete_if { |p| p.nil? || p.empty? }
    fw_text = fw_text.delete_if { |p| p.nil? || p.empty? }
    
    os["override_manager"].write_file( NetworkingConfigFile, text.join( "\n" ), "\n" )
    os["override_manager"].write_file( NatFirewallConfigFile, fw_text.join( "\n" ), "\n" )
  end

  def write_firewall
    rules = Firewall.find( :all, :conditions => [ "system_id IS NULL AND enabled='t'" ] )
    rules += Firewall.find( :all, :conditions => [ "system_id IS NOT NULL AND enabled='t'" ] )
    
    text = header

    rules.each do |rule|
      begin
        filters, chain = OSLibrary::Debian::Filter::Factory.instance.filter( rule.filter )
        
        target = nil
        case rule.target
        when "pass" then target = "-j RETURN"
        when "drop" then target = "-g #{FirewallMarkDrop.name}"
        when "reject" then target = "-g #{FirewallMarkReject.name}"
        end
        
        next if target.nil?
            
        filters.each do |filter|
          ## Nothing to do if the filtering string is empty.
          break if filter.strip.empty?
          text << "#{IPTablesCommand} #{Chain::FirewallRules.args} #{filter} #{target}\n"
        end
      rescue
        logger.warn( "The filter '#{rule.filter}' could not be parsed: #{$!}" )
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

        next if ApplicationHelper.null?( destination )
        
        ## Try to parse the new ip
        IPAddr.new( "#{destination}/32" )
        
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
        logger.warn( "The filter '#{rule.filter}' could not be parsed: #{$!}" )
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

    if interface.is_bridge?
      name = OSLibrary::Debian::NetworkManager.bridge_name( interface ) if interface.is_bridge?
      match = "-m physdev --physdev-in #{interface.os_name}" if interface.is_bridge?
    end
    
    index = interface.index
    mask = 1 << ( index - 1 )
    rules = <<EOF
#{IPTablesCommand} #{Chain::MarkInterface.args} #{match} -j MARK --or-mark #{mask}

## Mark packets destined for each IP address as local.
 for t_intf in `get_ip_addresses #{name}` ; do
#{IPTablesCommand} #{Chain::MarkInterface.args} -d ${t_intf} -j MARK --or-mark #{MarkInput | ( index << 8 )}
done

EOF

    rules
  end
  
  def filtering( interface )
    
  end
  
  ## REVIEW This doesn't support discontiguous netmasks (like 255.0.255.0) (but neither does ifconfig, so who cares)
  ## REVIEW Order is important, so this may need a way to reorder them in the UI.
  ## REVIEW should put 0.0.0.0/0 at the bottom.
  ## REVIEW how should auto work, right now it just uses MASQUERADE.
  def nat( interface )
    ## static is the only config type that supports NATing
    config = interface.current_config

    return nil if ( config.nil? || !config.is_a?( IntfStatic ))
    
    ## Nothing to nat if there are no NAT policies
    nat_policies = config.nat_policies
    return nil if ( nat_policies.nil? || nat_policies.empty? )

    ## Determine the name of the interface
    name = interface.os_name
    name = OSLibrary::Debian::NetworkManager.bridge_name( interface ) if interface.is_bridge?
    
    rules = []
    fw_rules = []

    nat_policies.each do |policy|
      ## REVIEW : Need to handle the proper ports.
      ## REVIEW : Need to use the correct interface marks, but that needs a bridge mark
      if ( policy.new_source == NatPolicy::Automatic )
        target = "MASQUERADE"
      else
        target = "SNAT --to-source #{policy.new_source}"
      end
      
      ## Global netmask, use the addresses for the interface
      if ( policy.netmask == "0" || policy.netmask == "0.0.0.0" )
        config.ip_networks.each do |ip_network|
          network = "#{ip_network.ip}/#{OSLibrary::NetworkManager.parseNetmask( ip_network.netmask )}"
          rules << "#{IPTablesCommand} #{Chain::PostNat.args} -m conntrack ! --ctorigdst #{network} -s #{network} -j #{target}"
          fw_rules << "#{IPTablesCommand} #{Chain::FirewallRules.args} -i ! #{name} -d #{network} -j DROP"
        end
      else
        network = "#{policy.ip}/#{OSLibrary::NetworkManager.parseNetmask( policy.netmask )}"
        rules << "#{IPTablesCommand} #{Chain::PostNat.args}  -m conntrack ! --ctorigdst #{network} -s #{network} -j #{target}"
        fw_rules << "#{IPTablesCommand} #{Chain::FirewallRules.args} -i ! #{name} -d #{network} -j DROP"
      end
    end

    [ rules.join( "\n" ), fw_rules.join( "\n" ) ]
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
    
    raise "Invalid destination '#{new_ip}'" if IPAddr.parse( "#{new_ip}/32" ).nil?

    ## Convert new_port to a number
    new_port_string = new_port.to_s
    
    new_port = new_port.to_i.to_s
    raise "Invalid redirect port '#{new_port_string}'" unless ( new_port == new_port_string )
  end
end
