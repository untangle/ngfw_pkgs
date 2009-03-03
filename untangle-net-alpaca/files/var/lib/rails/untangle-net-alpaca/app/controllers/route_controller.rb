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
class RouteController < ApplicationController
  def get_settings
    settings = {}
    settings["active_routes"] = NetworkRoute.get_active( os )
    settings["static_routes"] = NetworkRoute.find( :all )
    settings["interface_enum"] = build_interface_enum().delete_if { |i| i[0] == 8 }

    json_result( :values => settings )
  end

  def set_settings
    s = json_params

    network_routes = s["static_routes"].map do |entry| 
      entry["netmask"] = OSLibrary::NetworkManager::parseNetmask( entry["netmask"] )
      NetworkRoute.new( entry )
    end
    
    NetworkRoute.destroy_all
    network_routes.each { |route| route.save }

    os["routes_manager"].commit

    json_result
  end
  
  alias_method :index, :extjs
end
