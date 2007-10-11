class FileOverride < ActiveRecord::Base
  include Alpaca::ActiveRecordExtensions
  
  def FileOverride.order_field
    "position"
  end
end
