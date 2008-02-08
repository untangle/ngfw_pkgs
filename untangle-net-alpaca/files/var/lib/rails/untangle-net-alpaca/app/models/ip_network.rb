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
    unless ( value.to_i.to_s == value )
      cidr = OSLibrary::NetworkManager::CIDR.index( value )
      value = cidr unless cidr.nil?
    end

    value = "32" if ( value.nil? )
    self[:netmask] = value
  end

  protected
  def validate
    errors.add( "Invalid IP Address '#{ip}'" ) if IPAddr.parse( "#{ip}/32" ).nil?        
    errors.add( "Invalid Netmask '#{netmask}'" ) if IPAddr.parse( "1.2.3.4/#{netmask}" ).nil?
  end
end
