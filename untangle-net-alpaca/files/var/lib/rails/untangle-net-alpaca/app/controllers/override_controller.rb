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
class OverrideController < ApplicationController  
  def get_settings
    settings = {}
    settings["file_overrides"] = FileOverride.ordered_find( :all )
    alpaca_settings = AlpacaSettings.find( :first )
    alpaca_settings = AlpacaSettings.new if alpaca_settings.nil?
    settings["alpaca_settings"] = alpaca_settings

    json_result( :values => settings )
  end

  def set_settings
    s = json_params

    alpaca_settings = AlpacaSettings.find( :first )
    alpaca_settings = AlpacaSettings.new( :send_icmp_redirects => true ) if @alpaca_settings.nil? 
    alpaca_settings.update_attributes( s["alpaca_settings"] )
    
    FileOverride.destroy_all
    position = 0
    s["file_overrides"].each do |entry| 
      file_override = FileOverride.new( entry )
      file_override.position = position
      position += 1
      file_override.save
    end

    os["override_manager"].commit

    json_result
  end

  alias_method :index, :extjs
  
  def manage
    @fileOverrideList = FileOverride.ordered_find( :all )
    @alpaca_settings = AlpacaSettings.find( :first )
    @alpaca_settings = AlpacaSettings.new if @alpaca_settings.nil?
    render :action => 'manage'
  end

  def create_file_override
    @file_override = FileOverride.new
    ## Reasonable defaults
    ## Review: is there some way to do this in the model.
    @file_override.enabled = true
    @file_override.writable = false
    @file_override.path = ""
    @file_override.position = -1
  end

  def file_override_remove
    @rowId = params[:id]

    raise "no row id" if @rowId.nil?

    raise "invalid row id syntax" if /^fo-row-[0-9]*$/.match( @rowId ).nil?
  end

  def save
    ## Review : Internationalization
    return redirect_to( :action => "manage" ) if ( params[:commit] != "Save".t )
    
    fileOverrideList = []

    indices = params[:fileOverrides]
    enabled = params[:enabled]
    writable = params[:writable]
    path = params[:path]
    
    # No file overrides to save if there are no indices
    position = 0
    unless indices.nil?
      indices.each do |key,value|
        ## fileOverride
        fo = FileOverride.new()
        fo.enabled, fo.writable, fo.path = enabled[key], writable[key], path[key]
        fo.position = position
        position += 1
        fileOverrideList << fo
      end
    end
    
    ## Delete all of the old ones
    FileOverride.destroy_all
    
    ## Save all of the new ones
    fileOverrideList.each { |fo| fo.save }

    alpaca_settings = AlpacaSettings.find( :first )
    alpaca_settings = AlpacaSettings.new( :send_icmp_redirects => true ) if @alpaca_settings.nil? 
    
    s = params[:alpaca_settings]
    unless s.nil? || s[:send_icmp_redirects].nil?
      alpaca_settings.send_icmp_redirects = s[:send_icmp_redirects]
      alpaca_settings.save
    end

    os["override_manager"].commit

    ## Review : should have some indication that is saved.
    return redirect_to( :action => "manage" )
  end
end
