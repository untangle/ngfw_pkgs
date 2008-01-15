module DhcpHelper
  ## System ID for rules that block / pass DHCP traffic
  RuleSystemID = "dhcp-system-rule-33d4710d44b25d4115022b8c6f4b7e02"

  class StaticEntryTableModel < Alpaca::Table::TableModel
    include Singleton

    def initialize
      columns = []
      columns << Alpaca::Table::Column.new( "mac-address", "MAC Address" ) do |static_entry,options|
        row_id = options[:row_id]
        view = options[:view]

<<EOF
        #{view.hidden_field_tag( "static_entries[]", row_id )}
        #{view.text_field( "mac_address", row_id, { :value => static_entry.mac_address } )}
EOF
      end
      
      columns << Alpaca::Table::Column.new( "ip-address", "IP Address" ) do |static_entry,options|
        "&nbsp;" +
        options[:view].text_field( "ip_address", options[:row_id], { :value => static_entry.ip_address } )
      end

      columns << Alpaca::Table::Column.new( "description fill", "Description" ) do |static_entry,options| 
        "&nbsp;" +
        options[:view].text_field( "description", options[:row_id], { :value => static_entry.description } )
      end
      
      columns << Alpaca::Table::DeleteColumn.new
      
      super(  "Static DHCP Entries", "dhcp-static-entry", "", "dhcp-static_entry", columns )
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

  class Alpaca::Table::AddStaticColumn < Alpaca::Table::Column
    def initialize
      super( "add-static", "Add" )
    end
    
    ## Override this method for more advanced attributes
    def generate_attributes( dynamic_entry, options = {} )
      table_id = options[:data].css_id
      view = options[:view]
<<EOF
onclick="#{view.remote_function( :url => { :action => :create_static_entry, :mac_address => dynamic_entry.mac_address, :ip_address => dynamic_entry.ip_address, :description => dynamic_entry.hostname })}" class="add-button"
EOF
    end
  end

  class DynamicEntryTableModel < Alpaca::Table::TableModel
    include Singleton

    def initialize
      columns = []
      columns << Alpaca::Table::Column.new( "mac-address", "MAC Address" ) do |dynamic_entry,options|
        dynamic_entry.mac_address
      end
      
      columns << Alpaca::Table::Column.new( "ip-address", "IP Address" ) do |dynamic_entry,options| 
        dynamic_entry.ip_address
      end

      columns << Alpaca::Table::Column.new( "hostname fill", "Hostname" ) do |dynamic_entry,options| 
        dynamic_entry.hostname
      end
      
      columns << Alpaca::Table::AddStaticColumn.new
      
      super(  "Current DHCP Entries", "dhcp-dynamic-entry", "", "dhcp-dynamic_entry", columns )
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
end
