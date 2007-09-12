class Interface < ActiveRecord::Base
  ## Link for a static configuration
  has_one :intf_static
  
  ## Link for the dynamic/dhcp configuration
  has_one :intf_dynamic

  ## Link for the bridge configuration.
  has_one :intf_bridge

  ## Link for all of the interfaces that are bridged with this interface.
  has_many( :bridged_interfaces, :class_name => "IntfBridge", :foreign_key => "bridge_interface_id" )
end
