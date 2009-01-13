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
    json_result( settings )
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

  def manage
    @current_routes = NetworkRoute.get_active( os )
    @network_routes = NetworkRoute.find( :all )
    @network_routes = [] if @network_routes.nil?
  end

  def save
    return redirect_to( :action => "manage" ) if ( params[:commit] != "Save".t )

    NetworkRoute.destroy_all

    network_routes = params[:network_route]
    
    ## ignore empty lists
    network_routes = [] if network_routes.nil?
    
    network_routes.each do |network_route_row|
      if (!(params[:target][network_route_row].nil?) \
          && params[:target][network_route_row].length > 0\
          && !(params[:netmask][network_route_row].nil?) \
          && params[:netmask][network_route_row].length > 0\
          && !(params[:gateway][network_route_row].nil?) \
          && params[:gateway][network_route_row].length > 0)

        if (params[:name][network_route_row].nil?)
          params[:name][network_route_row] = ""
        end
        
        netmask = OSLibrary::NetworkManager::parseNetmask( params[:netmask][network_route_row] )
        network_route_obj = NetworkRoute.new
        network_route_obj.update_attributes( :target => params[:target][network_route_row], :netmask => netmask, :gateway => params[:gateway][network_route_row], :name => params[:name][network_route_row] )
        network_route_obj.save
      end
    end
    
    os["routes_manager"].commit

    ## Review : should have some indication that is saved.
    return redirect_to( :action => "manage" )
  end
  def create_route
    @network_route = NetworkRoute.new  
  end
end
