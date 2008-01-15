module AlpacaHelper

  class StatusTableModel < Alpaca::Table::TableModel
    include Singleton

    def initialize
      columns = []
      
      columns << Alpaca::Table::Column.new( "network_interface", "Network Interface".t ) do |interface,options| 
        options[:view].text_field( "interfaces", options[:row_id], { :value => "#{interface.name}", :readonly => true, :size => 18 } )
      end
      columns << Alpaca::Table::Column.new( "os_name", "OS Name".t ) do |interface,options| 
        options[:view].text_field( "interfaces", options[:row_id], { :value => "#{interface.os_name}", :readonly => true, :size => 8 } )
      end
      columns << Alpaca::Table::Column.new( "carrier", "Connection".t ) do |interface,options| 
        options[:view].text_field( "interfaces", options[:row_id], { :value => "#{interface.carrier}", :readonly => true, :size => 13 } )
      end
      columns << Alpaca::Table::Column.new( "mac", "Hardware Address".t ) do |interface,options| 
        options[:view].text_field( "interfaces", options[:row_id], { :value => "#{interface.hardware_address}", :readonly => true } )
      end
      
      super( table_name="Status", css_class="interface-status", header_css_class="interface-status-header", row_css_class="interface-status-row", columns )
    end

  end

  def status_table_model
    StatusTableModel.instance
  end

end
