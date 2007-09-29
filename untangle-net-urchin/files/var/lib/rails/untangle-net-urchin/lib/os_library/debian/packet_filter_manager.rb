require_dependency "os_library/debian/network_manager"

class OSLibrary::Debian::PacketFilterManager < OSLibrary::PacketFilterManager
  include Singleton

  IPTablesCommand = "${IPTABLES}"

  Service = "/etc/init.d/urchin-iptables"

  ConfigFile = "/etc/untangle-net-urchin/iptables-rules"
  
  class Chain
    def initialize( name, table, start_chain, init = "" )
      @name, @table, @start_chain = name, table, start_chain
      @init = eval( "String.new( \"#{init}\" )" )
    end
    
    def to_s
      name
    end

    def args
      "-t #{table} -A #{name}"
    end

    attr_reader :name, :table, :start_chain, :init

    MarkInterface = Chain.new( "markintf", "mangle", "PREROUTING", <<'EOF' )
## Clear out all of the bits for the interface mark
#{IPTablesCommand} #{args} -j MARK --and-mark 0xFFFF0000
EOF
    ## Chain Used for natting in the prerouting table.
    PostNat = Chain.new( "urchin-post-nat", "nat", "POSTROUTING", <<'EOF' )
## Do not NAT packets destined to local host.
#{IPTablesCommand} #{args} -o lo -j RETURN
EOF

    ## Chain Used for natting in the postrouting table.
    PreNat = Chain.new( "urchin-pre-nat", "nat", "PREROUTING" )

    Order = [ MarkInterface, PreNat, PostNat ]
  end
  
  def commit
    pf_file = []

    pf_file << header

    ## insert the commands to flush the existing tables.
    pf_file << flush

    ## insert the commands to create all of the tables
    pf_file << init_chains
    
    Interface.find( :all ).each do |interface|
      ## labelling
      pf_file << marking( interface )
      
      ## Insert the commands to filter traffic
      pf_file << filtering( interface )
      
      ## Insert the commands to handle NAT
      pf_file << nat( interface )
    end

    ## Delete all empty or nil parts
    pf_file = pf_file.delete_if { |p| p.nil? || p.empty? }
    
    ## Review : This is a bit verbose, and it has DebianSarge hardcoded
    overrideManager = OSLibrary.getOS( "DebianSarge" ).manager( "override_manager" )    
    overrideManager.write_file( ConfigFile, pf_file.join( "\n" ), "\n" )
    
    raise "Unable to iptables rules." unless Kernel.system( "#{Service} restart" )
  end
  
  private
  
  ## Flush all of the existing rules
  def flush
    ## The space before the for is so that emacs parses this line properly.
    <<EOF
## Flush all of the rules.
 for t_table in `cat /proc/net/ip_tables_names` ; do #{IPTablesCommand} -t ${t_table} -F ; done
EOF
  end

  ## Create all of the sub tables
  def init_chains
    Chain::Order.map do |chain|
      <<EOF
#{IPTablesCommand} -t #{chain.table} -N #{chain.name} 2> /dev/null
#{IPTablesCommand} -t #{chain.table} -F #{chain.name}
#{IPTablesCommand} -t #{chain.table} -A #{chain.start_chain} -j #{chain.name}
#{chain.init}
EOF
    end.join( "\n" )
  end
  
  ## REVIEW Need some way of labelling bridges, this means it needs an index.
  ## bridges right now are somewhat of a virtual concept (see is_bridge in interface).
  ## so indexing them is tough.
  ## Interface labelling
  def marking( interface )
    match = "-i #{interface.os_name}"
    match = "-m physdev --physdev-in #{interface.os_name}" if interface.is_bridge?
    mask = 1 << ( interface.index - 1 )
    rules = "#{IPTablesCommand} #{Chain::MarkInterface.args} #{match} -j MARK --or-mark #{mask}"

    ## REVIEW Insert the mark for locally destined packets.

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

    nat_policies.each do |policy|
      ## REVIEW Need to handle the proper ports
      if ( policy.new_source == NatPolicy::Automatic )
        target = "MASQUERADE"
      else
        target = "SNAT --to-source #{policy.new_source}"
      end
      
      ## Global netmask, use the addresses for the interface
      if ( policy.netmask == "0" || policy.netmask == "0.0.0.0" )
        config.ip_networks.each do |ip_network|
          network = "#{ip_network.ip}/#{OSLibrary::NetworkManager.parseNetmask( ip_network.netmask )}"
          rules << "#{IPTablesCommand} #{Chain::PostNat.args} ! -o #{name} -s #{network} -j #{target}"
        end
      else
        network = "#{policy.ip}/#{OSLibrary::NetworkManager.parseNetmask( policy.netmask )}"
        rules << "#{IPTablesCommand} #{Chain::PostNat.args} ! -o #{name} -s #{network} -j #{target}"
      end
    end

    rules.join( "\n" )
  end

  def header
    <<EOF
#!/bin/dash

## #{Time.new}
## Auto Generated by the Untangle Net Urchin
## If you modify this file manually, your changes
## may be overriden

iptables_debug()
{
   echo /sbin/iptables $*
   /sbin/iptables $*
}

IPTABLES=/sbin/iptables

IPTABLES="iptables_debug"

EOF
  end
end
