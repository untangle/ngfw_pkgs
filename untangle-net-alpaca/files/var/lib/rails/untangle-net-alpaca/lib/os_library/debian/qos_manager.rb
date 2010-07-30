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
class OSLibrary::Debian::QosManager < OSLibrary::QosManager
  include Singleton

  ProtocolMap = {
    "tcp" => 6,
    "udp" => 17,
    "icmp" => 1,
    "gre" => 47,
    "esp" => 50,
    "ah" => 51,
    "sctp" => 132
  }

  QoSStartLog = "/var/log/untangle-net-alpaca/qosstart.log"
  QoSRRDLog = "/var/log/untangle-net-alpaca/qosrrd.log"

  QoSConfig = "/etc/untangle-net-alpaca/qos-config"
  QoSRules = "/etc/untangle-net-alpaca/tc-rules.d"
#   PriorityMap = { 10 => "HIGHPRIO", 20 => "MIDPRIO", 30 => "LOWPRIO" }
#   PriorityFiles = { "SYSTEM" => QoSRules + "/900-system-priority",
#                     "HIGHPRIO" => QoSRules + "/100-high-priority",
#                     "MIDPRIO"  => QoSRules + "/200-mid-priority",
#                     "LOWPRIO"  => QoSRules + "/300-low-priority" }
  Service = "/etc/untangle-net-alpaca/qos-service"
  AptLog = "/var/log/uvm/apt.log"
  PriorityQueueToName = { 
    "10:" => "0 - None", 
    "11:" => "1 - Very High", 
    "12:" => "2 - High", 
    "13:" => "3 - Medium", 
    "14:" => "4 - Low",
    "15:" => "5 - Limited", 
    "16:" => "6 - Limited More", 
    "17:" => "7 - Limited Severely" }

  IPTablesCommand = OSLibrary::Debian::PacketFilterManager::IPTablesCommand
  
  Chain = OSLibrary::Debian::PacketFilterManager::Chain
  
  QoSMark = Chain.new( "alpaca-qos", "mangle", "PREROUTING", "" )

  #packet filter iptables integration
  QoSPacketFilterFile = "#{OSLibrary::Debian::PacketFilterManager::ConfigDirectory}/800-qos"

  ## Mark QoS priority buckets
  MarkQoSClass   = [0x00000000,
                    0x00100000,
                    0x00200000,
                    0x00300000,
                    0x00400000,
                    0x00500000,
                    0x00600000,
                    0x00700000]
  MarkQoSMask     = 0x00700000
  MarkQoSInverseMask  = 0xFF8FFFFF

  def status_v2( wan_interfaces = nil )
    lines = `#{Service} status2`
    pieces = lines.split( Regexp.new( 'interface: ', Regexp::MULTILINE ) )

    results = []

    if ( wan_interfaces.nil? )
      wan_interfaces = Interface.wan_interfaces
    end

    interface_name_map = {}
    wan_interfaces.each { |i| interface_name_map[i.os_name] = i.name }
      
    pieces.each do |piece|
      next unless piece.include?( "htb" ) and piece.include?( "leaf" )
      piece = piece.strip
      stats = piece.split( Regexp.new( '\s+', Regexp::MULTILINE ) )
      
      intf = stats[0]
      que_num = stats[6]
      rate = stats[10]
      burst = stats[14]
      sent = stats[18] + " " + stats[19]
      tokens = stats[43]
      ctokens = stats[45]
      
      queue_name = PriorityQueueToName[que_num]
      next if queue_name.nil?
      
      interface_name = interface_name_map[intf] 
      interface_name += " Outbound" if !interface_name.nil?
      if interface_name.nil? then
        # if imq - try 
        interface_name = interface_name_map[intf.sub("imq","eth")] 
        interface_name += " Inbound" if !interface_name.nil?
      end
      interface_name = intf if interface_name.nil?

      #( interface_name, priority, rate, burst, sent, tokens, ctokens )
      results << QosStatus.new( interface_name, queue_name,
                                rate,
                                burst,
                                sent,
                                tokens,
                                ctokens )
    end

    results
  end
  
  def start_time
    begin
      return File.mtime( QoSStartLog )
    rescue
    end
    ""
  end

  # FIXME
  def estimate_bandwidth
     download = "Unknown"
     upload = "Unknown"
     begin
       download = `rrdtool fetch #{QoSRRDLog} MAX | cut -d " " -f 2 | sort -n | tail -1`.to_f.round
       f = File.new( AptLog, "r" )
       f.each_line do |line|
         downloadMatchData = line.match( /Fetched.*\(([0-9]+)kB\/s\)/ )
         if ! downloadMatchData.nil? and downloadMatchData.length >= 2
            download = downloadMatchData[1] 
         end
       end
       upload = `rrdtool fetch #{QoSRRDLog} MAX | cut -d " " -f 3 | sort -n | tail -1`.to_f.round
     rescue
       # default to unkown
     end
     return [download, upload]
  end

  # FIXME
  def estimate_bandwidth_v2
     download = "Unknown"
     upload = "Unknown"
     begin
       download = `rrdtool fetch #{QoSRRDLog} MAX | cut -d " " -f 2 | sort -n | tail -1`.to_f.round
       f = File.new( AptLog, "r" )
       f.each_line do |line|
         downloadMatchData = line.match( /Fetched.*\(([0-9]+)kB\/s\)/ )
         if ! downloadMatchData.nil? and downloadMatchData.length >= 2
            download = downloadMatchData[1] 
         end
       end
       upload = `rrdtool fetch #{QoSRRDLog} MAX | cut -d " " -f 3 | sort -n | tail -1`.to_f.round
     rescue
       # default to unkown
     end
     return BandwithEstimate.new( download, upload )
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

  def hook_write_files
    tc_rules_files = {}

