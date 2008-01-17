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
      
      columns << Alpaca::Table::Column.new( "hw_addr", "HW Address".t ) do |arp,options| 
        "&nbsp;" + options[:view].text_field( "hw_addr", options[:row_id], { :value => arp.hw_addr } )
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
        #{system_arp.ip_address}
EOF
      end

      
      columns << Alpaca::Table::Column.new( "hw_addr", "HW Address".t ) do |system_arp,options| 
        "&nbsp;" + system_arp.mac_address
      end

      columns << Alpaca::Table::Column.new( "interface", "Interface".t ) do |system_arp,options| 
        "&nbsp;" + system_arp.interface
      end
            
      super(  "Active ARP Entries", "arps", "", "system_arp", columns )
    end
  end

  def system_arp_table_model
    SystemArpTableModel.instance
  end
end
