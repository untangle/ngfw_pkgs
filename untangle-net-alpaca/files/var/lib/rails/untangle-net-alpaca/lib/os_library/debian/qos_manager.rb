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

  QoSConfig = "/etc/untangle-net-alpaca/untangle-qos"
  QoSRules = "/etc/untangle-net-alpaca/tc-rules.d"
  PriorityMap = { 10 => "HIGHPRIO", 20 => "MIDPRIO", 30 => "LOWPRIO" }
  PriorityFiles = { "SYSTEM" => QoSRules + "/900-system-priority",
                    "HIGHPRIO" => QoSRules + "/100-high-priority",
                    "MIDPRIO"  => QoSRules + "/200-mid-priority",
                    "LOWPRIO"  => QoSRules + "/300-low-priority" }
  Service = "/etc/untangle-net-alpaca/wshaper.htb"
  AptLog = "/var/log/uvm/apt.log"
  PriorityQueueToName = { "30:" => "Low", "20:" => "Normal", "10:" => "High", "1:" => "Root" }

  IPTablesCommand = OSLibrary::Debian::PacketFilterManager::IPTablesCommand
  
  Chain = OSLibrary::Debian::PacketFilterManager::Chain
  
  QoSMark = Chain.new( "alpaca-qos", "mangle", "PREROUTING", "" )

  #packet filter iptables integration
  QoSPacketFilterFile = "#{OSLibrary::Debian::PacketFilterManager::ConfigDirectory}/800-qos"
  ## Mark QoS priority buckets
  MarkQoSHigh  = 0x00C00000
  MarkQoSNormal= 0x00400000
  MarkQoSLow   = 0x00200000
  MarkQoSMask  = 0x00E00000
  MarkQoSInverseMask  = 0xFF1FFFFF


  def status
     results = []
     lines = `#{Service} status`
     pieces = lines.split( Regexp.new( 'qdisc|class', Regexp::MULTILINE ) )
     pieces.each do |piece|
       if piece.include?( "htb" ) and piece.include?( "leaf" )
         stats = piece.split( Regexp.new( ' ', Regexp::MULTILINE ) )
         
         if PriorityQueueToName.has_key?( stats[6] )
           token_stats = piece.split( Regexp.new( 'c?tokens: ', Regexp::MULTILINE ) )
           results << [ PriorityQueueToName[stats[6]],
                        stats[10],
                        stats[14],
                        stats[19] + stats[20],
                        token_stats[1],
                        token_stats[2]
                      ]
         end
       end
     end
     return results
  end

  def status_v2( wan_interfaces = nil )
    lines = `#{Service} alpaca_status`
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
      
      queue_name = PriorityQueueToName[stats[7]]
      next if queue_name.nil?
      
      interface_name = interface_name_map[stats[0]]
      interface_name = stats[0] if interface_name.nil?

      results << QosStatus.new( interface_name, queue_name,
                                stats[11],
                                stats[15],
                                stats[19] + " " + stats[20],
                                stats[44],
                                stats[46] )
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

    PriorityFiles.each_pair do |key, filename|
      tc_rules_files[key] = header 
    end

    qos_settings = QosSettings.find( :first )
    qos_settings = QosSettings.new if qos_settings.nil?
    qos_enabled = "NO"
    if qos_settings.enabled
      qos_enabled = "YES"
    end

    wan_interfaces = Interface.wan_interfaces

    settings = header
    settings << <<EOF
QOS_ENABLED=#{qos_enabled}
UPLINKS="#{wan_interfaces.map { |i| i.os_name }.join( " " )}"
EOF

    wan_interfaces.each do |i|
      build_interface_config( i, qos_settings, settings, tc_rules_files )
    end

    rules = QosRule.find( :all, :conditions => [ "enabled='t'" ] )

    rules.each do |rule|
      build_qos_rule( wan_interfaces, rule, tc_rules_files )
    end

    tc_rules_files.each_pair do |key, file_contents|
      os["override_manager"].write_executable( PriorityFiles[key], file_contents, "\n" )
    end

    os["override_manager"].write_file( QoSConfig, settings, "\n" )
    
    text = header + "\n"
    text << <<EOF
#{IPTablesCommand} -t #{QoSMark.table} -N #{QoSMark.name} 2> /dev/null
#{IPTablesCommand} -t #{QoSMark.table} -F #{QoSMark.name}
#{QoSMark.init}

