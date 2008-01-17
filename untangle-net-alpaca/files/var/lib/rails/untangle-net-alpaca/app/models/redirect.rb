class Redirect < ActiveRecord::Base
  include Alpaca::ActiveRecordExtensions

  def before_save
    f = self.filter
    if ( /port::/.match( f ) && /protocol::/.match( f ).nil? )
      self.filter << "&&protocol::tcp,udp"
    end
  end
  
  def self.order_field
    "position"
  end
end
