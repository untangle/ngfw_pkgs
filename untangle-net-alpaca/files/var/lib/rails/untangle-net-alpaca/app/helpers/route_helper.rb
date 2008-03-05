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
module RouteHelper
  class RouteTableModel < Alpaca::Table::TableModel
    include Singleton

    def initialize
      columns = []
      columns << Alpaca::Table::Column.new( "target", "Target".t ) do |route,options|
        row_id = options[:row_id]
        view = options[:view]
<<EOF
        #{view.hidden_field_tag( "network_route[]", row_id )}
        #{view.text_field( "target", options[:row_id], { :value => route.target } )}
EOF
      end
      
      columns << Alpaca::Table::Column.new( "netmask", "Netmask".t ) do |route,options| 
        options[:view].text_field( "netmask", options[:row_id], { :value => route.netmask } )
      end

      columns << Alpaca::Table::Column.new( "gateway", "Gateway".t ) do |route,options| 
        options[:view].text_field( "gateway", options[:row_id], { :value => route.gateway } )
      end

      columns << Alpaca::Table::Column.new( "name", "Description".t ) do |route,options| 
        options[:view].text_field( "name", options[:row_id], { :value => route.name } )
      end

      columns << Alpaca::Table::DeleteColumn.new
      
      super( "Static Routes", "routes", "", "route", columns )
    end

    def row_id( row )
      "row-#{rand( 0x100000000 )}"
    end

    def action( table_data, view )
      <<EOF
<div onclick="#{view.remote_function( :url => { :action => :create_route } )}" class="add-button">
  #{"Add".t}
</div>
EOF
    end
  end

  def route_table_model
    RouteTableModel.instance
  end

  class SystemRouteTableModel < Alpaca::Table::TableModel
    include Singleton

    def initialize
      columns = []
      columns << Alpaca::Table::Column.new( "target", "Target".t ) do |system_route,options| 
        "<span>" + system_route.target + "</span>"
      end
      
      columns << Alpaca::Table::Column.new( "netmask", "Netmask".t ) do |system_route,options| 
        "<span>" + system_route.netmask + "</span>"
      end

      columns << Alpaca::Table::Column.new( "gateway", "Gateway".t ) do |system_route,options| 
        "<span>" + system_route.gateway + "</span>"
      end

      columns << Alpaca::Table::Column.new( "interface", "Interface".t ) do |system_route,options| 
        "<span>" + system_route.interface + "</span>"
      end
            
      super( "Active Routes", "routes", "", "system_route read-only", columns )
    end
  end

  def system_route_table_model
    SystemRouteTableModel.instance
  end
end
