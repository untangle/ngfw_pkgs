class StaticArp < ActiveRecord::Base
  def validate
    unless hw_addr && ApplicationHelper.ip_address?( hw_addr )
      errors.add( :hw_addr, "is missing or invalid" )
    end
    
    unless hostname && ApplicationHelper.ip_address?( hostname )
      errors.add( :hostname, "is missing or invalid" )
    end
  end
end
