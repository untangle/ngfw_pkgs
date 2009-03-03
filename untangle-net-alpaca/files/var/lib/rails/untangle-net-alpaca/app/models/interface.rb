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

class Interface < ActiveRecord::Base
  ## This is the os_name used for the magic no-interface.  This is
  ## a placeholder so the user can remove an interface without losing
  ## their settings for the internal or external interface.
  Unmapped = "nointerface"

  ## Link for a static configuration
  has_one :intf_static, :dependent => :destroy
  
  ## Link for the dynamic/dhcp configuration
  has_one :intf_dynamic, :dependent => :destroy

  ## Link for the bridge configuration.
  has_one :intf_bridge, :dependent => :destroy

  ## Link for the pppoe configuration.
  has_one :intf_pppoe, :dependent => :destroy

  ## Link for all of the interfaces that are bridged with this interface.
  has_many( :bridged_interfaces, :class_name => "IntfBridge", :foreign_key => "bridge_interface_id" )

  def self.wan_interfaces
    conditions = [ "wan = ? AND config_type != ?", true, InterfaceHelper::ConfigType::BRIDGE ]
    self.find( :all, :conditions => conditions )
  end

  def Interface.valid_dhcp_server?
    dhcp_server_settings = DhcpServerSettings.find( :first )
    if dhcp_server_settings.nil? \
      or dhcp_server_settings.enabled == false \
      or dhcp_server_settings.start_address.nil? \
      or dhcp_server_settings.end_address.nil? \
      or dhcp_server_settings.start_address.length == 0 \
      or dhcp_server_settings.end_address.length == 0
      return true
    end

    start_address = IPAddr.parse_ip( dhcp_server_settings.start_address )
    end_address = IPAddr.parse_ip( dhcp_server_settings.end_address )

    return false if ( start_address.nil? || end_address.nil? )

    interfaces = Interface.find( :all )
    ## Iterate each interface and check if there is an ip network that exists containing
    ## the DHCP server addresess.
    interfaces.each do |interface|
      if interface.config_type == InterfaceHelper::ConfigType::STATIC and ! interface.intf_static.nil?
        interface.intf_static.ip_networks.each do |ip_network|
          ip = ip_network.ip
          netmask = ip_network.netmask

          next if ip.nil?
          next if netmask.nil?

          ip_addr = IPAddr.parse( "#{ip}/#{netmask}" )
          next if ip_addr.nil?

          ## If this ip addres is in the range, then return true.
          return true if ip_addr.include?( start_address ) and ip_addr.include?( end_address )
        end
      end
    end
    return false
  end

  ## Return true if this interface is bridged with another interface
  def is_bridge?
    ## If the config is in bridge mode, then just return true if the bridged
    ## interface is non-nil
    return (!intf_bridge.nil? and !intf_bridge.bridge_interface.nil?) if self.config_type == InterfaceHelper::ConfigType::BRIDGE

    ## Check if this is in a configuration that is bridgeable.
    return false unless InterfaceHelper::BRIDGEABLE_CONFIGTYPES.include?( self.config_type )

    bia = self.bridged_interface_array
    ## If there are any entries, then this is a bridge
    ( bia.nil? || bia.empty? ) ? false : true
  end

  
  ## This returns a list of interfaces that are bridged with this interface
  ## and configured in bridge mode.
  def bridged_interface_array
    ## Check if this is in a configuration that is bridgeable.
    return [] unless  InterfaceHelper::BRIDGEABLE_CONFIGTYPES.include?( self.config_type )

    ## bridge interface array (creating a copy)
    bia = [ self.bridged_interfaces ].flatten
    
    bia = [] if bia.nil?
    
    ## Create a new set of bridged interfaces
    bia = bia.map { |ib| ib.nil? ? nil : ib.interface }
    
    ## Delete all of the nil interfaces and the ones where the bridge type isn't set properly.
    bia = bia.delete_if do |i| 
      next true if i.nil? 
      next true unless i.is_mapped?
      next true unless ( i.config_type == InterfaceHelper::ConfigType::BRIDGE )
      false
    end

    ## If this is nil or empty, it is not a bridge.
    bia
  end
  
  ## Get the config type
  def current_config
    case self.config_type
    when InterfaceHelper::ConfigType::STATIC
      return intf_static
    when InterfaceHelper::ConfigType::DYNAMIC
      return intf_dynamic
    when InterfaceHelper::ConfigType::BRIDGE
      return intf_bridge
    when InterfaceHelper::ConfigType::PPPOE
      return intf_pppoe
    end

    ## unknown config type?
    nil
  end

  class ConfigVisitor
    def intf_static( interface, config )
    end

    def intf_dynamic( interface, config )
    end

    def intf_bridge( interface, config )
    end

    def intf_pppoe( interface, config )
    end
  end

  def visit_config( visitor )
    current_config.accept( self, visitor )
  end


  def carrier
    carrier = "Unknown".t
    begin
      f = "/sys/class/net/" + self.os_name + "/carrier"
      sysfs = File.new( f, "r" )
      c = sysfs.readchar
      if c == 49 #ascii for 1
        carrier = "Connected".t
      else
        carrier = "Disconnected".t
      end
    rescue Exception => exception
      logger.error "Error reading carrier status: " + exception.to_s
      carrier = "Unknown".t
    end
    return carrier
  end

  ## REVIEW : This should be inside of the network_manager since it may be os dependent.
  def interface_status
    return `/usr/share/untangle-net-alpaca/scripts/get-interface-status #{self.os_name}`
  end

  def interface_status_v2
    i = `/usr/share/untangle-net-alpaca/scripts/get-interface-status #{self.os_name}`.strip.split( /:? +/ )
    { "name" => i[0], "connected" => i[1], "speed" => i[2], "duplex" => i[3] }
  end

  ## REVIEW : This should be inside of the network_manager since it may be os dependent.
  def current_mtu
    mtu_file = "/sys/class/net/#{self.os_name}/mtu"
    
    mtu = `cat #{mtu_file}` if ( File.exists?( mtu_file ))
    mtu = 1500 if ( mtu.nil? || mtu.empty? )
    return mtu
  end

  ## REVIEW : This should be inside of the network_manager since it may be os dependent.
  def hardware_address
    address = "Unknown".t
    begin
      sysfs = File.new( "/sys/class/net/" + self.os_name + "/address", "r" )
      address = sysfs.readline
    rescue Exception => exception
      address = "Unknown".t
    end
    return address
  end

  ## Returns true if the interface is mapped to an interface.
  def is_mapped?
    return os_name != Unmapped
  end
end
