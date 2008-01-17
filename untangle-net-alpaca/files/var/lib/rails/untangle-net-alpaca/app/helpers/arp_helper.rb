module ArpHelper
  class ArpTableModel < Alpaca::Table::TableModel
    include Singleton

    def initialize
      columns = []
      columns << Alpaca::Table::Column.new( "enabled", "On".t ) do |arp,options|
        row_id = options[:row_id]
        view = options[:view]
<<EOF
        #{view.hidden_field_tag( "arps[]", row_id )}
        #{view.table_checkbox( row_id, "enabled", arp.enabled )}
EOF
      end

      columns << Alpaca::Table::Column.new( "target", "Target".t ) do |arp,options| 
        "&nbsp;" + options[:view].select( "target", options[:row_id], Actions, { :selected => arp.target } )
      end
      
      columns << Alpaca::Table::Column.new( "description", "Description".t ) do |arp,options| 
        "&nbsp;" + options[:view].text_field( "description", options[:row_id], { :value => arp.description } )
      end
      
      ## This gets complicated.
      ## html_options = { "onlick" => "RuleBuilder.edit( '#{row_id}' )" }
      columns << Alpaca::Table::EditColumn.new do |arp,options|
        row_id = options[:row_id]
        filter = arp.filter
        filter = "" if filter.nil?
        view = options[:view]
<<EOF
    #{view.hidden_field( "filters", row_id, { :value => filter } )}
    &nbsp;
EOF
      end

      columns << Alpaca::Table::DeleteColumn.new
      
      super(  "User Packet Filter Rules", "arps", "", "arp", columns )
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
      columns << Alpaca::Table::Column.new( "enabled", "On".t ) do |system_arp,options|
        row_id = system_arp.system_id
        view = options[:view]

<<EOF
        #{view.hidden_field_tag( "system_arps[]", row_id )}
        #{view.table_checkbox( row_id, "system_enabled", system_arp.enabled )}
        #{view.hidden_field( "filters", row_id, { :value => system_arp.filter } )}
EOF
      end

      
      columns << Alpaca::Table::Column.new( "description", "Description".t ) do |system_arp,options| 
        "&nbsp;" + options[:view].text_field( "description", system_arp.system_id, { :value => system_arp.description } )
      end
            
      super(  "System Packet Filter Rules", "system-arps", "", "system_arp", columns )
    end
  end

  def system_arp_table_model
    SystemArpTableModel.instance
  end


end
