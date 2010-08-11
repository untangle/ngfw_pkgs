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
class NetworkController < ApplicationController
  UpdateInterfaces = "update_interfaces"

  def get_settings
    ## Cannot use this panel in advanced mode.
    if ( @config_level > AlpacaSettings::Level::Basic )
      return json_error( "Currently in advanced mode." )
    end
    
    interface_list = Interface.find( :all )

    if ( interface_list.nil? || interface_list.empty? )
      interface_list = InterfaceHelper.loadInterfaces
      ## Save all of the new interfaces
      interface_list.each { |interface| interface.save }      
    end
    
    interface_list.sort! { |a,b| a.index <=> b.index }
    
    settings = {}
    settings["config_list"] = interface_list.map do |interface|
      ## This is the dhcp status of this particular interface.
      d = nil

      ## XXXX MULTIWAN (not really this is basic mode) XXXX
      if interface.wan
        d = os["dhcp_manager"].get_dhcp_status( interface )
        settings["dhcp_status"] = d
      end
      
      NetworkHelper.build_interface_config( interface, interface_list, d )
    end

    json_result( :values => settings )
  end

  def set_settings
    s = json_params

    ## Retrieve all of the interfaces
    config_list = s["config_list"]
    
    ## Verify the list lines up with the existing interfaces
    interfaces = Interface.find( :all )

    ## Verify the list matches.
    if ( interfaces.size != config_list.size )
      return json_error( "Number of submitted interfaces does not match number of configured interfaces." )
    end

    interface_map = {}
    interfaces = interfaces.each{ |interface| interface_map[interface.id] = interface }
    
    ## Verify every id is represented
    config_list.each do |config|
      if interface_map[config["interface"]["id"]].nil?
          return json_error( "Submitted request does not configure every known interface." )
      end

      unless InterfaceHelper::CONFIGTYPES.include?( config["interface"]["config_type"] )
        return json_error( "Invalid configuration type #{config["interface"]["config_type"]}" )
      end
    end

    ## This is where it gets a little hairy, because it should verify all
    ## interfaces, and then save, for now it is saving interfaces as it goes.
    config_list.each do |config|
      interface_config = config["interface"]
      interface = interface_map[interface_config["id"]]
      case interface_config["config_type"]
      when InterfaceHelper::ConfigType::STATIC then static_v2( interface, config )
      when InterfaceHelper::ConfigType::DYNAMIC then dynamic_v2( interface, config )
      when InterfaceHelper::ConfigType::BRIDGE then bridge_v2( interface, config )
      when InterfaceHelper::ConfigType::PPPOE then pppoe_v2( interface, config )
        ## This is redundant
      else return json_error( "Unknown configuration type #{config_type}" )
      end      
    end

    spawn do
      os["network_manager"].commit
    end
    
    json_result
  end
  
  def index
    if ( @config_level > AlpacaSettings::Level::Basic )
      return redirect_to( :controller => 'interface', :action => 'list' )
    end

    extjs
  end
  
  def get_aliases
    ## Index is a reserved word, so the column name must be quoted.
    conditions = [ "\"index\" = ?", InterfaceHelper::ExternalIndex ]
    external_interface = Interface.find( :first, :conditions => conditions )
    
    if external_interface
      external_aliases, msg = external_interface.visit_config( AliasVisitor.new )
      unless msg.nil?
        return json_error( msg )
      end
    else 
      return json_error( "There presently isn't an external interface." )
    end

    external_aliases = [] if external_aliases.nil?
    external_aliases = external_aliases.map { |ea| { "network_string" => "#{ea.ip} / #{ea.netmask}" }}
    
    json_result( :values => { "external_aliases" => external_aliases })
  end

  def set_aliases
    s = json_params

    ## Index is a reserved word, so the column name must be quoted.
    conditions = [ "\"index\" = ?", InterfaceHelper::ExternalIndex ]
    external_interface = Interface.find( :first, :conditions => conditions )

    if external_interface.nil?
      return json_error( "Unable to find external interface." )
    end

    current_config = external_interface.current_config
    
    static = external_interface.intf_static
    if static.nil?
      static = IntfStatic.new 
      external_interface.intf_static = static
    end      
    
    dynamic = external_interface.intf_dynamic
    if dynamic.nil?
      dynamic = IntfDynamic.new 
      external_interface.intf_dynamic = dynamic
    end
    
    pppoe = external_interface.intf_pppoe
    if pppoe.nil?
      pppoe = IntfPppoe.new 
      external_interface.intf_pppoe = pppoe
    end
    
    aliasVisitor = SaveAliasesVisitor.new( s["external_aliases"] )
    [ static, dynamic, pppoe ].each do |config|
      msg = config.accept( external_interface, aliasVisitor )
      if ( current_config == config and !msg.nil? )
        return json_error( msg )
      end
      config.save
    end

    external_interface.save

    spawn do
      os["network_manager"].commit
    end
    
    json_result
  end

  alias_method :aliases, :extjs

  alias_method :troubleshoot, :extjs

  def get_troubleshoot_settings
    settings = {}

    ## Interface enumeration
    settings["interface_enum"] = build_interface_enum()

    json_result( :values => settings )
  end
  
  def get_general_settings
    settings = {}

    alpaca_settings = AlpacaSettings.find( :first )
    alpaca_settings = AlpacaSettings.new if alpaca_settings.nil?
    modules_disabled = alpaca_settings.modules_disabled
    modules_disabled = "" if modules_disabled.nil?
    settings["enable_sip_helper"] = !modules_disabled.include?( "nf_nat_sip" )
    settings["send_icmp_redirects"] = alpaca_settings.send_icmp_redirects

    settings["classy_nat_mode"] = alpaca_settings.classy_nat_mode

    uvm_settings = UvmSettings.find( :first )
    uvm_settings = UvmSettings.new if uvm_settings.nil?
    settings["uvm"] = uvm_settings

    json_result( :values => settings )
  end

  def set_general_settings
    s = json_params

    alpaca_settings = AlpacaSettings.find( :first )
    alpaca_settings = AlpacaSettings.new( :send_icmp_redirects => true ) if @alpaca_settings.nil? 
    alpaca_settings.send_icmp_redirects = s["send_icmp_redirects"]
    alpaca_settings.classy_nat_mode = s["classy_nat_mode"]
    
    modules_disabled = alpaca_settings.modules_disabled
    modules_disabled = "" if modules_disabled.nil?
    modules_disabled = modules_disabled.gsub( "nf_nat_sip", "" )
    modules_disabled = modules_disabled.gsub( "nf_conntrack_sip", "" )
    unless ( s["enable_sip_helper"] )
      modules_disabled += " nf_nat_sip nf_conntrack_sip "
    end
    alpaca_settings.modules_disabled = modules_disabled.strip
    alpaca_settings.save

    uvm_settings = UvmSettings.find( :first )
    uvm_settings = UvmSettings.new if uvm_settings.nil?
    uvm_settings.update_attributes( s["uvm"] )
    uvm_settings.save

    spawn do
      os["network_manager"].commit
    end
    
    json_result
  end

  alias_method :general, :extjs

  def start_ping_test
    s = json_params

    destination = s["destination"]
    count = s["count"]
    count = 5 if count.nil?
    count = count.to_i
    count = 5 if ( count < 1 or count > 200 )

    raise "Missing Destination" if destination.nil?
    destination = destination.strip
    raise "Invalid Destination" unless ApplicationHelper.safe_characters?( destination )
    
    session_id = get_user_command_session_id

    result = {}
    result["key"] = os["network_manager"].start_user_command( session_id, "ping -c #{count} #{destination}" )

    json_result( :values => result )
  end

  def start_connectivity_test
    s = json_params
    
    session_id = get_user_command_session_id
    result = {}
    result["key"] = os["network_manager"].start_user_command( session_id, <<EOF )
