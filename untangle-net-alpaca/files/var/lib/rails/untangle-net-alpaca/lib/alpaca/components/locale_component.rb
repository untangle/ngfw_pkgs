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
class Alpaca::Components::LocaleComponent < Alpaca::Component
  def register_menu_items( menu_organizer, config_level )
    ## This is disabled until we switch to ruby gettext.
  end
  
  class LocaleStage < Alpaca::Wizard::Stage
    def initialize( locale_array, settings )
      super( "locale", _("Language"), 100 )
      @locale_array = locale_array
      @settings = settings
    end

    attr_reader :locale_array, :settings
  end

  def wizard_insert_stages( builder )
    ## Register the detection stage
    settings = LocaleSetting.find( :first )

    ## Review : using en-US here is flimsy
    settings = LocaleSetting.new( :key => "en-US" ) if settings.nil?

    ## This is disabled until we support multiple locales.
    ## builder.insert_piece( LocaleStage.new( LOCALES.collect { |key,name| [ name.t, key ] }, settings ))
  end

  def wizard_insert_closers( builder )
    ## This is disabled until we support multiple locales.
    ## Doesn't really matter when this happens
    ## builder.insert_piece( Alpaca::Wizard::Closer.new( 50 ) { validate } )
    ## builder.insert_piece( Alpaca::Wizard::Closer.new( 1999 ) { save } )
  end

  private

  def validate
    locale = params[:locale]
    raise "Invalid locale: #{locale}" if LOCALES[locale].nil?
  end

  def save
    LocaleSetting.destroy_all
    ## Save the new locale
    LocaleSetting.new( :key => params[:locale] ).save
  end
end
