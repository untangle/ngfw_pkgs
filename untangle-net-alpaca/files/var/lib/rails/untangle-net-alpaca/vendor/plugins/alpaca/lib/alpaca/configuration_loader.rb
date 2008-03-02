#
# $HeadURL: svn://chef/work/pkgs/untangle-net-alpaca/files/var/lib/rails/untangle-net-alpaca/vendor/plugins/alpaca/lib/alpaca/uvm_data_loader.rb $
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
require "logger"

## The ConfigurationLoader loads settings from the current state of
## the box.  This is useful in situations when there are no default
## settings for a box and the user isn't required to go through a
## wizard.
class Alpaca::ConfigurationLoader
  LOG_FILE = '/var/log/untangle-net-alpaca/alpaca-load-configuration.log'
  def initialize
    @logger = Logger.new( LOG_FILE, 10, 1048576 )
  end

  attr_reader :logger

  ## This object is mostly copied from the uvm_data_loader.
  class NetworkSettings
    def initialize( default_route, dns_1, dns_2 )
      @default_route, @dns_1, @dns_2 = default_route, dns_1, dns_2

      @dns_1 = "" if IPAddr.parse_ip( @dns_1 ).nil?
      @dns_2 = "" if IPAddr.parse_ip( @dns_2 ).nil?
    end
    
    def to_s
      "<network-nettings: gw[#{@default_route}] dns1[#{@dns_1}] dns2[#{@dns_2}]>"
    end
    
    attr_reader :default_route, :dns_1, :dns_2
  end

  def load_configuration
    logger.debug( "Loading configuration #{Time.new}" )
    load_network_settings
  end

  private
  def load_network_settings
    ## Load the network settings.
    
    ## Delete all of the interfaces on the box (this really should run from scratch)
    Interface.destroy_all
    
    ## Load all of the interfaces on the box
    interfaces = InterfaceHelper.loadInterfaces
    
    raise ( "No interfaces are available, exiting" ) if interfaces.empty?

    interfaces.each do |interface|
      logger.debug( "Loading the interface: #{interface.os_name}" )
      ## Determine if DHCP is enabled on this interface.
      os_name = interface.os_name
      network_array = `ip addr show #{os_name} | awk '/inet.*scope global/ { print $2 }'`.strip.split
      is_dhcp=`ps aux | grep 'dhc[p].*#{os_name}'`.strip != ""

      ## Convert the strings into ip networks.
      network_array = network_array.map do |network| 
        ip_network = IpNetwork.new
        ip_network.parseNetwork( network )
        ip_network
      end

      network_array.delete_if { |ip_network| ip_network.nil? }
      
      ## The DHCP case is just concerned with the aliases.
      if ( is_dhcp )
        ## The first address is (hopefully) configured by DHCP.
        network_array.delete_at( 0 )
        dynamic = IntfDynamic.new
        dynamic.ip_networks = network_array
        interface.intf_dynamic = dynamic
        interface.config_type = InterfaceHelper::ConfigType::DYNAMIC
        interface.save
        next
      end

      ## Create a new static configuration
      static = IntfStatic.new

      if interface.wan
        ## setup the dns servers and the default gateway.
        static.dns_1, static.dns_2 = get_dns_servers
        static.default_gateway = get_default_gateway
      end

      static.ip_networks = network_array
      interface.intf_static = static
      interface.config_type = InterfaceHelper::ConfigType::STATIC
      interface.save
    end
  end

  def get_dns_servers
    servers = `awk '/nameserver/ { print $2 }' /etc/resolv.conf`.strip.split
    servers = servers.map { |dns_server| IPAddr.parse_ip( dns_server ) }
    servers.delete_if { |dns_server| dns_server.nil? || /127\.0\./.match( dns_server.to_s )}
    servers.map { |dns_server| dns_server.to_s }
  end

  def get_default_gateway
    `ip route show | awk '/^default/ { print $3 }'`
  end

end