echo -n "Testing DNS ... "
success="Successful"
dig updates.untangle.com > /dev/null 2>&1 
if [ "$?" = "0" ]; then
  echo "OK"
else
  echo "FAILED"
  success="Failure"
fi

echo -n "Testing TCP Connectivity ... "
echo "GET /" | netcat -q 0 -w 15 updates.untangle.com 80 > /dev/null 2>&1
if [ "$?" = "0" ]; then
  echo "OK"
else
  echo "FAILED"
  success="Failure"
fi

echo "`date` - Test ${success}!"

EOF

    json_result( :values => result )
  end

  def start_dns_test
    s = json_params

    hostname = s["hostname"]
    
    raise "Missing hostname" if hostname.nil?
    hostname = hostname.strip
    raise "Invalid hostname" unless ApplicationHelper.safe_characters?( hostname )
    
    session_id = get_user_command_session_id
    result = {}
    result["key"] = os["network_manager"].start_user_command( session_id, <<EOF )
success="Successful"

host #{hostname}
if [ "$?" != "0" ]; then
  success="Failure"
fi

echo "`date` - Test ${success}!"

EOF

    json_result( :values => result )
  end

  def start_tcp_test
    s = json_params

    destination = s["destination"]
    port = s["port"]

    
    raise "Missing destination" if destination.nil?
    raise "Missing port" if port.nil?
    destination = destination.strip
    raise "Invalid destination" unless ApplicationHelper.safe_characters?( destination )

    raise "invalid port" unless port.to_i.to_s == port.to_s
    port = port.to_i
    raise "invalid port" if ( port <= 0 || port > 0xFFFF )
    
    session_id = get_user_command_session_id
    result = {}
    result["key"] = os["network_manager"].start_user_command( session_id, <<EOF )
