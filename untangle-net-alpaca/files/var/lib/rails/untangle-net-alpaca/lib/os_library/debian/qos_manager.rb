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
  Service = "/etc/untangle-net-alpaca/qos-service"
  AptLog = "/var/log/uvm/apt.log"
  PriorityQueueToName = { 
    "10:" => "0 - Default", 
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

  ## packet filter iptables integration
  QosIptablesRuleFile = "#{OSLibrary::Debian::PacketFilterManager::ConfigDirectory}/800-qos"

  MarkQoSMask         = "0x00700000"
  MarkQoSInverseMask  = "0xFF8FFFFF"

  def status( wan_interfaces = nil )
    lines = `#{Service} status`
    pieces = lines.split( Regexp.new( 'interface: ', Regexp::MULTILINE ) )

    results = []

    if ( wan_interfaces.nil? )
      wan_interfaces = Interface.wan_interfaces
    end

    interface_name_map = {}
    wan_interfaces.each { |i| interface_name_map[i.os_name] = i.name }
      
    pieces.each do |piece|
      next unless piece.include?( "class htb" )
      piece = piece.strip
      stats = piece.split( Regexp.new( '\s+', Regexp::MULTILINE ) )

      # print "piece: ",piece,"\n"
      intf = stats[0]
      que_num = stats[7]
      rate = stats[11]
      burst = stats[15]
      sent = stats[19] + " " + stats[20]
      tokens = stats[44]
      ctokens = stats[46]
      # print "intf: ",intf," que_num: ",que_num,"\n"
      
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
      results << QosStatus.new( interface_name, queue_name, rate, burst, sent, tokens, ctokens )
    end

    results
  end

  def sessions( wan_interfaces = nil )
    lines = `#{Service} sessions`

    results = []

    if ( wan_interfaces.nil? )
      wan_interfaces = Interface.wan_interfaces
    end

    interface_name_map = {}
    wan_interfaces.each { |i| interface_name_map[i.os_name] = i.name }
      
    lines.each do |line|
      stats = line.split( Regexp.new( '\s+' ) )

      # print "line: ",line,"\n"
      proto = stats[1]
      state = stats[3]
      src = stats[5]
      dst = stats[7]
      src_port = stats[9]
      dst_port = stats[11]
      packets = stats[13]
      bytes = stats[15]
      priority = stats[17]
      # print "stats: ",proto,state,src,dst,src_port,dst_port,packets,bytes,priority,"\n"
      
      results << QosSession.new(proto,state,src,dst,src_port,dst_port,packets,bytes,priority)

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
      build_interface_config( intf, qos_settings, settings )
    end

    wan_interfaces.each do |intf|
      qos_classes.each do |clazz|
        build_class_config( clazz, intf, qos_settings, settings )
      end
    end

    custom_rules = QosRule.find( :all, :conditions => [ "enabled='t'" ] )

    os["override_manager"].write_file( QoSConfig, settings, "\n" )

    iptables_rules = header + "\n"

    iptables_rules << <<EOF
add_iptables_rules()
{
    echo "### Add IPTables Rules ###"

    # You would not think untracked sessions could have Connmark, but I think they actually all share the same connmark
    # This connmark should not be used anywhere, however we save the default one just in case.
    # ${IPTABLES} -t mangle -A alpaca-qos -m state --state UNTRACKED -j CONNMARK --set-mark 0x00${DEFAULT_CLASS}00000/#{MarkQoSMask}

    # if we see a UDP mark on a packet immediately save it to the conntrack before further processing
    # We do this because userspace may decide to mark a packet and we need to save it to conntrack
    ${IPTABLES} -t mangle -I alpaca-qos -p udp -m mark ! --mark 0x00000000/#{MarkQoSMask} -j CONNMARK --save-mark --mask #{MarkQoSMask}
    
    # also need to do this in the tune table because that is where UDP packets are QUEUEd
    # if there is a non-zero mark there we should save it. After the UVM is queue the packet it will release it with NF_REPEAT
    # and so this rule will save the new QoS mark
    ${IPTABLES} -t tune -I POSTROUTING -p udp -m mark ! --mark 0x00000000/#{MarkQoSMask} -j CONNMARK --save-mark --mask #{MarkQoSMask}

    # Using -m state --state instead of -m conntrack --ctstate ref: http://markmail.org/thread/b7eg6aovfh4agyz7
    ${IPTABLES} -t mangle -A alpaca-qos -m state ! --state UNTRACKED -j CONNMARK --restore-mark --mask #{MarkQoSMask}

    # Create special targets for both marking the current packet and the rest of the session via connmark
    for i in 1 2 3 4 5 6 7 ; do 
        ${IPTABLES} -t mangle -N qos-class${i} 2> /dev/null
        ${IPTABLES} -t mangle -F qos-class${i}
        ${IPTABLES} -t mangle -A qos-class${i} -j MARK --set-mark 0x00${i}00000/#{MarkQoSMask}
        ${IPTABLES} -t mangle -A qos-class${i} -j CONNMARK --set-mark 0x00${i}00000/#{MarkQoSMask}
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

    ${IPTABLES} -t mangle -D POSTROUTING -j alpaca-qos 2> /dev/null
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
      # must add source port to to catch traffic going back to non-local bound sockets (no connmark)
      iptables_rules << "#{IPTablesCommand} #{QoSMark.args} -p tcp --sport 22 #{target}\n"
    end

    if qos_settings.prioritize_dns != 0 then 
      # mark both packet and session
      target = " -g qos-class#{qos_settings.prioritize_dns} "
      iptables_rules << "### Prioritize DNS ###\n"
      iptables_rules << "#{IPTablesCommand} #{QoSMark.args} -p udp --dport 53 #{target}\n"
      iptables_rules << "#{IPTablesCommand} #{QoSMark.args} -p tcp --dport 53 #{target}\n"
      # must add source port to to catch traffic going back to non-local bound sockets (no connmark)
      iptables_rules << "#{IPTablesCommand} #{QoSMark.args} -p udp --sport 53 #{target}\n"
      iptables_rules << "#{IPTablesCommand} #{QoSMark.args} -p tcp --sport 53 #{target}\n"
    end

    if qos_settings.prioritize_openvpn != 0 then 
      # mark both packet and session
      target = " -g qos-class#{qos_settings.prioritize_openvpn} "
      iptables_rules << "### Prioritize DNS ###\n"
      iptables_rules << "#{IPTablesCommand} #{QoSMark.args} -p udp --dport 1194 #{target}\n"
      iptables_rules << "#{IPTablesCommand} #{QoSMark.args} -p tcp --dport 1194 #{target}\n"
      # must add source port to to catch traffic going back to non-local bound sockets (no connmark)
      iptables_rules << "#{IPTablesCommand} #{QoSMark.args} -p udp --sport 1194 #{target}\n"
      iptables_rules << "#{IPTablesCommand} #{QoSMark.args} -p tcp --sport 1194 #{target}\n"
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
      target = "-j MARK --set-mark 0x00#{qos_settings.prioritize_tcp_control}00000/#{MarkQoSMask}"
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
    iptables_rules << "#{IPTablesCommand} #{QoSMark.args} -m connmark --mark 0x00000000/#{MarkQoSMask} -j CONNMARK --set-mark 0x00#{qos_settings.default_class}00000/#{MarkQoSMask}\n"
    iptables_rules << "#{IPTablesCommand} #{QoSMark.args} -m mark --mark 0x00000000/#{MarkQoSMask} -j MARK --or-mark 0x00#{qos_settings.default_class}00000\n"

    os["override_manager"].write_file( QosIptablesRuleFile, iptables_rules, "\n" )    
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
  def build_class_config( clazz, interface, qos_settings, text )
    os_name = interface.os_name

    download_reserved = (clazz.download_reserved/100.0 * interface.download_bandwidth  * qos_settings.scaling_factor/100.0).round
    download_limit = (clazz.download_limit/100.0 * interface.download_bandwidth * qos_settings.scaling_factor/100.0).round
    upload_reserved = (clazz.upload_reserved/100.0 * interface.upload_bandwidth  * qos_settings.scaling_factor/100.0).round
    upload_limit = (clazz.upload_limit/100.0 * interface.upload_bandwidth * qos_settings.scaling_factor/100.0).round

    # 0 has special meaning (means "no limit" or "no reservation")
    download_limit = "none" if clazz.download_limit == 0
    upload_limit = "none" if clazz.upload_limit == 0
    upload_reserved = "none" if clazz.upload_reserved == 0
    download_reserved = "none" if clazz.download_reserved == 0

    if clazz.class_id == 0 then
      text << "\n# class/priority parameters\n"
    end

    text << <<EOF

#{os_name}_CLASS#{clazz.class_id}_UPLOAD_RESERVED=#{upload_reserved}
#{os_name}_CLASS#{clazz.class_id}_UPLOAD_LIMIT=#{upload_limit}
#{os_name}_CLASS#{clazz.class_id}_DOWNLOAD_RESERVED=#{download_reserved}
#{os_name}_CLASS#{clazz.class_id}_DOWNLOAD_LIMIT=#{download_limit}
EOF
  end

  private
  def build_interface_config( interface, qos_settings, text )
    os_name = interface.os_name
    dev = os_name


    text << <<EOF

# ${os_name} parameters
#{os_name}_DOWNLOAD_BANDWIDTH=#{interface.download_bandwidth}
#{os_name}_UPLOAD_BANDWIDTH=#{interface.upload_bandwidth}
EOF
  end

end

