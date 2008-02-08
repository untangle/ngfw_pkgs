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
module ArpHelper
  class ArpTableModel < Alpaca::Table::TableModel
    include Singleton

    def initialize
      columns = []
      columns << Alpaca::Table::Column.new( "hostname", "IP Address".t ) do |arp,options|
        row_id = options[:row_id]
        view = options[:view]
<<EOF
        #{view.hidden_field_tag( "static_arp[]", row_id )}
        #{view.text_field( "hostname", options[:row_id], { :value => arp.hostname } )}
EOF
      end
      
      columns << Alpaca::Table::Column.new( "hw_addr", "MAC Address".t ) do |arp,options| 
        options[:view].text_field( "hw_addr", options[:row_id], { :value => arp.hw_addr } )
      end

      columns << Alpaca::Table::DeleteColumn.new
      
      super(  "Static ARP Entries", "arps", "", "arp", columns )
    end

    def row_id( row )
      "row-#{rand( 0x100000000 )}"
    end

    def action( table_data, view )
      <<EOF
<div onclick="#{view.remote_function( :url => { :action => :create_arp } )}" class="add-button">
  #{"Add".t}
</div>
EOF
    end
  end

  def arp_table_model
    ArpTableModel.instance
  end

  class SystemArpTableModel < Alpaca::Table::TableModel
    include Singleton

    def initialize
      columns = []
      columns << Alpaca::Table::Column.new( "hostname", "IP Address".t ) do |system_arp,options|
        view = options[:view]
<<EOF
      <span>  #{system_arp.ip_address} </span>
EOF
      end

      
      columns << Alpaca::Table::Column.new( "hw_addr", "MAC Address".t ) do |system_arp,options| 
       options[:view].mac_address_link( system_arp.mac_address )
      end

      columns << Alpaca::Table::Column.new( "interface", "Interface".t ) do |system_arp,options| 
        "<span>" + system_arp.interface + "</span>"
      end
            
      super(  "Active ARP Entries", "arps", "", "system_arp read-only", columns )
    end
  end

  def system_arp_table_model
    SystemArpTableModel.instance
  end
end
