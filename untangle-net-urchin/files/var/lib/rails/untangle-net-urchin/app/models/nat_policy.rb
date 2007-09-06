class NatPolicy < ActiveRecord::Base
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
    errors.add( "Invalid IP Address '#{ip}'" ) if InterfaceHelper::IPAddressPattern.match( ip ).nil?
    InterfaceHelper::validateNetmask( errors, netmask )
  end
end
