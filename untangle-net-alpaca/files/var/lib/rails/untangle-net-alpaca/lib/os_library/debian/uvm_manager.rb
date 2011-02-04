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
class OSLibrary::Debian::UvmManager < OSLibrary::UvmManager
  ## Review : Many if not all of the generated iptables scripts contain zero variables,
  ## and don't actually need to be generated on the fly.

  include Singleton

  IPTablesCommand = OSLibrary::Debian::PacketFilterManager::IPTablesCommand
  
  Chain = OSLibrary::Debian::PacketFilterManager::Chain

  ## uvm subscription file
  UvmSubscriptionFile = "#{OSLibrary::Debian::PacketFilterManager::ConfigDirectory}/800-uvm"

  ## list of rules for the UVM (before the firewall (those rules should override these rules)).
  UvmServicesFile = "#{OSLibrary::Debian::PacketFilterManager::ConfigDirectory}/475-uvm-services"

  ## list of rules for the UVM (after the firewall (used when the user wants to override these rules)).
  UvmServicesPostFile = "#{OSLibrary::Debian::PacketFilterManager::ConfigDirectory}/675-uvm-services"

  ## list of rules for openvpn
  UvmOpenVPNFile = "#{OSLibrary::Debian::PacketFilterManager::ConfigDirectory}/475-openvpn-pf"

  ## file to write out the network config
  UvmNetworkConfigFile = "/etc/untangle-net-alpaca/netConfig.js"
  
  ## Function that contains all of the subscription / bypass rules
  BypassRules = "bypass_rules"

  ## Script to tell the UVM that the configuration has changed.
  UvmUpdateConfiguration = "/usr/share/untangle-net-alpaca/scripts/uvm/update-configuration"

  def register_hooks
    os["packet_filter_manager"].register_hook( 100, "uvm_manager", "write_files", :hook_write_files )
    os["network_manager"].register_hook( 100, "uvm_manager", "write_files", :hook_write_files )

    ## Register with the hostname manager to update when there are
    ## changes to the hostname
    os["hostname_manager"].register_hook( 1000, "uvm_manager", "commit", :hook_update_configuration )
    os["dns_server_manager"].register_hook( 1000, "uvm_manager", "commit", :hook_update_configuration )
  end

  ## Write out the files to load all of the iptables rules necessary to queue traffic.
  def hook_write_files
    ## These are all of the rules that are used to vector traffic to the UVM.
    write_subscription_script
    wan_mask = write_network_configuration_file

    ## These are all of the rules to filter / accept traffic to the various services
    ## the UVM provides (80, 443, etc)
    write_packet_filter_script( wan_mask )
    write_openvpn_script
  end

  ## A helper function for the packet filter manager.
  def handle_custom_rule( rule )
    return nil
  end

  ## Tell the UVM that there has been a change in the alpaca settings.  This is only used when something
  ## Changes but doesn't call the network manager.
  def hook_update_configuration
    run_command( UvmUpdateConfiguration )
  end

  def UID()
    key = "0000-0000-0000-0000"
    begin
        file = File.new("/usr/share/untangle/conf/uid", "r")
        key = file.gets
        key.strip!
    rescue => err
    end
    return key 
  end
  
  private
  
  def write_subscription_script
    text = header
    
    text += subscription_rules
    
    text += <<EOF
HELPER_SCRIPT="/usr/share/untangle-net-alpaca/scripts/uvm/iptables"

if [ ! -f ${HELPER_SCRIPT} ]; then
  echo "[`date`] The script ${HELPER_SCRIPT} is not available"
  return 0
fi

. ${HELPER_SCRIPT}

if [ "`is_uvm_running`x" = "truex" ]; then
  echo "[`date`] The UVM running, inserting queueing hooks"
  uvm_iptables_rules
  
  ## Ignore any traffic that is on the utun interface
  #{IPTablesCommand} -t #{Chain::FirewallRules.table} -I #{Chain::FirewallRules} 1 -i ${TUN_DEV} -j RETURN
  
  #{BypassRules}
else
  echo "[`date`] The UVM is currently not running"