#     PriorityFiles.each_pair do |key, filename|
#       tc_rules_files[key] = header 
#     end

    qos_settings = QosSettings.find( :first )
    qos_settings = QosSettings.new if qos_settings.nil?
    qos_enabled = "NO"
    if qos_settings.enabled
      qos_enabled = "YES"
    end

    wan_interfaces = Interface.wan_interfaces

    qos_classes = QosClass.find( :all )

    settings = header
    settings << <<EOF

# global parameters
QOS_ENABLED=#{qos_enabled}
UPLINKS="#{wan_interfaces.map { |i| i.os_name }.join( " " )}"
DEFAULT_CLASS=#{qos_settings.default_class}
EOF

    wan_interfaces.each do |intf|
      build_interface_config( intf, qos_settings, settings, tc_rules_files )
    end

    wan_interfaces.each do |intf|
      qos_classes.each do |clazz|
        build_class_config( clazz, intf, qos_settings, settings, tc_rules_files )
      end
    end

    custom_rules = QosRule.find( :all, :conditions => [ "enabled='t'" ] )

    os["override_manager"].write_file( QoSConfig, settings, "\n" )

# XXX
# XXX
# XXX
#    rules.each do |rule|
#      build_qos_rule( wan_interfaces, rule, tc_rules_files )
#    end

#     tc_rules_files.each_pair do |key, file_contents|
#       os["override_manager"].write_executable( PriorityFiles[key], file_contents, "\n" )
#     end

    
    iptables_rules = header + "\n"

    iptables_rules << <<EOF