success="Successful"

echo 1 | netcat -q 0 -v -w 15 #{destination} #{port}
if [ "$?" != "0" ]; then
  success="Failure"
fi

echo "`date` - Test ${success}!"

EOF

    json_result( :values => result )
  end

  def start_traceroute_test
    s = json_params

    destination = s["destination"]
    
    raise "Missing destination" if destination.nil?
    destination = destination.strip
    raise "Invalid destination" unless ApplicationHelper.safe_characters?( destination )
    
    session_id = get_user_command_session_id
    result = {}
    result["key"] = os["network_manager"].start_user_command( session_id, <<EOF )
traceroute #{destination}
if [ "$?" != "0" ]; then
  success="Failure"
fi

echo "`date` - Test Complete!"

EOF

    json_result( :values => result )
  end

  def start_packet_test
    s = json_params

    destination = s["destination"]
    port = s["port"]
    timeout = s["timeout"]
    intf = s["interface"]
        
    
    if ( destination.nil? or destination == "" or destination.downcase == "any" )
      destination = ""
    else
      destination = destination.strip
      raise "Invalid destination" unless ApplicationHelper.safe_characters?( destination )
      destination = "host #{destination}"
    end

    if ( port.nil? or port == "" )
      port = ""
    else
      raise "invalid port" unless port.to_i.to_s == port.to_s
      port = port.to_i
      raise "invalid port" if ( port <= 0 || port > 0xFFFF )
      port = "port #{port}"
    end

    raise "Invalid timeout" unless ( timeout.to_i.to_s == timeout.to_s )
    timeout = timeout.to_i
    raise "Invalid timeout" unless ( timeout > 2 and timeout < 121 )

    ## Get the interface
    if ( intf == 8 )
      intf = "tun0"
    else
      conditions = [ "\"index\" = ?", intf ]
      intf = Interface.find( :first, :conditions => conditions )
      raise "Invalid Interface" if intf.nil?
      intf = intf.os_name
    end
    
    if ( destination != "" and port != "" )
      port = " and #{port}"
    end
    
    session_id = get_user_command_session_id
    result = {}
    result["key"] = os["network_manager"].start_user_command( session_id, <<EOF )
intf_name=#{intf}
pppoe_name=`/usr/share/untangle-net-alpaca/scripts/get_pppoe_name ${intf_name}`

if [ "${pppoe_name}" != "ppp.${intf_name}" ]; then
  intf_name=${pppoe_name}
fi

tcpdump -i ${intf_name} -l -q -c 1024 -n #{destination} #{port} 2>&1 &
for t in `seq 1 #{timeout}`; do
  sleep 1
  ps aux | grep -q " $! .*[t]cpdump -i"
  if [ "$?" != "0" ]; then
    break
  fi
done
ps aux | grep -q " $! .*[t]cpdump -i" && kill -INT $!
ps aux | grep -q " $! .*[t]cpdump -i" && wait $!

echo "`date` - Test Complete!"

