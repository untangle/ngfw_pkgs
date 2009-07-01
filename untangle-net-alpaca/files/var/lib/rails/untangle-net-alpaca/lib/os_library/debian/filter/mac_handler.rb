## Handle for the IP based filtering
#
# $HeadURL: svn://chef/branch/prod/release-6.2/work/pkgs/untangle-net-alpaca/files/var/lib/rails/untangle-net-alpaca/lib/os_library/debian/filter/ip_handler.rb $
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
class OSLibrary::Debian::Filter::MacHandler
  include Singleton
  
  def handle( parameter, value, filters )
    filters[parameter] = "-m mac --mac-source #{value}"
  end

  def parameters
    [ "s-mac-addr" ]
  end
end
