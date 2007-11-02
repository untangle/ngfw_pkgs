class DnsStaticEntry < ActiveRecord::Base
  include Alpaca::ActiveRecordExtensions
  
  def DnsStaticEntry.order_field
    "position"
  end
end
