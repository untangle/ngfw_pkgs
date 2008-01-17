class NetworkRoute < ActiveRecord::Base
  def validate
    unless target && ApplicationHelper.ip_address?( target )
      errors.add( :target, "is missing or invalid" )
    end
    
    unless netmask && ApplicationHelper.ip_address?( netmask )
      errors.add( :netmask, "is missing or invalid" )
    end

    unless gateway && ApplicationHelper.ip_address?( gateway )
      errors.add( :gateway, "is missing or invalid" )
    end

    #unless name && ApplicationHelper.description?( name )
    #  errors.add( :name, "is missing or invalid" )
    #end
  end

  def NetworkRoute.get_active( os )
    return os["routes_manager"].get_active
  end
end
