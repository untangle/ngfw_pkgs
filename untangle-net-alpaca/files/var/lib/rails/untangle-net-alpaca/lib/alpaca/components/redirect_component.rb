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
class Alpaca::Components::RedirectComponent < Alpaca::Component
  def register_menu_items( menu_organizer, config_level )
    menu_organizer.register_item( "/main/redirects", menu_item( 200, "Port Forwards", {} ))
  end
  
  def wizard_insert_closers( builder )
    ## Doesn't really matter when this happens
    builder.insert_piece( Alpaca::Wizard::Closer.new( 50 ) { validate } )
    builder.insert_piece( Alpaca::Wizard::Closer.new( 1100 ) { save } )
  end

  def pre_save_configuration( config, settings_hash )
    Redirect.destroy_all( "system_id IS NULL" )
  end

  private

  def validate
  end

  def save
    ## Leaving the redirects alone for now.
  end
end
