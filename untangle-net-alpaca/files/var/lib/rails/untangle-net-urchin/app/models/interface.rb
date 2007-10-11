class Interface < ActiveRecord::Base
  ## Link for a static configuration
  has_one :intf_static
  
  ## Link for the dynamic/dhcp configuration
  has_one :intf_dynamic

  ## Link for the bridge configuration.
  has_one :intf_bridge

  ## Link for all of the interfaces that are bridged with this interface.
  has_many( :bridged_interfaces, :class_name => "IntfBridge", :foreign_key => "bridge_interface_id" )
  
  ## Return true if this interface is bridged with another interface
  def is_bridge?
    ## If the config is in bridge mode, then just return true if the bridged
    ## interface is non-nil
    return !intf_bridge.bridge_interface.nil? if self.config_type == InterfaceHelper::ConfigType::BRIDGE
    
    ## Otherwise grab all of the bridged interfaces and check if any of them
    ## are actually configured as bridges
    bi = self.bridged_interfaces.map{ |ib| ib.interface }
    bi = bi.delete_if { |ib| ib.nil? || ib.config_type != InterfaceHelper::ConfigType::BRIDGE }
    
    ## If there are any entries, then this is a bridge
    ( bi.nil? || bi.empty? ) ? false : true
  end
  
  ## Get the config type
  def current_config
    case self.config_type
    when InterfaceHelper::ConfigType::STATIC
      return intf_static
    when InterfaceHelper::ConfigType::DYNAMIC
      return intf_dynamic
    when InterfaceHelper::ConfigType::BRIDGE
      return intf_bridge
    end

    ## unknown config type?
    nil
  end
end
