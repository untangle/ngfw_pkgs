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
    errors.add( "Invalid IP Address '#{ip}'" ) if IPAddr.parse_ip( ip ).nil?

    errors.add( "Invalid Netmask '#{netmask}'" ) if IPAddr.parse_netmask( netmask ).nil?

    ## Check the new source address.
    errors.add( "Invalid Source Address '#{new_source}'" ) if ( new_source.nil? || new_source.empty? )

    if (( new_source != Automatic ) && ( IPAddr.parse_ip( new_source ).nil? ))
      errors.add( "Invalid Source Address '#{new_source}'" )
    end
  end
end
