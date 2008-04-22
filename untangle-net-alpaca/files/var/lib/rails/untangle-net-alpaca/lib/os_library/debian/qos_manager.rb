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

  QoSConfig = "/etc/untangle-net-alpaca/untangle-qos"
  QoSRules = "/etc/untangle-net-alpaca/tc-rules.d"
  PriorityFiles = { "SYSTEM" => QoSRules + "/50-system-priority",
                    "HIGHPRIO" => QoSRules + "/100-high-priority",
                    "MIDPRIO"  => QoSRules + "/200-mid-priority",
                    "LOWPRIO"  => QoSRules + "/300-low-priority" }
  Service = "/etc/untangle-net-alpaca/wshaper.htb"
  AptLog = "/var/log/uvm/apt.log"
  PriorityQueueToName = { "30:" => "Low", "20:" => "Normal", "10:" => "High" }

  def status
     results = []
     lines = `#{Service} status`
     pieces = lines.split( Regexp.new( 'qdisc|class', Regexp::MULTILINE ) )
     pieces.each do |piece|
       if piece.include?( "htb" ) and piece.include?( "leaf" )
         stats = piece.split( Regexp.new( ' ', Regexp::MULTILINE ) )
         
         if PriorityQueueToName.has_key?( stats[6] )
           results << [ PriorityQueueToName[stats[6]],
                        stats[10],
                        stats[14],
                        stats[19] + stats[20],
                        stats[24].sub( /,/, '' ),
                        stats[26].sub( /\)/, '' )
                      ]
         end
       end
     end
     return results
  end

  def estimate_bandwidth
     download = "Unknown"
     upload = "Unknown"
     begin
       f = File.new( AptLog, "r" )
       f.each_line do |line|
         downloadMatchData = line.match( /Fetched.*\(([0-9]+)kB\/s\)/ )
         if ! downloadMatchData.nil? and downloadMatchData.length >= 2
            download = downloadMatchData[1] 
            #TODO fix this hack
            upload = downloadMatchData[1].to_f/5.0
         end
       end
     rescue
       # default to unkown
     end
     return [download, upload]
  end

  def hook_write_files

    tc_rules_files = {}

    PriorityFiles.each_pair do |key, filename|
      tc_rules_files[key] = ""
    end

    qos_settings = QosSettings.find( :first )
    qos_settings = QosSettings.new if qos_settings.nil?
    qos_enabled = "NO"
    if qos_settings.enabled
      qos_enabled = "YES"
    end
    settings = "QOS_ENABLED=#{qos_enabled}\nDOWNLINK=#{qos_settings.download*qos_settings.download_percentage/100}\nUPLINK=#{qos_settings.upload*qos_settings.upload_percentage/100}\nDEV=#{Interface.external.os_name}\n\n"
    

    dev = Interface.external.os_name
    tc_rules_files["SYSTEM"] = ""
    if qos_settings.prioritize_ssh
      tc_rules_files["SYSTEM"] << "tc filter add dev #{dev} parent 1:0 protocol ip prio 10 u32 match ip tos 0x10 0xff match ip dport 22 0xffff flowid 1:10\n"
      tc_rules_files["SYSTEM"] << "tc filter add dev #{dev} parent 1:0 protocol ip prio 10 u32 match ip tos 0x10 0xff match ip sport 22 0xffff flowid 1:10\n"
    end
    if qos_settings.prioritize_ping
      tc_rules_files["SYSTEM"] << "tc filter add dev #{dev} parent 1:0 protocol ip prio 10 u32 match ip protocol 1 0xff flowid 1:10\n"
    end
    if qos_settings.prioritize_ack
      tc_rules_files["SYSTEM"] << "tc filter add dev #{dev} parent 1: protocol ip prio 10 u32 match ip protocol 6 0xff match u8 0x05 0x0f at 0 match u16 0x0000 0xffc0 at 2 match u8 0x10 0xff at 33 flowid 1:10\n"
    end
    if qos_settings.prioritize_dns
      tc_rules_files["SYSTEM"] << "tc filter add dev #{dev} parent 1:0 protocol ip prio 10 u32 match ip dport 53 0xffff flowid 1:10\n"
    end
    #TODO actually write this
    if qos_settings.prioritize_gaming
      tc_rules_files["SYSTEM"] << "tc filter add dev #{dev} parent 1:0 protocol ip prio 10 u32 match ip protocol 1 0xff flowid 1:10\n"
      tc_rules_files["SYSTEM"] << "tc filter add dev #{dev} parent 1:0 protocol ip prio 10 u32 match ip dport 53 0xffff flowid 1:10\n"
      tc_rules_files["SYSTEM"] << "tc filter add dev #{dev} parent 1:0 protocol ip prio 10 u32 match ip dport 6073 0xffff flowid 1:10\n"
#      tc_rules_files["SYSTEM"] << "tc filter add dev #{dev} parent 1:0 protocol ip prio 10 u32 match ip dport 2300-2400 0xffff flowid 1:10\n"
      tc_rules_files["SYSTEM"] << "tc filter add dev #{dev} parent 1:0 protocol ip prio 10 u32 match ip dport 1200 0xffff flowid 1:10\n"
