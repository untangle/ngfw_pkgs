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
class Alpaca::Components::WizardComponent < Alpaca::Component
  def register_menu_items( menu_organizer, config_level )
    #menu_organizer.register_item( "/main/status/wizard", menu_item( 100, "Wizard", {} ))
  end

  def wizard_insert_stages( builder )
    ## Register the detection stage
    builder.insert_piece( Alpaca::Wizard::Stage.new( "welcome", "Welcome".t, 0 ))
    builder.insert_piece( Alpaca::Wizard::RjsStage.new( "review", "Review".t, 999, "generate_review" ))
    builder.insert_piece( Alpaca::Wizard::Stage.new( "finish", "Finished".t, 1000 ))
  end
end
