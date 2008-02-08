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
        dynamic_entry.ip_address
      end

      columns << Alpaca::Table::Column.new( "hostname fill", "Hostname" ) do |dynamic_entry,options| 
        dynamic_entry.hostname
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
end

