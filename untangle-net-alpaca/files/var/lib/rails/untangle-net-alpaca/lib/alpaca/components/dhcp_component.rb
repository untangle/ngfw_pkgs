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
class Alpaca::Components::DhcpComponent < Alpaca::Component
  def register_menu_items( menu_organizer, config_level )
    menu_organizer.register_item( "/main/dhcp_server",
                                  menu_item( 400, "DHCP Server", :action => "manage" ))
    menu_organizer.register_item( "/main/dhcp_server/entries",
                                  menu_item( 1, "Static Entries", :action => "manage_entries" ))
  end

  def wizard_insert_closers( builder )
    builder.insert_piece( Alpaca::Wizard::Closer.new( 1200 ) { save } )
  end

  private
  def save
    ## Iterate all of the interfaces
    ## At this port the interfaces exist in the database.
    ## Review : internationalization, flimsy key.
    interface = Interface.find( :first, :conditions => [ "name = ?", "Internal" ] )

    ## Create a new set of settings
    dhcp_server_settings = DhcpServerSettings.new
    
    internal_network = nil
    config = interface.current_config unless interface.nil?

    case config 
    when IntfStatic then internal_network = config.ip_networks[0]
    when IntfDynamic then internal_network = nil
    when IntfBridge
      ## Get the configuration of the interface it is bridged with.
      config = config.interface.current_config
      internal_network = config.ip_networks[0] if config.is_a? IntfStatic
    end

    unless internal_network.nil?
      ip = IPAddr.parse_ip( internal_network.ip )
      netmask = IPAddr.parse_netmask( internal_network.netmask )
    end
    
    dhcp_server_settings.enabled = false
    dhcp_server_settings.lease_duration = 0
    dhcp_server_settings.gateway = nil
    dhcp_server_settings.netmask = nil
    
    ## This will only configure /24 or larger network, the logic for
    ## smaller networks is complicated and isn't really worth it.
    unless ( ip.nil? || netmask.nil? )
      start_address, end_address = nil, nil
      if (( netmask & IPAddr.parse( "0.0.0.255" )) == IPAddr.parse( "0.0.0.0" ))
        ## /24 or larger network
        mask = ip & netmask
        if (( mask | IPAddr.parse( "0.0.0.100" )).to_i > ip.to_i )
          start_address = mask | IPAddr.parse( "0.0.0.100" )
          end_address = mask | IPAddr.parse( "0.0.0.200" )
        else
          start_address = mask | IPAddr.parse( "0.0.0.16" )
          end_address = mask | IPAddr.parse( "0.0.0.99" )
        end
      end
            
      unless ( start_address.nil? || end_address.nil? )
        dhcp_server_settings.enabled = true
        dhcp_server_settings.start_address = start_address.to_s
        dhcp_server_settings.end_address = end_address.to_s
      end
    end

    ## Review : Perhaps this should do something less harsh
    DhcpStaticEntry.destroy_all

    DhcpServerSettings.destroy_all
    dhcp_server_settings.save
  end
end
  
