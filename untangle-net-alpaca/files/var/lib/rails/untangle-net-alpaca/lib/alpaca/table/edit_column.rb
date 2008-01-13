class Alpaca::Table::EditColumn < Alpaca::Table::Column
  def initialize
    super( "edit", "Edit" )
  end

  ## Override this method for more advanced attributes
  def generate_attributes( row, options = {} )
    table_id = options[:data].css_id
    "onclick=\"RuleBuilder.edit( '#{options[:row_id]}' );\""
  end
end
