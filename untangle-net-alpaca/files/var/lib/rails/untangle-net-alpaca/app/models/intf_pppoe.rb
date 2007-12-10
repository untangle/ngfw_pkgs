class IntfPppoe < ActiveRecord::Base
  def accept( interface, visitor )
    visitor.intf_pppoe( interface, self )
  end
end
