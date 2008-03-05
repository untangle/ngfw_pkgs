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
      
      addr = self.new( val )
      return nil unless addr.ipv4?

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
end
