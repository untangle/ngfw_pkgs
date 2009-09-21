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
class AlpacaController < ApplicationController
  def get_settings
    json_result( :values => { "alpaca_settings" => @alpaca_settings, "config_level" => @config_level })
  end

  def set_to_advanced
    ## Change the level to advanced
    @alpaca_settings.config_level = AlpacaSettings::Level::Advanced.level
    @alpaca_settings.save
    
    json_result
  end

  def continue_background_command
    s = json_params

    key = s["key"]
    raise "Missing command key" if key.nil?
    
    stdout_offset = s["stdout_offset"]
    stdout_offset = 0 if stdout_offset.nil?
    stderr_offset = s["stderr_offset"]
    stderr_offset = 0 if stderr_offset.nil?

    session_id = get_user_command_session_id
    result = ApplicationHelper.get_user_command_output( session_id, key, stdout_offset, stderr_offset )
    
    json_result( :values => result )
  end

  alias_method :index, :extjs

  def status
    @interfaces = Interface.find( :all )
  end
end