add_iptables_rules()
{
    echo "### Add IPTables Rules ###"

    echo "# Set the default mark on UNTRACKED sessions"

    # You would not think untracked sessions could have Connmark, but I think they actually all share the same connmark
    # This connmark should not be used anywhere, however we save the default one just in case.
    # ${IPTABLES} -t mangle -A alpaca-qos -m state --state UNTRACKED -j CONNMARK --set-mark 0x00${DEFAULT_CLASS}00000/0x00700000

    echo "# Restore the mark for TRACKED sessions"
    # Using -m state --state instead of -m conntrack --ctstate ref: http://markmail.org/thread/b7eg6aovfh4agyz7
    ${IPTABLES} -t mangle -A alpaca-qos -m state ! --state UNTRACKED -j CONNMARK --restore-mark --mask 0x00700000

    # for i in 1 2 3 4 5 6 7 ; do 
        # these are likely redundant
        # ${IPTABLES} -t mangle -A alpaca-qos -m connmark --mark 0x00${i}00000/0x00700000 -g qos-class${i}
        # ${IPTABLES} -t mangle -A alpaca-qos -m mark --mark 0x00${i}00000/0x00700000 -g qos-class${i}
    # done

    for i in 1 2 3 4 5 6 7 ; do 
        ${IPTABLES} -t mangle -N qos-class${i} 2> /dev/null
        ${IPTABLES} -t mangle -F qos-class${i}
        ${IPTABLES} -t mangle -A qos-class${i} -j MARK --set-mark 0x00${i}00000/0x00700000
        ${IPTABLES} -t mangle -A qos-class${i} -j CONNMARK --set-mark 0x00${i}00000/0x00700000
    done

    ${IPTABLES} -t mangle -A POSTROUTING -j alpaca-qos
}

flush_iptables_rules()
{
    echo "### Flush IPTables Rules ###"
    ${IPTABLES} -t mangle -F alpaca-qos 2> /dev/null

    for i in 1 2 3 4 5 6 7 ; do 
       ${IPTABLES} -t mangle -F qos-class${i} 2> /dev/null
    done

    ${IPTABLES} -t mangle -D POSTROUTING -j alpaca-qos
}
EOF

    iptables_rules << <<EOF
### Initialize QoS Table ###
#{IPTablesCommand} -t #{QoSMark.table} -N #{QoSMark.name} 2> /dev/null
#{IPTablesCommand} -t #{QoSMark.table} -F #{QoSMark.name}
flush_iptables_rules

#{QoSMark.init}

