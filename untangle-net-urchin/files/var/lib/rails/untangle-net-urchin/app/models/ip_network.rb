require "ipaddr"

class IpNetwork < ActiveRecord::Base
  ## Parse a network and netmask combination.
  ## Valid Syntax:
  ## w.x.y.z -> w.x.y.z / 32
  ## w.x.y.z / a.b.c.d -> ip / netmask
  ## w.x.y.z / <cidr>
  def parseNetwork( value )
    ## Split it up, and strip the whitespace.
    self.ip, self.netmask  = value.split( "/" ).map { |n| n.strip }
  end

  def netmask=( value )
    value = "32" if ( value.nil? )
    self[:netmask] = value
  end

  protected
  def validate
    errors.add( "Invalid IP Address '#{ip}'" ) if IPAddr.parse( "#{ip}/32" ).nil?        
    errors.add( "Invalid Netmask '#{netmask}'" ) if IPAddr.parse( "1.2.3.4/#{netmask}" ).nil?
  end
end
