## Load the global ipaddr.
#
# $HeadURL$
# Copyright (c) 2007-2008 Untangle, Inc.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License, version 2,
# as published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but
# AS-IS and WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE, TITLE, or
# NONINFRINGEMENT.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA.
#
require "ipaddr"

class ::IPAddr
  ## Simple method to only return an IPAddr if val is a valid IP Address.
  def self.parse( val )
    begin
      ## Invalid if there are two many slashes (IPAddr doesn't catch this)
      return nil if val.nil?

      val = val.strip
      
      return nil if val.empty?
      
      return nil if ( val.count( "/" ) > 1 )

      ip_address, netmask = val.split( "/" )
      
      if ( self.validate_ip_string( ip_address ).nil? )
        return nil
      end
            
      unless netmask.nil?
        if ( netmask.to_i.to_s != netmask )
          if ( self.validate_ip_string( netmask ).nil? )
            return nil
          end
        else
          netmask = netmask.to_i
          if ( netmask < 0 || netmask > 32 ) 
            return nil
          end
        end
      end
      
      addr = self.new( val, family = Socket::AF_INET )

      return addr
    rescue
    end

    ## Return nil on failure
    nil
  end

  def self.parse_ip( val )
    return nil if val.nil?
    val = val.strip
    return nil if val.empty?

    return self.parse( "#{val}/32" )
  end

  def self.parse_netmask( val )
    return nil if val.nil?
    val = val.strip
    return nil if val.empty?

    return self.parse( "255.255.255.255/#{val}" )
  end

  def self.validate_ip_string( ip_string )
    ## IPAddr will do a DNS Lookup on addresses that do not look like
    ## ip addresses.  This causes the system to hang if DNS doesn't work
    ## and it tries to parse a hostname.  This is obviously less then
    ## desirable.  To work around this, we verify the IP address 
    ## is a valid IP Address before sending it to the IPAddr constructor.
    ip_pieces = ip_string.split( "." )
    if ( ip_pieces.length != 4 ) 
      return nil
    end
    ip_pieces.each do |piece|
      n = piece.to_i
      ## One of the pieces is not a number
      if ( n.to_s != piece )
        return nil
      end
      
      ## One piece is out of the range
      if ( n < 0 || n > 255 )
        return nil
      end
    end
    
    return true
  end
end
