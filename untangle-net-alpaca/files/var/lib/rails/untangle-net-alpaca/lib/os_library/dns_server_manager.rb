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
class OSLibrary::DnsServerManager < Alpaca::OS::ManagerBase
  class DynamicEntry
    def initialize( ip_address, hostname )
      @ip_address, @hostname = ip_address, hostname
    end
    
    attr_reader :ip_address, :hostname

    ## compare the ip addresses of the two entries
    def <=>( o )
      @ip_address <=> o.ip_address
    end
  end
  
  def dynamic_entries
    raise "base class, override in an os specific class"
  end

  def commit
    raise "base class, override in an os specific class"
  end
end
