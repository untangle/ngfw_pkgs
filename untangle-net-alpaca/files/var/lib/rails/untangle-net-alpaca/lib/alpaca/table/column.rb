## Data that is in the table 
class Alpaca::Table::Column
  ## css_class : The CSS Class for this columns
  ## title : Title to display in the header
  ## otherwise, generate_column must build the div.
  ## Pass in the block capable of converting a row to this column of data.
  def initialize( css_class, title, options = {}, &generator )
    @css_class = css_class
    title = "&nbsp;" if ( title.nil? || title.empty? )
    @title = title
    ## Convert the options into an HTML string
    @options = options.map { |k,v| "#{k}='#{v}'" }.join( " " )
    @generator = generator
  end
  
  ## Abstract method, given a row of a data, return the HTML
  ## to fill that row.
  def generate_column( row, options ={} )
    @generator.call( row, options )
  end
  
  attr_reader :css_class, :title, :options
end
