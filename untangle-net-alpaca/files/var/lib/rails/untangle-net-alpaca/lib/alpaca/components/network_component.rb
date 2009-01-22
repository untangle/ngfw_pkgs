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
class Alpaca::Components::NetworkComponent < Alpaca::Component
  def register_menu_items( menu_organizer, config_level )
    if ( config_level == AlpacaSettings::Level::Basic )    
      menu_organizer.register_item( "/main/network", menu_item( 200, "Network", :action => "manage" ))
      
      menu_organizer.register_item( "/extjs/network", menu_item( 200, "Network", :action => "index" ))
    end
  end

  def wizard_insert_stages( builder )
  end

  def pre_prepare_configuration( config, settings_hash )
    interfaces = InterfaceHelper.loadInterfaces
    
    interfaces.each do |i|
      case i.index
      when InterfaceHelper::ExternalIndex
        if ( config["is_dhcp_enabled"] )
          i.intf_dynamic = IntfDynamic.new
          i.config_type = InterfaceHelper::ConfigType::DYNAMIC
        else
          static = IntfStatic.new
          network = IpNetwork.new( :ip => config["ip"], :netmask => config["netmask"], :position => 1 )
          raise "Invalid network #{network.ip} / #{network.netmask}" unless network.valid? 
          static.ip_networks = [ network ]
          static.default_gateway = config["gateway"]
          static.dns_1 = config["dns_1"]
          static.dns_2 = config["dns_2"]
          i.intf_static = static
          i.config_type = InterfaceHelper::ConfigType::STATIC 
        end
        ## Auto installs are presently reserved for single NIC boxes, just disable all other NICs.
        
        raise "Invalid network settings" unless i.valid?
      else
        static = IntfStatic.new
        i.intf_static = static
        i.config_type = InterfaceHelper::ConfigType::STATIC
      end
    end
    
    settings_hash[self.class] = interfaces
  end

  def pre_save_configuration( config, settings_hash )
    IntfStatic.destroy_all
    IntfDynamic.destroy_all
    
    Interface.destroy_all
    settings_hash[self.class].each { |i| i.save }
  end
end
