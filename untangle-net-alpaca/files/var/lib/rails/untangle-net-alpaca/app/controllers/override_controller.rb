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
end
