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
class NetworkRoute < ActiveRecord::Base
  def validate
    unless target && ApplicationHelper.ip_address?( target )
      errors.add( :target, "is missing or invalid" )
    end
    
    unless netmask && ApplicationHelper.ip_address?( netmask )
      errors.add( :netmask, "is missing or invalid" )
    end

    unless gateway && ApplicationHelper.ip_address?( gateway )
      errors.add( :gateway, "is missing or invalid" )
    end

    #unless name && ApplicationHelper.description?( name )
    #  errors.add( :name, "is missing or invalid" )
    #end
  end

  def NetworkRoute.get_active( os )
    return os["routes_manager"].get_active
  end
end