${IPTABLES} -t mangle -A #{QoSMark.name} -m connmark --mark #{MarkQoSHigh}/#{MarkQoSMask} -g qos-high-mark
${IPTABLES} -t mangle -A #{QoSMark.name} -m connmark --mark #{MarkQoSNormal}/#{MarkQoSMask} -g qos-normal-mark
${IPTABLES} -t mangle -A #{QoSMark.name} -m connmark --mark #{MarkQoSLow}/#{MarkQoSMask} -g qos-low-mark
${IPTABLES} -t mangle -N qos-high-mark 2> /dev/null
${IPTABLES} -t mangle -F qos-high-mark
${IPTABLES} -t mangle -A qos-high-mark -j MARK --or-mark #{MarkQoSHigh}
${IPTABLES} -t mangle -A qos-high-mark -j CONNMARK --set-mark #{MarkQoSHigh}/#{MarkQoSMask}
${IPTABLES} -t mangle -N qos-normal-mark 2> /dev/null
${IPTABLES} -t mangle -F qos-normal-mark
${IPTABLES} -t mangle -A qos-normal-mark -j MARK --or-mark #{MarkQoSNormal}
${IPTABLES} -t mangle -A qos-normal-mark -j CONNMARK --set-mark #{MarkQoSNormal}/#{MarkQoSMask}
${IPTABLES} -t mangle -N qos-low-mark 2> /dev/null
${IPTABLES} -t mangle -F qos-low-mark
${IPTABLES} -t mangle -A qos-low-mark -j MARK --or-mark #{MarkQoSLow}
${IPTABLES} -t mangle -A qos-low-mark -j CONNMARK --set-mark #{MarkQoSLow}/#{MarkQoSMask}

EOF

    if ! qos_settings.prioritize_ack.nil? and qos_settings.prioritize_gaming > 0 and qos_settings.prioritize_gaming != 20
      case qos_settings.prioritize_gaming
      when 10
         target = " -g qos-high-mark "
      when 30
         target = " -g qos-low-mark "
      end
      #XBOX Live
      text << "#{IPTablesCommand} #{QoSMark.args} -p udp -m multiport --destination-ports 88 -g #{target} \n"
      text << "#{IPTablesCommand} #{QoSMark.args} -p tcp -m multiport --destination-ports 3074 -g #{target} \n"
      text << "#{IPTablesCommand} #{QoSMark.args} -p udp -m multiport --destination-ports 3074 -g #{target} \n"
      if qos_settings.prioritize_gaming == 10
          text << "#{IPTablesCommand} #{QoSMark.args} -p udp -m multiport --destination-ports 88 -g bypass-mark \n"
          text << "#{IPTablesCommand} #{QoSMark.args} -p tcp -m multiport --destination-ports 3074 -g bypass-mark \n"
          text << "#{IPTablesCommand} #{QoSMark.args} -p udp -m multiport --destination-ports 3074 -g bypass-mark \n"
      end
      #PS3
      text << "#{IPTablesCommand} #{QoSMark.args} -p tcp -m multiport --destination-ports 5223 #{target} \n"
      text << "#{IPTablesCommand} #{QoSMark.args} -p udp -m multiport --destination-ports 3478:3479 #{target} \n"
      if qos_settings.prioritize_gaming == 10
          text << "#{IPTablesCommand} #{QoSMark.args} -p tcp -m multiport --destination-ports 5223 -g bypass-mark \n"
          text << "#{IPTablesCommand} #{QoSMark.args} -p udp -m multiport --destination-ports 3478:3479 -g bypass-mark \n"
      end
      #wii
      text << "#{IPTablesCommand} #{QoSMark.args} -p tcp -m multiport --destination-ports 29900 #{target} \n"
      text << "#{IPTablesCommand} #{QoSMark.args} -p tcp -m multiport --destination-ports 29901 #{target} \n"
      text << "#{IPTablesCommand} #{QoSMark.args} -p tcp -m multiport --destination-ports 28910 #{target} \n"
      text << "#{IPTablesCommand} #{QoSMark.args} -p tcp -m multiport --destination-ports 29920 #{target} \n"
      if qos_settings.prioritize_gaming == 10
          text << "#{IPTablesCommand} #{QoSMark.args} -p tcp -m multiport --destination-ports 29900 -g bypass-mark \n"
          text << "#{IPTablesCommand} #{QoSMark.args} -p tcp -m multiport --destination-ports 29901 -g bypass-mark \n"
          text << "#{IPTablesCommand} #{QoSMark.args} -p tcp -m multiport --destination-ports 28910 -g bypass-mark \n"
          text << "#{IPTablesCommand} #{QoSMark.args} -p tcp -m multiport --destination-ports 29920 -g bypass-mark \n"
      end
      # other games
      text << "#{IPTablesCommand} #{QoSMark.args} -p tcp -m multiport --destination-ports 1200 #{target} \n"
      text << "#{IPTablesCommand} #{QoSMark.args} -p udp -m multiport --destination-ports 1200 #{target} \n"
      text << "#{IPTablesCommand} #{QoSMark.args} -p tcp -m multiport --destination-ports 4000 #{target} \n"
      text << "#{IPTablesCommand} #{QoSMark.args} -p udp -m multiport --destination-ports 4000 #{target} \n"
      text << "#{IPTablesCommand} #{QoSMark.args} -p tcp -m multiport --destination-ports 6003 #{target} \n"
      text << "#{IPTablesCommand} #{QoSMark.args} -p udp -m multiport --destination-ports 6003 #{target} \n"
      text << "#{IPTablesCommand} #{QoSMark.args} -p udp -m multiport --destination-ports 6073 #{target} \n"
      text << "#{IPTablesCommand} #{QoSMark.args} -p tcp -m multiport --destination-ports 7000 #{target} \n"
      text << "#{IPTablesCommand} #{QoSMark.args} -p udp -m multiport --destination-ports 7000 #{target} \n"
      text << "#{IPTablesCommand} #{QoSMark.args} -p tcp -m multiport --destination-ports 7002 #{target} \n"
      text << "#{IPTablesCommand} #{QoSMark.args} -p udp -m multiport --destination-ports 7002 #{target} \n"
      text << "#{IPTablesCommand} #{QoSMark.args} -p tcp -m multiport --destination-ports 8080 #{target} \n"
      text << "#{IPTablesCommand} #{QoSMark.args} -p udp -m multiport --destination-ports 8080 #{target} \n"
      text << "#{IPTablesCommand} #{QoSMark.args} -p tcp -m multiport --destination-ports 27900 #{target} \n"
      text << "#{IPTablesCommand} #{QoSMark.args} -p udp -m multiport --destination-ports 27900 #{target} \n"
      text << "#{IPTablesCommand} #{QoSMark.args} -p tcp -m multiport --destination-ports 27910 #{target} \n"
      text << "#{IPTablesCommand} #{QoSMark.args} -p udp -m multiport --destination-ports 27910 #{target} \n"
      text << "#{IPTablesCommand} #{QoSMark.args} -p tcp -m multiport --destination-ports 2300:2400 #{target} \n"
      text << "#{IPTablesCommand} #{QoSMark.args} -p udp -m multiport --destination-ports 2300:2400 #{target} \n"
      text << "#{IPTablesCommand} #{QoSMark.args} -p tcp -m multiport --destination-ports 6112:6119 #{target} \n"
      text << "#{IPTablesCommand} #{QoSMark.args} -p udp -m multiport --destination-ports 6112:6119 #{target} \n"
      text << "#{IPTablesCommand} #{QoSMark.args} -p tcp -m multiport --destination-ports 7777:7783 #{target} \n"
      text << "#{IPTablesCommand} #{QoSMark.args} -p udp -m multiport --destination-ports 7777:7783 #{target} \n"
      text << "#{IPTablesCommand} #{QoSMark.args} -p tcp -m multiport --destination-ports 6112:6119 #{target} \n"
      text << "#{IPTablesCommand} #{QoSMark.args} -p udp -m multiport --destination-ports 6112:6119 #{target} \n"
    end

    rules.each do |rule|
      begin
        filters, chain = OSLibrary::Debian::Filter::Factory.instance.filter( rule.filter )
        
        target = nil
        case rule.priority
        when 10
          target = " -g qos-high-mark "
        when 20
          target = " -g qos-normal-mark "
        when 30
          target = " -g qos-low-mark "
        end
        
        next if target.nil?
            
        filters.each do |filter|
          ## Nothing to do if the filtering string is empty.
          break if filter.strip.empty?
          text << "#{IPTablesCommand} #{QoSMark.args} #{filter} #{target}\n"
        end
      rescue
        logger.warn( "The filter '#{rule.filter}' could not be parsed: #{$!}" )
      end
    end

    os["override_manager"].write_file( QoSPacketFilterFile, text, "\n" )    
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
  def build_interface_config( interface, qos_settings, text, tc_rules_files )
    dev = interface.os_name

    #when using pppoe the actual interface is named ppp.#{os_name}
    if interface.current_config == IntfPppoe
        dev = OSLibrary::Debian::PppoEManager.get_pppoe_name( interface )
    end

    text << <<EOF
