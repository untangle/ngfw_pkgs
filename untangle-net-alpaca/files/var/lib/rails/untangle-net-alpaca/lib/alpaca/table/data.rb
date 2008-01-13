## Data that is in the table 
class Alpaca::Table::Data
  def initialize( css_id, rows )
    @css_id = css_id
    @rows = rows
  end

  attr_reader :css_id, :rows
end
