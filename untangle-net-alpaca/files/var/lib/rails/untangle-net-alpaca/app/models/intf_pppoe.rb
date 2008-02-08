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
class IntfPppoe < ActiveRecord::Base
  HiddenPassword = "        "
  def accept( interface, visitor )
    visitor.intf_pppoe( interface, self )
  end

  def password=( pass )
    if ( pass != IntfPppoe::HiddenPassword )
      write_attribute( :password, pass )
    else
      logger.debug( "Ignoring password set to HiddenPassword" )
    end
  end

  def hidden_password
    pass = read_attribute( :password )
    if pass.nil? || pass.length == 0
      return ""
    end
    return IntfPppoe::HiddenPassword
  end

end
