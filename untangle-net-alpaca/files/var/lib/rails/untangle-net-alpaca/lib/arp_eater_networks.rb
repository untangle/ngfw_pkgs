## This is in lib, instead of model, because this was originally
## inside of the untangle-arp-eater package, but now it has to be in
## the main area.

class ArpEaterNetworks < ActiveRecord::Base
  AutoStrings = [ "auto", "automatic", "*" ]

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
    unless ( value.to_i.to_s == value )
      cidr = OSLibrary::NetworkManager::CIDR.index( value )
      value = cidr unless cidr.nil?
    end

    value = "32" if ( value.nil? )
    self[:netmask] = value
  end

  protected
  def validate
    errors.add( "Invalid IP Address '#{ip}'" ) if IPAddr.parse_ip( ip ).nil?
    errors.add( "Invalid Netmask '#{netmask}'" ) if IPAddr.parse_netmask( netmask ).nil?
  end

  def self.is_gateway_auto?( test_gateway )
    return true if test_gateway.nil? 
    test_gateway.strip!
    
    return true if test_gateway.empty? || AutoStrings.include?( test_gateway )
    false
  end
end
