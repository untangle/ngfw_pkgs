class IntfDynamic < ActiveRecord::Base
  belongs_to :interface
  
  has_and_belongs_to_many :ip_networks, :order => "position"

  protected
  def validate
    errors.add( "Invalid IP Address '#{ip}'" ) unless checkField( ip )
    InterfaceHelper::validateNetmask( errors, netmask ) unless ApplicationHelper.null?( netmask )
    errors.add( "Invalid Gateway '#{default_gateway}'" ) unless checkField( default_gateway )
    errors.add( "Invalid Primary DNS Server '#{dns_1}'" ) unless checkField( dns_1 )
    errors.add( "Invalid Secondary DNS Server '#{dns_2}'" ) unless checkField( dns_2 )

    errors.each { |e,f| logger.debug( e + " " + f ) }
  end

  def checkField( field )
    ## In dynamic, none of the fields are required.
    return true if ApplicationHelper.null?( field )
    
    ## The field is valid if the match is non-nil
    return !IPAddr.parse( field ).nil?
  end

  def accept( interface, visitor )
    visitor.intf_dynamic( interface, self )
  end
end
