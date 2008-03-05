## Handle for the IP based filtering
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
class OSLibrary::Debian::Filter::LocalHandler
  include OSLibrary::Debian::Filter
  include Singleton
  
  def handle( parameter, value, filters )
    filters["chain"] = "INPUT"

    ## Also indicate the mark that should be set
    m = OSLibrary::Debian::PacketFilterManager::MarkInput
    filters["mark"] = Mark.expand( filters["mark"], [[ m, m ]] )
  end

  def parameters
    [ "d-local" ]
  end
end
