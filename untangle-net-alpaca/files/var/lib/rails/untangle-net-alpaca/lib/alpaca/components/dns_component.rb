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
class Alpaca::Components::DnsComponent < Alpaca::Component
  def register_menu_items( menu_organizer, config_level )
    menu_organizer.register_item( "/main/dns_server", menu_item( 500, "DNS Server", :action => "manage" ))

    if ( config_level >= AlpacaSettings::Level::Advanced ) 
      menu_organizer.register_item( "/main/advanced/dns_upstream_servers", menu_item( 600, "Upstream DNS", :action => "upstream_servers" ))
    end
  end
  
  def wizard_insert_closers( builder )
    builder.insert_piece( Alpaca::Wizard::Closer.new( 1200 ) { save } )
  end

  def pre_prepare_configuration( config, settings_hash )
    suffix = config["suffix"]
    suffix = "example.com" unless validator.is_hostname?( suffix )
    settings_hash[self.class] = DnsServerSettings.new( :enabled => true, :suffix => suffix )
  end

  def pre_save_configuration( config, settings_hash )
    DnsServerSettings.destroy_all
    
    ## Review : Perhaps this should do something less harsh
    DnsStaticEntry.destroy_all
    DnsUpstreamServers.destroy_all

    ## Save the settings
    settings_hash[self.class].save
  end

  private
  def save
    ## Create a new set of settings
    dns_server_settings = DnsServerSettings.create_default
    
    ## Parse out the suffix from the hostname if it is specified.
    hostname = params[:hostname]
    unless hostname.nil?
      hostname = hostname.strip
      dns_server_settings.suffix = hostname.sub( /^[^\.]*\./, "" ) unless hostname.empty?
    end
    
    DnsServerSettings.destroy_all
    
    ## Review : Perhaps this should do something less harsh
    DnsStaticEntry.destroy_all

    DnsUpstreamServers.destroy_all

    ## Save the settings
    dns_server_settings.save
  end
end
