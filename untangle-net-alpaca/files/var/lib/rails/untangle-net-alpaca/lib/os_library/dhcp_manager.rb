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
class OSLibrary::DhcpManager < Alpaca::OS::ManagerBase  
  ## This is the current DHCP configuration on an interface.
  ## To retrieve this, use get_dhcp_status( os_name )
  class DhcpStatus
    Unset = ""
    def initialize( ip = Unset, netmask = Unset, default_gateway = Unset, dns_1 = Unset, dns_2 = Unset )
      @ip, @netmask, @default_gateway, @dns_1, @dns_2 = ip, netmask, default_gateway, dns_1, dns_2 
    end

    attr_reader :ip, :netmask, :default_gateway, :dns_1, :dns_2
  end

  ## This should be overriden by the o/s specific value.
  def get_dhcp_status( interface )
    raise "base class, override in an os specific class"
  end

  ## This should commit and update all of the dhcp settings
  def commit
    raise "base class, override in an os specific class"
  end
end
