class Subscription < ActiveRecord::Base
  include Alpaca::ActiveRecordExtensions
  
  def self.order_field
    "position"
  end
end
