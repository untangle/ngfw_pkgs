class Alpaca::Table::TableModel
  def initialize( css_class, header_css_class, row_css_class, columns )
    @css_class = css_class
    @header_css_class = header_css_class
    @row_css_class = row_css_class
    @columns = columns
  end

  def row_id( row )
    "e-row-#{rand( 0x100000000 )}"
  end

  attr_reader :css_class, :header_css_class, :row_css_class, :columns
end
