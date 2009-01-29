## REVIEW Should create a consistent way to build these tables.
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
class ArpController < ApplicationController
  def get_settings
    settings = {}
    settings["active_arps"] = StaticArp.get_active( os )
    settings["static_arps"] = StaticArp.find( :all )
    json_result( :values => settings )
  end

  def get_active
    json_result( :values => StaticArp.get_active( os ))
  end
  
  def set_settings
    s = json_params

    StaticArp.destroy_all

    static_arps = s["static_arps"]
    
    unless static_arps.nil?
      static_arps.each { |entry| StaticArp.new( entry ).save }
    end

    os["arps_manager"].commit

    json_result
  end

  alias_method :index, :extjs
end
