class DhcpStaticEntry < ActiveRecord::Base
  include Alpaca::ActiveRecordExtensions
  
  def DhcpStaticEntry.order_field
    "position"
  end
end