fi

return 0

EOF

    os["override_manager"].write_file( UvmSubscriptionFile, text, "\n" )    
  end

  def write_packet_filter_script( wan_mask )
    text = header
    
    text += <<EOF
HELPER_SCRIPT="/usr/share/untangle-net-alpaca/scripts/uvm/iptables"

if [ ! -f ${HELPER_SCRIPT} ]; then
  echo "[`date`] The script ${HELPER_SCRIPT} is not available"
  return 0
fi

MASK_WAN=#{wan_mask}
MASK_NON_WAN=#{wan_mask ^ 0xFF}

. ${HELPER_SCRIPT}

if [ "`is_uvm_running`x" = "truex" ]; then
  echo "[`date`] The UVM running, service rules."
  uvm_packet_filter_standard_internal
  uvm_packet_filter_secure_internal
  uvm_packet_filter_secure_external
  uvm_packet_filter_secure_public
else
  echo "[`date`] The UVM is currently not running"
fi

## Should this be here?  Use type to protect older boxes.
type uvm_shield_traffic > /dev/null 2>&1 && {
    uvm_shield_traffic
} || {
    echo "[`date`] uvm_shield_traffic is not defined."
}

return 0
EOF

    uvm_settings = UvmSettings.find( :first )
    ## Default to evaluating the rules before the redirects.
    if ( uvm_settings.nil? || uvm_settings.override_redirects )
      os["override_manager"].write_file( UvmServicesFile, text, "\n" )    
      os["override_manager"].write_file( UvmServicesPostFile, header, "\n" )
    else
      os["override_manager"].write_file( UvmServicesFile, header, "\n" )    
      os["override_manager"].write_file( UvmServicesPostFile, text, "\n" )      
    end
  end

  def write_openvpn_script
    accept_vpn_client = ""

    route_bridge_vpn_traffic = ""

    if Firewall.find( :first, :conditions => [ "system_id = ? and enabled='t'", "accept-client-vpn-8a762ae9" ] )
      accept_vpn_client = "true"
    end

    if Firewall.find( :first, :conditions => [ "system_id = ? and enabled='t'", "route-bridge-vpn-37ce4160" ] )
      route_bridge_vpn_traffic = "true"
    end

    
    text = header
    ## REVIEW This presently doesn't mark openvpn traffic as local.
    ## REVIEW 0x80 is a magic number.
    text  += <<EOF
HELPER_SCRIPT="/usr/share/untangle-net-alpaca/scripts/uvm/iptables"

if [ ! -f ${HELPER_SCRIPT} ]; then
  echo "[`date`] The script ${HELPER_SCRIPT} is not available"
  return 0
fi

. ${HELPER_SCRIPT}

if [ "`is_uvm_running`x" != "truex" ]; then 
  echo "[`date`] The UVM running, not inserting rules for openvpn"
  return 0
fi

if [ "`pidof openvpn`x" = "x" ]; then
  echo "[`date`] OpenVPN is not running, not inserting rules for openvpn"
  return 0
fi    

## This is the mark rule
#{IPTablesCommand} #{Chain::MarkInterface.args} -i tun0 -j MARK --or-mark #{0x80}

## Function designed to insert the necessary filter rule to pass traffic from a
## a VPN interface.
insert_vpn_export()
{
  local t_network=$1
  local t_netmask=$2

  #{IPTablesCommand} #{Chain::FirewallRules.args} -i tun0 -d ${t_network}/${t_netmask} -j RETURN
}

## Now insert all exports
EXPORTS_FILE=`uvm_home`/conf/openvpn/packet-filter-rules

if [ -f ${EXPORTS_FILE} ]; then 
  . ${EXPORTS_FILE}
  ## At the end block everything else
  #{IPTablesCommand} #{Chain::FirewallRules.args} -i tun0 -j DROP
fi

## If it is a client, insert the pass rule.
if [ -n "#{accept_vpn_client}" ] && [ ! -f /etc/openvpn/server.conf ] ; then
  #{IPTablesCommand} #{Chain::FirewallRules.args} -i tun0 -j RETURN
