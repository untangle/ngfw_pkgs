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
module NetworkHelper
  ## Helper class to represent all of the information about an interface
  ## configuration
  class InterfaceConfig
    def initialize( interface, static, bridge, bridgeable_interfaces, pppoe )
      @interface, @static, @bridge = interface, static, bridge
      @bridgeable_interfaces = bridgeable_interfaces
      @bridgeable_interfaces_v2 = bridgeable_interfaces.map { |a,b| [b,a] }
      @pppoe = pppoe
    end

    def config_types
      ## Just create a copy (CONFIGTYPES is frozen)
      config_types = InterfaceHelper::CONFIGTYPES.map { |type| type }
      
      if @interface.wan
        config_types = 
          config_types - [ InterfaceHelper::ConfigType::BRIDGE ]
      else
        config_types = 
          config_types - [ InterfaceHelper::ConfigType::DYNAMIC, InterfaceHelper::ConfigType::PPPOE ]
      end

      ## This is what a select expects
      config_types.map { |type| [ type, type ] }
    end
    
    attr_reader :interface, :static, :bridge, :bridgeable_interfaces, :bridgeable_interfaces_v2, :pppoe
  end

  class StaticConfig
    def initialize( ip = "", netmask = 24, default_gateway = "", dns_1 = "", dns_2 = "" )
      @ip, @netmask, @default_gateway, @dns_1, @dns_2 = ip, netmask, default_gateway, dns_1, dns_2
    end

    attr_reader :ip, :netmask, :default_gateway, :dns_1, :dns_2
  end
  
  ## Create an interface config for a particular interface
  ## @param interface The interface to build the config for.
  ## @param interface_list List of interfaces that are configurable
  ## @param dhcp_status Current DHCP Configuration for the this interface.
  def self.build_interface_config( interface, interface_list, dhcp_status )
    s = interface.intf_static
    static = nil

    if (( interface.config_type == InterfaceHelper::ConfigType::DYNAMIC ) && !dhcp_status.nil? )
      netmask = dhcp_status.netmask
      if OSLibrary::NetworkManager::NETMASK_TO_CIDR.key?( dhcp_status.netmask )
         netmask = OSLibrary::NetworkManager::NETMASK_TO_CIDR[ dhcp_status.netmask ]
      end
      
      static = StaticConfig.new( dhcp_status.ip, netmask, dhcp_status.default_gateway, dhcp_status.dns_1, dhcp_status.dns_2 )
    elsif s.nil?
      ## Just use the defaults
      static = StaticConfig.new
    else
      network = s.ip_networks[0]
      ip = ""
      netmask = 24
      ip, netmask = network.ip, network.netmask unless network.nil?
      if interface.wan
        default_gateway = s.default_gateway unless ApplicationHelper.null?( s.default_gateway )
        dns_1 = s.dns_1 unless ApplicationHelper.null?( s.dns_1 )
        dns_2 = s.dns_2 unless ApplicationHelper.null?( s.dns_2 )
      end

      static = StaticConfig.new( ip, netmask, default_gateway, dns_1, dns_2 )
    end

    bridge = interface.intf_bridge
    bridge = bridge.bridge_interface.id unless bridge.nil? || bridge.bridge_interface.nil?

    bridgeable_interfaces = 
      interface_list.map { |i| [ i.name, i.id ] }.delete_if{ |n| n[1] == interface.id }

    pppoe = interface.intf_pppoe
    pppoe = IntfPppoe.new if pppoe.nil?

    pppoe["password"] = ApplicationHelper::PASSWORD_STRING


    ## Return the new interface config.
    InterfaceConfig.new( interface, static, bridge, bridgeable_interfaces, pppoe )
  end
end
