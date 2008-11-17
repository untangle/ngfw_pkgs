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
module DnsHelper
  class StaticEntryTableModel < Alpaca::Table::TableModel
    include Singleton

    def initialize
      columns = []
      columns << Alpaca::Table::Column.new( "ip-address", "IP Address" ) do |static_entry,options|
        row_id = options[:row_id]
        view = options[:view]
<<EOF
        #{view.hidden_field_tag( "static_entries[]", row_id )}
        #{view.text_field( "ip_address", row_id, { :value => static_entry.ip_address } )}
EOF
      end
      
      columns << Alpaca::Table::Column.new( "hostname", "Hostname(s)" ) do |static_entry,options|
        "" +
        options[:view].text_field( "hostname", options[:row_id], { :value => static_entry.hostname } )
      end

      columns << Alpaca::Table::Column.new( "description fill", "Description" ) do |static_entry,options| 
        "" +
        options[:view].text_field( "description", options[:row_id], { :value => static_entry.description } )
      end
      
      columns << Alpaca::Table::DeleteColumn.new
      
      super(  "Static DNS Entries", "dns-static-entry", "", "dns-static_entry", columns )
    end

    def row_id( row )
      "row-#{rand( 0x100000000 )}"
    end

    def action( table_data, view )
      <<EOF
<div onclick="#{view.remote_function( :url => { :action => :create_static_entry } )}" class="add-button">
  #{"Add".t}
</div>
EOF
    end
  end

  def static_entry_table_model
    StaticEntryTableModel.instance
  end

  class DynamicEntryTableModel < Alpaca::Table::TableModel
    include Singleton

    def initialize
      columns = []
      columns << Alpaca::Table::Column.new( "ip-address", "IP Address" ) do |dynamic_entry,options|
        "<span>"+dynamic_entry.ip_address+"</span>"
      end

      columns << Alpaca::Table::Column.new( "hostname fill", "Hostname" ) do |dynamic_entry,options| 
        "<span>"+dynamic_entry.hostname+"</span>"
      end
      
      super(  "Automatic DNS Entries", "dns-dynamic-entry", "", "dns-dynamic_entry read-only", columns )
    end

    def row_id( row )
      "row-#{rand( 0x100000000 )}"
    end

    def action( table_data, view )
      <<EOF
<div onclick="#{view.remote_function( :url => { :action => :refresh_dynamic_entries } )}" class="refresh-button">
  #{"Refresh".t}
</div>
EOF
    end
  end

  def dynamic_entry_table_model
    DynamicEntryTableModel.instance
  end

  class UpstreamServersTableModel < Alpaca::Table::TableModel
    include Singleton

    def initialize
      columns = []
      columns << Alpaca::Table::Column.new( "server-ip", "Server Address" ) do |entry,options|
        row_id = options[:row_id]
        view = options[:view]
<<EOF
        #{view.hidden_field_tag( "upstream_servers[]", row_id )}
        #{view.text_field( "server_ip", row_id, { :value => entry.server_ip } )}
EOF
      end

      columns << Alpaca::Table::Column.new( "domain-list fill", "Domain List" ) do |entry,options| 
        options[:view].text_field( "domain_name_lists", options[:row_id], { :value => entry.domain_name_list } )
      end

      columns << Alpaca::Table::DeleteColumn.new
      
      super(  "Local DNS Servers", "dns-upstream-servers", "", "dns-upstream-server-entry", columns )
    end

    def row_id( row )
      "row-#{rand( 0x100000000 )}"
    end

    def action( table_data, view )
      <<EOF
<div onclick="#{view.remote_function( :url => { :action => :create_upstream_server } )}" class="add-button">
  #{"Add".t}
</div>
EOF
    end
  end

  def upstream_servers_table_model
    UpstreamServersTableModel.instance
  end
end