add_iptables_rules
EOF

    wan_interfaces.each do |intf|
      dev_num = intf.os_name.delete "a-z."
      dev_match = "-i #{intf.os_name}"
      physdev_match = "-m physdev --physdev-in #{intf.os_name}"
        
      iptables_rules << "#{IPTablesCommand} -t mangle -A PREROUTING #{dev_match} -j IMQ --todev #{dev_num}\n"
      iptables_rules << "#{IPTablesCommand} -t mangle -A PREROUTING #{physdev_match} -j IMQ --todev #{dev_num}\n"
    end

    if qos_settings.prioritize_ping != 0 then 
      # mark both packet and session
      target = " -g qos-class#{qos_settings.prioritize_ping} "
      iptables_rules << "### Prioritize Ping ###\n"
      iptables_rules << "#{IPTablesCommand} #{QoSMark.args} -p icmp --icmp-type echo-request #{target}\n"
      iptables_rules << "#{IPTablesCommand} #{QoSMark.args} -p icmp --icmp-type echo-reply   #{target}\n"
    end

    if qos_settings.prioritize_ssh != 0 then 
      # mark both packet and session
      target = " -g qos-class#{qos_settings.prioritize_ssh} "
      iptables_rules << "### Prioritize SSH ###\n"
      iptables_rules << "#{IPTablesCommand} #{QoSMark.args} -p tcp --dport 22 #{target}\n"
    end

    if qos_settings.prioritize_dns != 0 then 
      # mark both packet and session
      target = " -g qos-class#{qos_settings.prioritize_dns} "
      iptables_rules << "### Prioritize DNS ###\n"
      iptables_rules << "#{IPTablesCommand} #{QoSMark.args} -p udp --dport 53 #{target}\n"
      iptables_rules << "#{IPTablesCommand} #{QoSMark.args} -p tcp --dport 53 #{target}\n"
    end

    if qos_settings.prioritize_gaming != 0 then 
      iptables_rules << "### Prioritize Gaming ###\n"
      # mark both packet and session
      target = " -g qos-class#{qos_settings.prioritize_gaming} "
      #XBOX Live
      iptables_rules << "#{IPTablesCommand} #{QoSMark.args} -p udp -m multiport --destination-ports 88 #{target} \n"
      iptables_rules << "#{IPTablesCommand} #{QoSMark.args} -p tcp -m multiport --destination-ports 3074 #{target} \n"
      iptables_rules << "#{IPTablesCommand} #{QoSMark.args} -p udp -m multiport --destination-ports 3074 #{target} \n"
      #PS3
      iptables_rules << "#{IPTablesCommand} #{QoSMark.args} -p tcp -m multiport --destination-ports 5223 #{target} \n"
      iptables_rules << "#{IPTablesCommand} #{QoSMark.args} -p udp -m multiport --destination-ports 3478:3479 #{target} \n"
      #wii
      iptables_rules << "#{IPTablesCommand} #{QoSMark.args} -p tcp -m multiport --destination-ports 29900 #{target} \n"
      iptables_rules << "#{IPTablesCommand} #{QoSMark.args} -p tcp -m multiport --destination-ports 29901 #{target} \n"
      iptables_rules << "#{IPTablesCommand} #{QoSMark.args} -p tcp -m multiport --destination-ports 28910 #{target} \n"
      iptables_rules << "#{IPTablesCommand} #{QoSMark.args} -p tcp -m multiport --destination-ports 29920 #{target} \n"
      # other games
      iptables_rules << "#{IPTablesCommand} #{QoSMark.args} -p tcp -m multiport --destination-ports 1200 #{target} \n"
      iptables_rules << "#{IPTablesCommand} #{QoSMark.args} -p udp -m multiport --destination-ports 1200 #{target} \n"
      iptables_rules << "#{IPTablesCommand} #{QoSMark.args} -p tcp -m multiport --destination-ports 4000 #{target} \n"
      iptables_rules << "#{IPTablesCommand} #{QoSMark.args} -p udp -m multiport --destination-ports 4000 #{target} \n"
      iptables_rules << "#{IPTablesCommand} #{QoSMark.args} -p tcp -m multiport --destination-ports 6003 #{target} \n"
      iptables_rules << "#{IPTablesCommand} #{QoSMark.args} -p udp -m multiport --destination-ports 6003 #{target} \n"
      iptables_rules << "#{IPTablesCommand} #{QoSMark.args} -p udp -m multiport --destination-ports 6073 #{target} \n"
      iptables_rules << "#{IPTablesCommand} #{QoSMark.args} -p tcp -m multiport --destination-ports 7000 #{target} \n"
      iptables_rules << "#{IPTablesCommand} #{QoSMark.args} -p udp -m multiport --destination-ports 7000 #{target} \n"
      iptables_rules << "#{IPTablesCommand} #{QoSMark.args} -p tcp -m multiport --destination-ports 7002 #{target} \n"
      iptables_rules << "#{IPTablesCommand} #{QoSMark.args} -p udp -m multiport --destination-ports 7002 #{target} \n"
      iptables_rules << "#{IPTablesCommand} #{QoSMark.args} -p tcp -m multiport --destination-ports 8080 #{target} \n"
      iptables_rules << "#{IPTablesCommand} #{QoSMark.args} -p udp -m multiport --destination-ports 8080 #{target} \n"
      iptables_rules << "#{IPTablesCommand} #{QoSMark.args} -p tcp -m multiport --destination-ports 27900 #{target} \n"
      iptables_rules << "#{IPTablesCommand} #{QoSMark.args} -p udp -m multiport --destination-ports 27900 #{target} \n"
      iptables_rules << "#{IPTablesCommand} #{QoSMark.args} -p tcp -m multiport --destination-ports 27910 #{target} \n"
      iptables_rules << "#{IPTablesCommand} #{QoSMark.args} -p udp -m multiport --destination-ports 27910 #{target} \n"
      iptables_rules << "#{IPTablesCommand} #{QoSMark.args} -p tcp -m multiport --destination-ports 2300:2400 #{target} \n"
      iptables_rules << "#{IPTablesCommand} #{QoSMark.args} -p udp -m multiport --destination-ports 2300:2400 #{target} \n"
      iptables_rules << "#{IPTablesCommand} #{QoSMark.args} -p tcp -m multiport --destination-ports 6112:6119 #{target} \n"
      iptables_rules << "#{IPTablesCommand} #{QoSMark.args} -p udp -m multiport --destination-ports 6112:6119 #{target} \n"
      iptables_rules << "#{IPTablesCommand} #{QoSMark.args} -p tcp -m multiport --destination-ports 7777:7783 #{target} \n"
      iptables_rules << "#{IPTablesCommand} #{QoSMark.args} -p udp -m multiport --destination-ports 7777:7783 #{target} \n"
      iptables_rules << "#{IPTablesCommand} #{QoSMark.args} -p tcp -m multiport --destination-ports 6112:6119 #{target} \n"
      iptables_rules << "#{IPTablesCommand} #{QoSMark.args} -p udp -m multiport --destination-ports 6112:6119 #{target} \n"
    end

    iptables_rules << "### Custom Rules ###\n"

    custom_rules.each do |rule|
      begin
        filters, chain = OSLibrary::Debian::Filter::Factory.instance.filter( rule.filter )
        
        target = " -g qos-class#{rule.priority} "
        # only match bypassed sessions (but non-local sessions are also marked with this)
        bypass = " -m mark --mark 0x01000000/0x01000000 "
        # so also only match connections that are not untracked (this avoids matching non-locally bound sessions)
        untrac = " -m state ! --state UNTRACKED "

        filters.each do |filter|
          ## Nothing to do if the filtering string is empty.
          break if filter.strip.empty?
          iptables_rules << "#{IPTablesCommand} #{QoSMark.args} #{filter} #{bypass} #{untrac} #{target}\n"
        end
      rescue
        logger.warn( "The filter '#{rule.filter}' could not be parsed: #{$!}" )
      end
    end

    #
    # These rules only match specific packets (not the entire session)
    # As such they only mark the packet (not the connmark) and they must be evaluated last
    #
    iptables_rules << "### Packet Rules ###\n"

    if qos_settings.prioritize_tcp_control != 0 then 
      # only mark packet
      target = "-j MARK --set-mark 0x00#{qos_settings.prioritize_tcp_control}00000/0x00700000"
      iptables_rules << "### Prioritize TCP control ###\n"
      iptables_rules << "#{IPTablesCommand} #{QoSMark.args} -p tcp --tcp-flags SYN SYN #{target}\n"
      iptables_rules << "#{IPTablesCommand} #{QoSMark.args} -p tcp --tcp-flags RST RST #{target}\n"
      iptables_rules << "#{IPTablesCommand} #{QoSMark.args} -p tcp --tcp-flags FIN FIN #{target}\n"
    end



    # add default rules
    # these don't point to qos-classX because they need to be separate.
    # It is possible that the packet has been marked but the connmark has not (example: SYN)
    # If no connmark, save the default connmark
    # If no mark, save the default mark
    iptables_rules << "#{IPTablesCommand} #{QoSMark.args} -m connmark --mark 0x00000000/0x00700000 -j CONNMARK --set-mark 0x00#{qos_settings.default_class}00000/0x00700000\n"
    iptables_rules << "#{IPTablesCommand} #{QoSMark.args} -m mark --mark 0x00000000/0x00700000 -j MARK --or-mark 0x00#{qos_settings.default_class}00000\n"

    os["override_manager"].write_file( QoSPacketFilterFile, iptables_rules, "\n" )    
  end

  def hook_run_services
    logger.warn "Unable to stop #{Service}." unless run_command( "#{Service} stop" ) == 0
    logger.warn "Unable to start #{Service}" unless run_command( "#{Service} start" ) == 0
  end

  def commit
    write_files
    run_services
  end
  
  def register_hooks
    os["packet_filter_manager"].register_hook( 100, "qos_manager", "write_files", :hook_write_files )
    os["network_manager"].register_hook( 100, "qos_manager", "write_files", :hook_write_files )
    os["packet_filter_manager"].register_hook( 1000, "qos_manager", "run_services", :hook_run_services )
    os["network_manager"].register_hook( 1000, "qos_manager", "run_services", :hook_run_services )
  end

  private
  def build_class_config( clazz, interface, qos_settings, text, tc_rules_files )
    os_name = interface.os_name

    download_limit = (clazz.download_limit/100.0 * interface.download_bandwidth * qos_settings.scaling_factor/100.0).round
    upload_limit = (clazz.upload_limit/100.0 * interface.upload_bandwidth * qos_settings.scaling_factor/100.0).round
    upload_reserved = (clazz.upload_reserved/100.0 * interface.upload_bandwidth  * qos_settings.scaling_factor/100.0).round

    # 0 has special meaning (means "no limit" or "no reservation")
    download_limit = "none" if clazz.download_limit == 0
    upload_limit = "none" if clazz.upload_limit == 0
    upload_reserved = "none" if clazz.upload_reserved == 0

    if clazz.class_id == 0 then
      text << "\n# class/priority parameters\n"
    end

    text << <<EOF
