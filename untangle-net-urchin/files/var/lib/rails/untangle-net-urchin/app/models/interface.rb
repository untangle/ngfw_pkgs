class Interface < ActiveRecord::Base
  has_one :intf_static

  has_one :intf_dynamic
end
