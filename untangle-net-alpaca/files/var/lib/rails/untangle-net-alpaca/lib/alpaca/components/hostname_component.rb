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
class Alpaca::Components::HostnameComponent < Alpaca::Component
  class HostnameStage < Alpaca::Wizard::Stage
    def initialize( hostname )
      super( "hostname", _("Hostname"), 400 )
      @hostname = hostname
    end

    attr_reader :hostname
  end

  ## Register all of the menu items.
  def register_menu_items( menu_organizer, config_level )
    menu_organizer.register_item( "/extjs/hostname", menu_item( 300, _("Hostname"), :action => "index" ))
  end

  def wizard_generate_review( review )
    review["hostname"] = params[:hostname]
  end
  
  ## Insert the desired stages for the wizard.
  def wizard_insert_stages( builder )
    hostname = os["hostname_manager"].current
    
    ## Register the hostname configuration stage
    builder.insert_piece( HostnameStage.new( hostname ))
  end

  def wizard_insert_closers( builder )
    builder.insert_piece( Alpaca::Wizard::Closer.new( 0 ) { validate } )
    builder.insert_piece( Alpaca::Wizard::Closer.new( 1600 ) { save } )
  end

  def validate
    raise "invalid hostname" if ApplicationHelper.null?( params[:hostname] )
  end

  def pre_prepare_configuration( config, settings_hash )
    settings = HostnameSettings.new
    
    hostname = config["hostname"]
    hostname = "untangle.example.com" unless validator.is_hostname?( hostname )
    settings.hostname = hostname

    settings_hash[self.class] = settings
  end

  def pre_save_configuration( config, settings_hash )
    HostnameSettings.destroy_all
    settings_hash[self.class].save
  end

  def save
    hostname_settings = HostnameSettings.find( :first )
    hostname_settings = HostnameSettings.new if hostname_settings.nil?
    hostname_settings.hostname = params[:hostname]
    hostname_settings.save
  end
end
