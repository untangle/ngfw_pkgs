#
# $HeadURL: svn://chef/work/pkgs/untangle-net-alpaca/files/var/lib/rails/untangle-net-alpaca/lib/os_library/arps_manager.rb $
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
class OSLibrary::Null::ArpsManager < OSLibrary::ArpsManager
  include Singleton
  
  ConfigFile = "/etc/untangle-net-alpaca/arps"
  
  def get_active
    results = []
    arp = `arp -n`.split( "\n" )
    number_of_heading_lines = 1
    arp = arp.slice( number_of_heading_lines, arp.length )
    arp.each do |entry|
      items = entry.split
      next if items.length != 5
      a = ActiveArp.new
      a.ip_address = items[0]
      a.mac_address = items[2]
      a.interface = items[4]
      results << a
    end
    return results
  end
  
  def hook_commit
  end

  def hook_write_files
  end
 
  def hook_run_services
  end
end