#      tc_rules_files["SYSTEM"] << "tc filter add dev #{dev} parent 1:0 protocol ip prio 10 u32 match ip dport 27000-27015,27030-27039 0xffff flowid 1:10\n"
      tc_rules_files["SYSTEM"] << "tc filter add dev #{dev} parent 1:0 protocol ip prio 10 u32 match ip dport 4000 0xffff flowid 1:10\n"
#      tc_rules_files["SYSTEM"] << "tc filter add dev #{dev} parent 1:0 protocol ip prio 10 u32 match ip dport 6112-6119 0xffff flowid 1:10\n"
      tc_rules_files["SYSTEM"] << "tc filter add dev #{dev} parent 1:0 protocol ip prio 10 u32 match ip dport 7000 0xffff flowid 1:10\n"
#      tc_rules_files["SYSTEM"] << "tc filter add dev #{dev} parent 1:0 protocol ip prio 10 u32 match ip dport 1024-6000 0xffff flowid 1:10\n"
      tc_rules_files["SYSTEM"] << "tc filter add dev #{dev} parent 1:0 protocol ip prio 10 u32 match ip dport 6003 0xffff flowid 1:10\n"
      tc_rules_files["SYSTEM"] << "tc filter add dev #{dev} parent 1:0 protocol ip prio 10 u32 match ip dport 7002 0xffff flowid 1:10\n"
      tc_rules_files["SYSTEM"] << "tc filter add dev #{dev} parent 1:0 protocol ip prio 10 u32 match ip dport 27910 0xffff flowid 1:10\n"
      tc_rules_files["SYSTEM"] << "tc filter add dev #{dev} parent 1:0 protocol ip prio 10 u32 match ip dport 8080 0xffff flowid 1:10\n"
      tc_rules_files["SYSTEM"] << "tc filter add dev #{dev} parent 1:0 protocol ip prio 10 u32 match ip dport 27900 0xffff flowid 1:10\n"
#      tc_rules_files["SYSTEM"] << "tc filter add dev #{dev} parent 1:0 protocol ip prio 10 u32 match ip dport 7777-7783 0xffff flowid 1:10\n"

    end

    qos_rules = QosRules.find( :all )
    qos_rules.each do |qos_rule|
       if qos_rule.enabled
         dev = Interface.external.os_name
         filter_string = ""
         filters = qos_rule.filter.split( "&&" )
         filters.each do |filter|
           type, value = filter.split( "::" )
           if ! value.nil?
             if type == "s-addr"
               address_netmask = value.split( "/" )
               address = address_netmask[0]
               netmask = "0xFFFFFFFF"
               if address_netmask.length == 2
                 netmask = OSLibrary::QosManager::NETMASK32[address_netmask[1]]
               end 
               filter_string << " match ip src #{address} #{netmask} "
             elsif type == "d-addr"
               address_netmask = value.split( "/" )
               address = address_netmask[0]
               netmask = "0xFFFFFFFF"
               if address_netmask.length == 2
                 netmask = OSLibrary::QosManager::NETMASK32[address_netmask[1]]
               end 
               filter_string << " match ip dst #{address} #{netmask} "
             elsif type == "s-port"
               port_mask = value.split( "/" )
               port = port_mask[0]
               mask = "0xFFFF"
               if port_mask.length == 2
                 mask = OSLibrary::QosManager::NETMASK16[port_mask[1]]
               end
               filter_string << " match ip sport #{port} #{mask} "
             elsif type == "d-port"
               port_mask = value.split( "/" )
               port = port_mask[0]
               mask = "0xFFFF"
               if port_mask.length == 2
                 mask = OSLibrary::QosManager::NETMASK16[port_mask[1]]
               end
               filter_string << " match ip dport #{port} #{mask} "
             end
           end
         end
         priority = QosHelper::QosTableModel::PRIORITY[qos_rule.priority]
         if ! filter_string.nil? and filter_string.length > 0
             tc_rules_files[priority] << "tc filter add dev #{dev} parent 1: protocol ip prio #{qos_rule.priority} u32 #{filter_string} flowid 1:#{qos_rule.priority}\n" 
         end
       end
    end
    tc_rules_files.each_pair do |key, file_contents|
      os["override_manager"].write_file( PriorityFiles[key], file_contents, "\n" )
    end
    os["override_manager"].write_file( QoSConfig, settings, "\n" )
  end

  def hook_run_services
    logger.warn "Unable to reconfigure network settings." unless run_command( "#{Service} stop" ) == 0
    logger.warn "Unable to reconfigure network settings." unless run_command( "#{Service} start" ) == 0
  end

  def commit
    write_files
    run_services
  end

  def register_hooks
    os["network_manager"].register_hook( -100, "qos_manager", "write_files", :hook_write_files )
    os["network_manager"].register_hook( 100, "qos_manager", "run_services", :hook_run_services )
  end


end

