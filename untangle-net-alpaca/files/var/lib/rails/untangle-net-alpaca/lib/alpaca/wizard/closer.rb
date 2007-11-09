## Use to commmit / close the wizard session.  All of the settings
## should be committed to the database.

## Save priorities are as follows:
## 0    - 1000 validation : database should never be modified.
## 1000 - 2000 save       : database values are saved.
## 2000 - 3000 commit     : database values are commited to filesystem and services are restarteed.
class Alpaca::Wizard::Closer < Alpaca::Wizard::Piece
  def initialize( priority, &close )
    super( priority )
    raise "Must provide a block to save when creating a closer" if close.nil?
    @close = close
  end
  
  def save
    @close.call
  end
end
