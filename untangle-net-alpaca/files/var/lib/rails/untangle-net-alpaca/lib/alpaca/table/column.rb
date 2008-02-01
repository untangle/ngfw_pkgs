## Data that is in the table 
class Alpaca::Table::Column
  ## css_class : The CSS Class for this columns
  ## title : Title to display in the header
  ## otherwise, generate_column must build the div.
  ## Pass in the block capable of converting a row to this column of data.
  def initialize( css_class, title, attributes = {}, &generator )
    @css_class = css_class
    title = "&nbsp;" if ( title.nil? || title.empty? )
    @title = title
    @attributes = attributes
    @generator = generator
  end
  
  ## Abstract method, given a row of a data, return the HTML
  ## to fill that row.
  def generate_column( row, options ={} )
    return "&nbsp;" if @generator.nil?

    @generator.call( row, options )
  end

  ## Override this method for more advanced attributes
  def generate_attributes( row, options = {} )
    ## Convert the options into an HTML string
    @attributes.map { |k,v| "#{k}='#{v}'" }.join( " " )
  end

  ## Override this to generate a more complicated header
  def generate_header( options = {} )
    self.title.t
  end
  
  attr_reader :css_class, :title, :attributes
end