#{dev}_DOWNLOAD=#{interface.download_bandwidth * qos_settings.download_percentage/100}
#{dev}_UPLOAD=#{interface.upload_bandwidth * qos_settings.upload_percentage/100}
EOF

    if ! qos_settings.prioritize_ping.nil? and qos_settings.prioritize_ping > 0
      tc_rules_files["SYSTEM"] << "tc filter add dev #{dev} parent 1: protocol ip prio #{qos_settings.prioritize_ping} u32 match ip protocol 1 0xff flowid 1:#{qos_settings.prioritize_ping}\n"
    end

    if ! qos_settings.prioritize_ack.nil? and qos_settings.prioritize_ack > 0
      tc_rules_files["SYSTEM"] << "tc filter add dev #{dev} parent 1: protocol ip prio #{qos_settings.prioritize_ack} u32 match ip protocol 6 0xff match u8 0x05 0x0f at 0 match u16 0x0000 0xffc0 at 2 match u8 0x10 0xff at 33 flowid 1:#{qos_settings.prioritize_ack}\n"
    end
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

      if protocol_filter.length == 0
        protocol_filter = [ "" ]
      end

      wan_interfaces.each do |interface|
        os_name = interface.os_name

        protocol_filter.each do |protocol_filter|
          tc_rules_files[priority] << "tc filter add dev #{os_name} parent 1: protocol ip prio #{rule.priority} u32 #{protocol_filter} #{filter} flowid 1:#{rule.priority}\n"
        end
      end

      rescue
      logger.warn( "The filter '#{rule.filter}' could not be parsed: #{$!}" )
    end
  end
end