EOF

    json_result( :values => result )
  end

  def commit
    spawn do
      os["network_manager"].commit
    end
    return redirect_to( :action => 'manage' )
  end

  def create_ip_network
    @list_id = params[:list_id]
    raise "no row id" if @list_id.nil?
    raise "invalid list id  #{@list_id} syntax" if @list_id != "external-aliases"

    ## Review : How to set defaults
    @ip_network = IpNetwork.new
    @ip_network.ip = "1.2.3.4"
    @ip_network.netmask = "24"
    @ip_network.allow_ping = true
  end

  private

  class AliasVisitor < Interface::ConfigVisitor
    def intf_static( interface, config )
      ## Create a copy of the array.
      aliases = [ config.ip_networks ].flatten

      ## Delete the alias at the first position from the list
      aliases.delete_if { |a| a.position == 1 }
      [ aliases, nil ]
    end

    def intf_dynamic( interface, config )
      [ config.ip_networks, nil ]
    end

    def intf_bridge( interface, config )
      [ [], "External Interface is presently configured as a bridge" ]
    end

    def intf_pppoe( interface, config )
      ## Review : We currently support this.
      [ config.ip_networks, nil ]
    end
  end

  class SaveAliasesVisitor < Interface::ConfigVisitor
    def initialize( external_aliases )
      @external_aliases = external_aliases
    end

    def intf_static( interface, config )
      ## Create the ip_network list, starting with position 2
      ip_networks = ip_network_list( 2 )
      external = config.ip_networks[0]
      if external.nil?
        config.ip_networks = ip_networks
      else
        ## Put it at the beginning
        config.ip_networks = [ external ] + ip_networks 
      end
      
      nil
    end

    def intf_dynamic( interface, config )
      config.ip_networks = ip_network_list( 1 )

      nil
    end

    def intf_bridge( interface, config )
      "External Interface is presently configured as a bridge"
    end

    def intf_pppoe( interface, config )
      config.ip_networks = ip_network_list( 1 )
      nil
    end

    private
    def ip_network_list( position )
      @external_aliases.map do |ea|
          network = IpNetwork.new
          network.parseNetwork( ea["network_string"] )
          network.position, position = position, position + 1
          network
      end
    end
  end

  def static_v2( interface, config )
    static = interface.intf_static
    static = IntfStatic.new if static.nil?

    static_config = config["static"]
    
    network = static.ip_networks[0]

    ## There isn't a first one, need to create a new one
    if network.nil?
      network = IpNetwork.new( :allow_ping => true, :position => 1 )
      network.parseNetwork( "#{static_config["ip"]}/#{static_config["netmask"]}" )
      static.ip_networks = [ network ]
    elsif ( network.position == 1 )
      ## Replace the one that is there
      network.ip = static_config["ip"]
      network.netmask = static_config["netmask"]
      network.allow_ping = true
      network.save
    else
      ## The first one doesn't exist, need to insert one at the beginning
      network = IpNetwork.new( :allow_ping => true, :position => 1 )
      network.parseNetwork( "#{static_config["ip"]}/#{static_config["netmask"]}" )
      static.ip_networks << network
    end
    
    if interface.wan
      ## Set the default gateway and dns
      static.default_gateway = static_config["default_gateway"]
      static.dns_1 = static_config["dns_1"]
      static.dns_2 = static_config["dns_2"]
    else
      ## Add a NAT policy (this not the external interface)
      natPolicy = NatPolicy.new
      natPolicy.ip = "0.0.0.0"
      natPolicy.netmask = "0"
      natPolicy.new_source = "auto"
      static.nat_policies = [ natPolicy ]
    end

    static.save
    interface.config_type = InterfaceHelper::ConfigType::STATIC
    interface.intf_static = static
    interface.save
  end

  def bridge_v2( interface, config )
    bridge = interface.intf_bridge
    bridge = IntfBridge.new if bridge.nil?

    bridge_id = config["bridge"]
    return logger.warn( "Bridge interface is not specified" ) if bridge_id.nil?

    bridge_interface = Interface.find( :first, :conditions => [ "id = ?", bridge_id ] )
    return logger.warn( "Unable to find the interface '#{bridge_id}'" ) if bridge_interface.nil?

    bridge.bridge_interface = bridge_interface
    bridge_interface.bridged_interfaces << bridge
    
    interface.intf_bridge = bridge
    interface.config_type = InterfaceHelper::ConfigType::BRIDGE
    interface.save
  end

  def dynamic_v2( interface, config )
    dynamic = interface.intf_dynamic
    dynamic = IntfDynamic.new if dynamic.nil?
    dynamic.allow_ping = true

    dynamic.ip = nil
    dynamic.netmask = nil
    dynamic.default_gateway = nil
    dynamic.dns_1 = nil
    dynamic.dns_2 = nil

    dynamic.save
    interface.config_type = InterfaceHelper::ConfigType::DYNAMIC
    interface.intf_dynamic = dynamic
    interface.save    
  end

  def pppoe_v2( interface, config )
    pppoe_config = config["pppoe"]

    pppoe = interface.intf_pppoe
    pppoe = IntfPppoe.new if pppoe.nil?
    pppoe.username = pppoe_config["username"]
    if ( pppoe_config["password"] != ApplicationHelper::PASSWORD_STRING )
      pppoe.password = pppoe_config["password"]
    end
    pppoe.use_peer_dns = pppoe_config["use_peer_dns"]
    pppoe.dns_1 = pppoe_config["dns_1"]
    pppoe.dns_2 = pppoe_config["dns_2"]
    pppoe.save

    interface.config_type = InterfaceHelper::ConfigType::PPPOE
    interface.intf_pppoe = pppoe
    interface.save
  end
end
