require "ipaddr"

class IntfStatic < ActiveRecord::Base
  belongs_to :interface
  
  has_and_belongs_to_many :ip_networks, :order => "position"

  has_and_belongs_to_many :nat_policies, :order => "position"

  protected
  def validate
    errors.add( "Invalid Default Gateway '#{default_gateway}'" ) unless checkField( default_gateway )
    errors.add( "Invalid Primary DNS Server '#{dns_1}'" ) unless checkField( dns_1 )
    errors.add( "Invalid Secondary DNS Server '#{dns_2}'" ) unless checkField( dns_2 )

    errors.each { |e,f| logger.debug( e.to_s + " " + f.to_s ) }
  end

  def checkField( field )
    ## In dynamic, none of the fields are required.
    return true if ApplicationHelper.null?( field )
    
    ## The field is valid if the match is non-nil
    return !IPAddr.parse( field ).nil?
  end

  def accept( interface, visitor )
    visitor.intf_static( interface, self )
  end
end
