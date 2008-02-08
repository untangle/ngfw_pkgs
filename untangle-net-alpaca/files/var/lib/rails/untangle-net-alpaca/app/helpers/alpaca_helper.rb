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
module AlpacaHelper

  class StatusTableModel < Alpaca::Table::TableModel
    include Singleton

    def initialize
      columns = []
      
      columns << Alpaca::Table::Column.new( "network_interface", "Network Interface".t ) do |interface,options| 
        options[:view].text_field( "interfaces", options[:row_id], { :value => "#{interface.name}", :readonly => true, :size => 18 } )
      end
      #columns << Alpaca::Table::Column.new( "os_name", "OS Name".t ) do |interface,options| 
      #  options[:view].text_field( "interfaces", options[:row_id], { :value => "#{interface.os_name}", :readonly => true, :size => 8 } )
      #end
      columns << Alpaca::Table::Column.new( "carrier", "Connection".t ) do |interface,options| 
        options[:view].text_field( "interfaces", options[:row_id], { :value => "#{interface.interface_status}", :readonly => true, :size => 13 } )
      end
      columns << Alpaca::Table::Column.new( "mac", "Hardware Address".t ) do |interface,options| 
        #options[:view].text_field( "interfaces", options[:row_id], { :value => "#{interface.hardware_address}", :readonly => true } )
        options[:view].mac_address_link( interface.hardware_address )
      end
      
      super( table_name="Status", css_class="interface-status", header_css_class="interface-status-header", row_css_class="interface-status-row read-only", columns )
    end

    def action( table_data, view )
      <<EOF
<div onclick="#{view.remote_function( :update => "main-content", :url => { :action => :status } )}" class="refresh-button">
  #{"Refresh".t}
</div>
EOF
    end

  end

  def status_table_model
    StatusTableModel.instance
  end

end
