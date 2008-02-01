class Alpaca::Table::DragColumn < Alpaca::Table::Column
  def initialize
    super( "drag", "" )
  end

  def generate_header( options = {} )
    view = options[:view]
    view.image_tag( "drag.gif" )
  end
end
