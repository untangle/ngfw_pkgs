class Alpaca::Wizard::Stage < Alpaca::Wizard::Piece
  def initialize( id, name, priority )
    super( priority )
    @id, @name = id, name 
  end
  
  ## ID that is to be used when this is referenced in list.
  def list_id
    "sl-#{@id}"
  end
  
  ## Name of the partial used to render this stage
  def partial
    @id.sub( /-[0-9]+$/, "" ).gsub( "-", "_" )
  end
  
  attr_reader :id, :name
end
