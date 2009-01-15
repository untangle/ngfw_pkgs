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
class LocaleController < ApplicationController
  def set_language
    s = json_params
    language_settings = LanguageSettings.find( :first )
    language_settings = LanguageSettings.new if language_settings.nil?
    language_settings.update_attributes( s["language_settings"] )
    language_settings.save
    json_result
  end

  def index
    manage
    render :action => 'manage'
  end
  
  def manage
    @title = "Select your current Locale"
    
    @localeArray = LOCALES.collect { |key,name| [ name.t, key ] }
    @settings = LocaleSetting.find( :first )
    @settings = LocaleSetting.new( :key => "en-US" ) if @settings.nil?
  end
  
  def save
    ## Review : Internationalization
    return redirect_to( :action => "manage" ) if ( params[:commit] != "Save".t )
    
    newLocale = params[:locale]
    
    logger.debug( "new locale: '#{newLocale}'" )

    ## Review : validation
    return redirect_to( :action => "manage" ) if newLocale.nil? || LOCALES[newLocale].nil?

    LocaleSetting.destroy_all

    ## Save the new locale
    LocaleSetting.new( :key => newLocale ).save
    
    return redirect_to( :action => "manage" )
  end
end