#{os_name}_CLASS#{clazz.class_id}_DOWNLOAD_LIMIT=#{download_limit}
#{os_name}_CLASS#{clazz.class_id}_UPLOAD_LIMIT=#{upload_limit}
#{os_name}_CLASS#{clazz.class_id}_UPLOAD_RESERVED=#{upload_reserved}
EOF
  end

  private
  def build_interface_config( interface, qos_settings, text, tc_rules_files )
    os_name = interface.os_name
    dev = os_name

    # FIXME
    # handle PPPoE

    text << <<EOF

# ${os_name} parameters
## #{os_name}_DOWNLOAD_BANDWIDTH=#{interface.download_bandwidth}
## #{os_name}_UPLOAD_BANDWIDTH=#{interface.upload_bandwidth}
EOF

#     if ! qos_settings.prioritize_ping.nil? and qos_settings.prioritize_ping > 0
#       tc_rules_files["SYSTEM"] << "tc filter add dev #{dev} parent 1: protocol ip prio #{qos_settings.prioritize_ping} u32 match ip protocol 1 0xff flowid 1:#{qos_settings.prioritize_ping}\n"
#     end

#     if ! qos_settings.prioritize_ack.nil? and qos_settings.prioritize_ack > 0
#       tc_rules_files["SYSTEM"] << "tc filter add dev #{dev} parent 1: protocol ip prio #{qos_settings.prioritize_ack} u32 match ip protocol 6 0xff match u8 0x05 0x0f at 0 match u16 0x0000 0xffc0 at 2 match u8 0x10 0xff at 33 flowid 1:#{qos_settings.prioritize_ack}\n"
#     end
  end

  def build_qos_rule( wan_interfaces, rule, tc_rules_files )
    begin

      ## The rules that don't match this criteria must be handled in iptables.
      return if rule.filter.include?( "s-" )
      return if rule.filter.include?( "d-local" )
      return unless rule.filter.include?( "d-" )

      priority = PriorityMap[rule.priority]
      filter = ""
      protocol_filter = []
      conditions = rule.filter.split( "&&" )

      conditions.each do |condition|
        type, value = condition.split( "::" )
        case type
        when "d-port"
          filter << " match ip dport #{value} 0xffff "
        when "d-addr"
          if ! value.include?( "/" )
            value << "/32"
          end
          filter << " match ip dst #{value} "
        when "protocol"
          value.split( "," ).each do |protocol|
            protocol = protocol.strip
            protocol_id = ProtocolMap[protocol]
            next if protocol_id.nil?
            protocol_filter << "  match ip protocol #{protocol_id} 0xff "
          end
        end
      end

      ## If the protocol is not specified, apply this QoS rule to all protocols.
      if protocol_filter.length == 0
        protocol_filter = [ "" ]
      end

      

      ## Apply this QoS rule to all of the WAN interfaces
      wan_interfaces.each do |interface|
        os_name = interface.os_name

        #if interface.current_config.is_a?( IntfPppoe )
        #  os_name="${PPPOE_INTERFACE_#{interface.os_name.downcase}}"
        #end

        protocol_filter.each do |protocol_filter|
          tc_rules_files[priority] << "tc filter add dev #{os_name} parent 1: protocol ip prio #{rule.priority} u32 #{protocol_filter} #{filter} flowid 1:#{rule.priority}\n"
        end
      end

    rescue
      logger.warn( "The filter '#{rule.filter}' could not be parsed: #{$!}" )
    end
  end
end

