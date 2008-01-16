module RedirectHelper
  class RedirectTableModel < Alpaca::Table::TableModel
    include Singleton

    def initialize
      columns = []
      columns << Alpaca::Table::Column.new( "enabled", "On".t ) do |redirect,options|
        row_id = options[:row_id]
        view = options[:view]

<<EOF
        #{view.hidden_field_tag( "redirects[]", row_id )}
        #{view.table_checkbox( row_id, "enabled", redirect.enabled )}
EOF
      end
      
      columns << Alpaca::Table::Column.new( "description", "Description".t ) do |redirect,options| 
        "&nbsp;" + options[:view].text_field( "description", options[:row_id], { :value => redirect.description } )
      end
      
      ## This gets complicated.
      ## html_options = { "onlick" => "RuleBuilder.edit( '#{row_id}' )" }
      columns << Alpaca::Table::EditColumn.new do |redirect,options|
        row_id = options[:row_id]
        filter = redirect.filter
        filter = "" if filter.nil?
        view = options[:view]
<<EOF
    #{view.hidden_field( "filters", row_id, { :value => filter } )}
    #{view.hidden_field( "new_ip", row_id, { :value => redirect.new_ip } )}
    #{view.hidden_field( "new_enc_id", row_id, { :value => redirect.new_enc_id } )}
    &nbsp;
EOF
      end

      columns << Alpaca::Table::DeleteColumn.new
      
      super(  "Port Forwards", "redirects", "", "redirect", columns )
    end

    def row_id( row )
      "row-#{rand( 0x100000000 )}"
    end

    def action( table_data, view )
      <<EOF
<div onclick="#{view.remote_function( :url => { :action => :create_redirect } )}" class="add-button">
  #{"Add".t}
</div>
EOF
    end
  end

  def redirect_table_model
    RedirectTableModel.instance
  end

  def self.is_local( ip )
    return ( ip == "localhost" || ip == "127.0.0.1" )
  end
end
