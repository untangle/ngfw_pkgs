class Alpaca::Table::TableModel
  def initialize( table_name, css_class, header_css_class, row_css_class, columns )
    @table_name = table_name
    @css_class = css_class
    @header_css_class = header_css_class
    @row_css_class = row_css_class
    @columns = columns
  end

  def row_id( row )
    "e-row-#{rand( 0x100000000 )}"
  end

  ## Override these methods to remove these buttons
  def has_add_button
    true
  end

  def has_label
    true
  end


  attr_reader :table_name, :css_class, :header_css_class, :row_css_class, :columns
end
