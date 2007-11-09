class Alpaca::Wizard::Builder
  def initialize( type )
    @type = type
    @pieces = {}
  end

  ## append a piece
  def insert_piece( piece )
    ## Skip all of the items that are not the correct type
    next unless piece.is_a? @type 

    if @pieces[piece.priority].nil?
      @pieces[piece.priority] = [piece]
    else
      @pieces[piece.priority] << piece
    end
  end

  ## Iterate the pieces in order.
  def iterate_pieces
    keys = @pieces.keys.sort

    ## Iterate through each of the pieces at each of the priorties
    keys.each { |key| @pieces[key].each { |piece| yield piece }}
  end
end
