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
class Alpaca::Components::UvmComponent < Alpaca::Component
  def register_menu_items( menu_organizer, config_level )
    if ( config_level >= AlpacaSettings::Level::Advanced ) 
      menu_organizer.register_item( "/advanced/uvm", menu_item( 300, _("Bypass Rules"), :action => "index" ))
    end
  end

  def wizard_insert_closers( builder )
    builder.insert_piece( Alpaca::Wizard::Closer.new( 1900 ) { save } )
  end

  def pre_save_configuration( config, settings_hash )
    ## This is used as a key for future updates to know which rules are safe to remove
    host_ip_marker="[**** Host Machine ****]"

    Subscription.destroy_all( "system_id IS NULL" )

    ## Load all of the additional filter rules.
    mac_address_list = config["mac_addresses"] or ""
  end

  private
  def save
    os["uvm_manager"].write_files
  end
end
