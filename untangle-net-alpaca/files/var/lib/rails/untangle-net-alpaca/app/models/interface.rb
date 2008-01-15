class Interface < ActiveRecord::Base
  ## Link for a static configuration
  has_one :intf_static, :dependent => :destroy
  
  ## Link for the dynamic/dhcp configuration
  has_one :intf_dynamic, :dependent => :destroy

  ## Link for the bridge configuration.
  has_one :intf_bridge, :dependent => :destroy

  ## Link for the pppoe configuration.
  has_one :intf_pppoe, :dependent => :destroy

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
    when InterfaceHelper::ConfigType::PPPOE
      return intf_pppoe
    end

    ## unknown config type?
    nil
  end

  class ConfigVisitor
    def intf_static( interface, config )
    end

    def intf_dynamic( interface, config )
    end

    def intf_bridge( interface, config )
    end

    def intf_pppoe( interface, config )
    end
  end

  def visit_config( visitor )
    current_config.accept( self, visitor )
  end


  def carrier
    carrier = "Unknown".t
    begin
      f = "/sys/class/net/" + self.os_name + "/carrier"
      sysfs = File.new( f, "r" )
      c = sysfs.readchar
      if c == 49 #ascii for 1
        carrier = "Connected".t
      else
        carrier = "Disconnected".t
      end
    rescue Exception => exception
      logger.error "Error reading carrier status: " + exception.to_s
      carrier = "Unknown".t
    end
    return carrier
  end

  def hardware_address
    address = "Unknown".t
    begin
      sysfs = File.new( "/sys/class/net/" + self.os_name + "/address", "r" )
      address = sysfs.readline
    rescue Exception => exception
      address = "Unknown".t
    end
    return address
  end


end