fi

if [ -n "#{route_bridge_vpn_traffic}" ]; then
  uvm_openvpn_ebtables_rules || true
fi

true

EOF

    os["override_manager"].write_file( UvmOpenVPNFile, text, "\n" )
  end

  ## This writes a file that indicates to the UVM the order
  ## of the interfaces
  def write_network_configuration_file
    ## Create an interface map
    interfaces = {}
    Interface.find( :all ).each { |interface| interfaces[interface.index] = interface }
    
    settings = UvmSettings.find( :first )
    settings = UvmSettings.new if settings.nil?
    
    intf_order = settings.interface_order
    intf_order = UvmHelper::DefaultOrder if ApplicationHelper.null?( intf_order )
    intf_order = intf_order.split( "," ).map { |idx| idx.to_i }.delete_if { |idx| idx == 0 }
    wan_interfaces = []

    ## Go through and delete the interfaces that are in the map.
    intf_order.each do |idx|
      interface = interfaces[idx]
      next if interface.nil?
      
      ## Delete the item at index for the second loop
      interfaces.delete( idx )
      
      ## Append the index
      wan_interfaces << idx if ( interface.wan == true )
    end

    hostname_settings = HostnameSettings.find( :first )
    dns_settings = DnsServerSettings.find( :first )
    dhcp_settings = DhcpServerSettings.find( :first )

    netConfigFileText = ""
    netConfigFileText += "{\n"
    netConfigFileText += "    javaClass: \"com.untangle.uvm.networking.NetworkConfiguration\",\n"
    if !hostname_settings.nil?
      netConfigFileText += "    hostname: \"#{hostname_settings.hostname}\",\n" 
    end
    if dns_settings.nil?
      netConfigFileText += "    dnsServerEnabled: false,\n" 
    else
      netConfigFileText += "    dnsServerEnabled: #{dns_settings.enabled},\n" 
      netConfigFileText += "    dnsLocalDomain: \"#{dns_settings.suffix}\",\n" 
    end
    if dhcp_settings.nil?
      netConfigFileText += "    dhcpServerEnabled: false,\n" 
    else
      netConfigFileText += "    dhcpServerEnabled: #{dhcp_settings.enabled},\n" 
    end

    netConfigFileText += "    interfaceList: {\n" 
    netConfigFileText += "        javaClass: \"java.util.LinkedList\",\n" 
    netConfigFileText += "        list: [\n"

    first = true
    Interface.find( :all ).each { |interface| 
      if (first) 
        netConfigFileText += "               {\n"
        first = false
      else
        netConfigFileText += "              ,{\n"
      end
      netConfigFileText += "            javaClass: \"com.untangle.uvm.networking.InterfaceConfiguration\",\n" 
      netConfigFileText += "            interfaceId: #{interface.index},\n"
      netConfigFileText += "            systemName: \"#{interface.os_name}\",\n"
      netConfigFileText += "            name: \"#{interface.name}\",\n" 
      netConfigFileText += "            configType: \"#{interface.config_type}\",\n" 

      netConfigFileText += "            WAN: #{interface.wan},\n" 

      if (interface.config_type == "static")
        intfStatic = IntfStatic.find( :first, :conditions => [ "interface_id = ?", interface.id ] )

        if !intfStatic.ip_networks.nil? and !intfStatic.ip_networks[0].nil?
          netConfigFileText += "            primaryAddressStr: \"#{intfStatic.ip_networks[0].ip}/#{intfStatic.ip_networks[0].netmask}\",\n" 
        end

        if (interface.wan) 
          netConfigFileText += "            gatewayStr: \"#{intfStatic.default_gateway}\",\n" if !intfStatic.default_gateway.nil?
          netConfigFileText += "            dns1Str: \"#{intfStatic.dns_1}\",\n" if !intfStatic.dns_1.nil?
          netConfigFileText += "            dns2Str: \"#{intfStatic.dns_2}\",\n" if !intfStatic.dns_2.nil?
          netConfigFileText += "            mtu: #{intfStatic.mtu},\n" if !intfStatic.mtu.nil?
        end
      end

      if (interface.config_type == "dynamic")
        intfDynamic = IntfDynamic.find( :first, :conditions => [ "interface_id = ?", interface.id ] )

        dhcp_status = os["dhcp_manager"].get_dhcp_status( interface )
        if !dhcp_status.nil?
          netConfigFileText += "            primaryAddressString: \"#{dhcp_status.ip}/#{dhcp_status.netmask}\",\n" if !dhcp_status.nil?
        end

        netConfigFileText += "            overrideIPAddress: \"#{intfDynamic.ip}\",\n" if !intfDynamic.netmask.nil?
        netConfigFileText += "            overrideNetmask: \"#{intfDynamic.netmask}\",\n" if !intfDynamic.netmask.nil?

        if (interface.wan) 
          netConfigFileText += "            overrideGateway: \"#{intfDynamic.default_gateway}\",\n" if !intfDynamic.default_gateway.nil?
          netConfigFileText += "            overrideDns1: \"#{intfDynamic.dns_1}\",\n" if !intfDynamic.dns_1.nil?
          netConfigFileText += "            overrideDns2: \"#{intfDynamic.dns_2}\",\n" if !intfDynamic.dns_2.nil?
        end
      end

      if (interface.config_type == "bridge")
        intfBridge = IntfBridge.find( :first, :conditions => [ "interface_id = ?", interface.id ] )
        bridgedToIntf = Interface.find( :first, :conditions => [ "id = ?", intfBridge.bridge_interface_id ] )
        netConfigFileText += "            bridgedTo: \"#{bridgedToIntf.name}\",\n" if !bridgedToIntf.name.nil?
      end

      if (interface.config_type == "pppoe")
        #pppoe username
        #pppoe password
      end

      netConfigFileText += "        }\n"
    }

    # manually add the VPN interface
    netConfigFileText += "              ,{\n"
    netConfigFileText += "            javaClass: \"com.untangle.uvm.networking.InterfaceConfiguration\",\n" 
    netConfigFileText += "            interfaceId: #{UvmHelper::OpenVpnIndex},\n"
    netConfigFileText += "            systemName: \"tun0\",\n"
    netConfigFileText += "            name: \"OpenVPN\",\n" 
    netConfigFileText += "            WAN: false,\n" 
    netConfigFileText += "        }\n"


    netConfigFileText += "         ]\n" 
    netConfigFileText += "    }\n" 
    netConfigFileText += "}\n" 
    netConfigFileText += "\n" 

    os["override_manager"].write_file( UvmNetworkConfigFile, netConfigFileText )

    wan_mask=0
    wan_interfaces.each { |idx| wan_mask |= 1 << ( idx - 1 ) }
    return wan_mask
  end

  def subscription_rules
    text = <<EOF
#{BypassRules}() {
  local t_rule
EOF

    ## Add the user rules
    rules = Subscription.find( :all, :conditions => [ "system_id IS NULL AND enabled='t'" ] )
    ## Add the system rules
    rules += Subscription.find( :all, :conditions => [ "system_id IS NOT NULL AND enabled='t'" ] )
    
    rules.each do |rule|
      begin
        next text << handle_custom_rule( rule ) if rule.is_custom

        filters, chain = OSLibrary::Debian::Filter::Factory.instance.filter( rule.filter )
        
        target = ( rule.subscribe ) ? "-j RETURN" : "-g #{Chain::BypassMark}"

        filters.each do |filter|
          break if filter.strip.empty?
          text << "#{IPTablesCommand} #{Chain::BypassRules.args} #{filter} #{target}\n"
        end
        
      rescue
        logger.warn( "The filter '#{rule.id}' '#{rule.filter}' could not be parsed: #{$!}" )
      end
    end
    
    text + "\n}\n"
  end

  ## Review: This should be a global function
  def header
    <<EOF
#!/bin/dash

## #{Time.new}
## Auto Generated by the Untangle Net Alpaca
## If you modify this file manually, your changes
## may be overriden

EOF
  end

end
