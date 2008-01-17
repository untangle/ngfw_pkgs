module OverrideHelper
  class OverrideTableModel < Alpaca::Table::TableModel
    include Singleton

    def initialize
      columns = []
      columns << Alpaca::Table::Column.new( "enabled", "On".t ) do |override,options|
        row_id = options[:row_id]
        view = options[:view]
<<EOF
        #{view.hidden_field_tag( "fileOverrides[]", row_id )}
        #{view.table_checkbox( row_id, "enabled", override.enabled )}
EOF
      end

      columns << Alpaca::Table::Column.new( "writable", "Writable".t ) do |override,options| 
        "&nbsp;" + options[:view].check_box( "writable", options[:row_id], { :checked => override.writable }, true, false )
      end
      
      columns << Alpaca::Table::Column.new( "path", "File Path".t ) do |override,options|
        "&nbsp;" + options[:view].text_field( "path", options[:row_id], { :value => override.path } )
      end

      columns << Alpaca::Table::DeleteColumn.new
      
      super(  "File Overrides", "overrides", "", "override", columns )
    end

    def row_id( row )
      "row-#{rand( 0x100000000 )}"
    end

    def action( table_data, view )
      <<EOF
<div onclick="#{view.remote_function( :url => { :action => :create_file_override } )}" class="add-button">
  #{"Add".t}
</div>
EOF
    end
  end

  def override_table_model
    OverrideTableModel.instance
  end
end
