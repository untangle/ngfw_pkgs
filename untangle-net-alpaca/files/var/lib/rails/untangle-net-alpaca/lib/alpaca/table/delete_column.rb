class Alpaca::Table::DeleteColumn < Alpaca::Table::Column
  def initialize
    super( "minus", "Delete".t )
  end

  ## Override this method for more advanced attributes
  def generate_attributes( row, options = {} )
    table_id = options[:data].css_id
    "onclick=\"TableManager.remove( '#{table_id}', '#{options[:row_id]}' );\""
  end
end
