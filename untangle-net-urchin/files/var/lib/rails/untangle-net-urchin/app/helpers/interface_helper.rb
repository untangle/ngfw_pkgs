module InterfaceHelper
  IPAddressPattern =  /\b(?:(?:25[0-5]|2[0-4]\d|[01]?\d\d?)\.){3}(?:25[0-5]|2[0-4]\d|[01]?\d\d?)\b/

  def InterfaceHelper.validateNetmask( errors, netmask )
    ## not an ip address.
    if InterfaceHelper::IPAddressPattern.match( netmask ).nil? 
      errors.add( "Invalid CIDR notation '#{netmask}'" ) if /^\d*$/.match( netmask ).nil?
      return
                  
      cidr = netmask.to_i
      errors.add( "CIDR Notation is between 0 and 32, #{cidr}" ) if ( cidr < 0 || cidr > 32 ) 
    end
  end
end
