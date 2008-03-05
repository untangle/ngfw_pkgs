#
# $HeadURL: svn://chef/work/pkgs/untangle-net-alpaca/files/var/lib/rails/untangle-net-alpaca/vendor/plugins/alpaca/lib/alpaca/localization_extensions.rb $
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

## A generic class for validating various types
class Alpaca::Validator
  HostNameMaxLength = 255
  HostNameLabelLength = 63
  
  ## using this syntax because emacs doesn't understand this regex with //
  HostNameLabelMatcher = Regexp.new( "^[0-9A-Za-z]([-/_0-9A-Za-z]*[0-9A-Za-z])?$" )

  MacAddressMaxLength = 17
  MacAddressParts = 6
  MacAddressMatcher =  /^([0-9a-fA-F]{1,2}:){5}[0-9a-fA-F]{1,2}$/

  ## If e is true, return the problem with the value, not just true or false
  def self.is_hostname?( value, e = false )
    value = fix_string( value )

    return rv( "Hostname is empty", e ) if value.empty?
    
    return rv( "Hostname is too long", e ) if value.length > HostNameMaxLength
    
    value.split( "." ).each do |l| 
      return rv( "Hostname label is too long", e ) if l.length > HostNameLabelLength
      return rv( "Hostname contains invalid characters", e ) unless HostNameLabelMatcher.match( l )
    end
    
    return true
  end

  ## Test if a mac address is a valid string
  def self.is_mac_address?( value, e = false )
    value = fix_string( value )
    return rv( "MAC Address is empty", e ) if value.empty?

    return rv( "MAC Address is too long", e ) if value.length > MacAddressMaxLength

    return rv( "MAC Address contains invalid characters", e )  unless MacAddressMatcher.match( value )

    return true
  end

  private
  ## Helper function to strip and clean up a string (basically gets all of the nil? code in one place.)
  def self.fix_string( value )
    return "" if value.nil?
    return value.strip
  end

  ## Helper for the validators, returns return_code if error_string is
  ## true, or true or false otherwise. (true iff return_code is true)
  ## (rv is short for return_value)
  def self.rv( return_code, error_string )
    return error_string ? return_code : return_code == true
  end
end
