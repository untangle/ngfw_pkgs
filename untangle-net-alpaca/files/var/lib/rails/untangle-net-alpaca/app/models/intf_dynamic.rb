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
class IntfDynamic < ActiveRecord::Base
  belongs_to :interface
  
  has_and_belongs_to_many :ip_networks, :order => "position"

  def accept( interface, visitor )
    visitor.intf_dynamic( interface, self )
  end

  protected
  def validate
    errors.add( "Invalid IP Address '#{ip}'" ) unless checkField( ip )
    InterfaceHelper::validateNetmask( errors, netmask ) unless ApplicationHelper.null?( netmask )
    errors.add( "Invalid Gateway '#{default_gateway}'" ) unless checkField( default_gateway )
    errors.add( "Invalid Primary DNS Server '#{dns_1}'" ) unless checkField( dns_1 )
    errors.add( "Invalid Secondary DNS Server '#{dns_2}'" ) unless checkField( dns_2 )

    errors.each { |e,f| logger.debug( e + " " + f ) }
  end

  def checkField( field )
    ## In dynamic, none of the fields are required.
    return true if ApplicationHelper.null?( field )
    
    ## The field is valid if the match is non-nil
    return !IPAddr.parse( field ).nil?
  end
end
