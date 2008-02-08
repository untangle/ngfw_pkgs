module UvmHelper
  VpnIndex = 8
  ## Indices : 
  ## 1 -> external
  ## 3 -> DMZ
  ## 8 -> VPN
  ## 2 -> internal
  DefaultOrder = "1,3,#{VpnIndex},2"

  class SubscriptionTableModel < Alpaca::Table::TableModel
    include Singleton

    def initialize
      columns = []
      columns << Alpaca::Table::DragColumn.new
      columns << Alpaca::Table::Column.new( "enabled", "On".t ) do |subscription,options|
        row_id = options[:row_id]
        view = options[:view]
<<EOF
        #{view.hidden_field_tag( "subscriptions[]", row_id )}
        #{view.table_checkbox( row_id, "enabled", subscription.enabled )}
EOF
      end
      columns << Alpaca::Table::Column.new( "subscribe", "Bypass".t ) do |subscription,options|
        row_id = options[:row_id]
        view = options[:view]
<<EOF
        #{view.check_box( "subscribe", row_id, { :checked => ! subscription.subscribe }, false, true )}
EOF
      end
      
      columns << Alpaca::Table::Column.new( "description", "Description".t ) do |subscription,options| 
        "&nbsp;" + options[:view].text_field( "description", options[:row_id], { :value => subscription.description } )
      end
      
      ## This gets complicated.
      ## html_options = { "onlick" => "RuleBuilder.edit( '#{row_id}' )" }
      columns << Alpaca::Table::EditColumn.new do |subscription,options|
        row_id = options[:row_id]
        filter = subscription.filter
        filter = "" if filter.nil?
        view = options[:view]
<<EOF
    #{view.hidden_field( "filters", row_id, { :value => filter } )}
    &nbsp;
EOF
      end

      columns << Alpaca::Table::DeleteColumn.new
      
      super(  "Bypass Rules".t, "subscriptions", "", "subscription", columns )
    end

    def row_id( row )
      "row-#{rand( 0x100000000 )}"
    end

    def action( table_data, view )
      <<EOF
<div onclick="#{view.remote_function( :url => { :action => :create_subscription } )}" class="add-button">
  #{"Add".t}
</div>
EOF
    end
  end

  def subscription_table_model
    SubscriptionTableModel.instance
  end

  class SystemSubscriptionTableModel < Alpaca::Table::TableModel
    include Singleton

    def initialize
      columns = []
      columns << Alpaca::Table::Column.new( "enabled", "On".t ) do |system_subscription,options|
        row_id = system_subscription.system_id
        view = options[:view]

<<EOF
        #{view.hidden_field_tag( "system_subscriptions[]", system_subscription.system_id )}
        #{view.table_checkbox( row_id, "system_enabled", system_subscription.enabled )}
        #{view.hidden_field( "filters", row_id, { :value => system_subscription.filter } )}
EOF
      end

      
      columns << Alpaca::Table::Column.new( "description", "Description".t ) do |system_subscription,options| 
        "<span>" + system_subscription.description + "</span>"
      end
            
      super(  "System Bypass Rules".t, "system-subscriptions", "", "system_subscription read-only", columns )
    end
  end

  def system_subscription_table_model
    SystemSubscriptionTableModel.instance
  end
end
