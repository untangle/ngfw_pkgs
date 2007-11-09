## This is how to represent a  in the wizard, 
## extend this for more advanced stages.
class Alpaca::Wizard::Piece
  def initialize( priority )
    @priority = priority
  end
    
  attr_reader :priority
end
  
