class IntfBridge < ActiveRecord::Base
  belongs_to( :interface )
  
  belongs_to( :bridge_interface, :class_name => "Interface", :foreign_key => "bridge_interface_id" )
  
  protected
  def validate
    bridge = bridge_interface
    
    return errors.add( "A bridge interface must be specified" ) if bridge.nil?
    unless InterfaceHelper::BRIDGEABLE_CONFIGTYPES.include?( bridge.config_type )
      return errors.add( "Unable to bridge with the interface #{bridge.name}" )
    end
  end
end
