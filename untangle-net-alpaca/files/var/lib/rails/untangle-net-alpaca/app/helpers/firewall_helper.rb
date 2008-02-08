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
module FirewallHelper
  Actions = [[ "Pass", "pass" ],
             [ "Drop", "drop" ],
             [ "Reject", "reject" ]]

  class FirewallTableModel < Alpaca::Table::TableModel
    include Singleton

    def initialize
      columns = []

      columns << Alpaca::Table::DragColumn.new

      columns << Alpaca::Table::Column.new( "enabled", "On".t ) do |firewall,options|
        row_id = options[:row_id]
        view = options[:view]
<<EOF
        #{view.hidden_field_tag( "firewalls[]", row_id )}
        #{view.table_checkbox( row_id, "enabled", firewall.enabled )}
EOF
      end

      columns << Alpaca::Table::Column.new( "target", "Action".t ) do |firewall,options| 
        "&nbsp;" + options[:view].select( "target", options[:row_id], Actions, { :selected => firewall.target } )
      end
      
      columns << Alpaca::Table::Column.new( "description", "Description".t ) do |firewall,options| 
        "&nbsp;" + options[:view].text_field( "description", options[:row_id], { :value => firewall.description } )
      end
      
      ## This gets complicated.
      ## html_options = { "onlick" => "RuleBuilder.edit( '#{row_id}' )" }
      columns << Alpaca::Table::EditColumn.new do |firewall,options|
        row_id = options[:row_id]
        filter = firewall.filter
        filter = "" if filter.nil?
        view = options[:view]
<<EOF
    #{view.hidden_field( "filters", row_id, { :value => filter } )}
    &nbsp;
EOF
      end

      columns << Alpaca::Table::DeleteColumn.new
      
      super(  "User Packet Filter Rules", "firewalls", "", "firewall", columns )
    end

    def row_id( row )
      "row-#{rand( 0x100000000 )}"
    end

    def action( table_data, view )
      <<EOF
<div onclick="#{view.remote_function( :url => { :action => :create_firewall } )}" class="add-button">
  #{"Add".t}
</div>
EOF
    end
  end

  def firewall_table_model
    FirewallTableModel.instance
  end

  class SystemFirewallTableModel < Alpaca::Table::TableModel
    include Singleton

    def initialize
      columns = []
      columns << Alpaca::Table::Column.new( "enabled", "On".t ) do |system_firewall,options|
        row_id = system_firewall.system_id
        view = options[:view]

<<EOF
        #{view.hidden_field_tag( "system_firewalls[]", row_id )}
        #{view.table_checkbox( row_id, "system_enabled", system_firewall.enabled )}
        #{view.hidden_field( "filters", row_id, { :value => system_firewall.filter } )}
EOF
      end

      
      columns << Alpaca::Table::Column.new( "description", "Description".t ) do |system_firewall,options| 
        "<span>" + system_firewall.description + "</span>"
      end
            
      super(  "System Packet Filter Rules", "system-firewalls", "", "system_firewall read-only", columns )
    end
  end

  def system_firewall_table_model
    SystemFirewallTableModel.instance
  end



end
