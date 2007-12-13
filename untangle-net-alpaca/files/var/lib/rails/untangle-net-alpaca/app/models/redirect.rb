class Redirect < ActiveRecord::Base
  include Alpaca::ActiveRecordExtensions

  def before_save
    if self.filter =~ /protocol::/
      return true
    else
      self.filter << "&&protocol::tcp,udp"
    end
  end
  
  def self.order_field
    "position"
  end
end
