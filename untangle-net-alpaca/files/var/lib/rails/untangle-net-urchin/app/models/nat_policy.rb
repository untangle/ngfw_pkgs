class NatPolicy < ActiveRecord::Base
  Automatic = "auto"

  ## Parse a network and netmask combination.
  ## Valid Syntax:
  ## w.x.y.z -> w.x.y.z / 32
  ## w.x.y.z / a.b.c.d -> ip / netmask
  ## w.x.y.z / <cidr>
  def parseNetwork( value )
    ## Split it up, and strip the whitespace.
    self.ip, self.netmask = value.split( "/" ).map { |n| n.strip }
  end

  def netmask=( value )
    value = 32 if ( value.nil? )
    self[:netmask] = value
  end

  protected
  def validate
    ## All of the strings have to be internationalized.
    errors.add( "Invalid IP Address '#{ip}'" ) if IPAddr.parse( "#{ip}/32" ).nil?        
    errors.add( "Invalid Netmask '#{netmask}'" ) if IPAddr.parse( "1.2.3.4/#{netmask}" ).nil?

    ## Check the new source address.
    if (( new_source != Automatic ) && ( IPAddr.parse( "#{new_source}/32" ).nil? ))
      errors.add( "Invalid Source Address '#{new_source}'" )
    end
  end
end
