## Handler for interface based filtering
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
class OSLibrary::Debian::Filter::IntfHandler
  include OSLibrary::Debian::Filter
  include Singleton
  
  def handle( parameter, value, filters )    
    ## Indicate which marks should be set
    intf_marks = value.split( "," ).uniq.map do |index|
      n = index.to_i
      raise "invalid index #{index}" if n.to_s != index
      raise "invalid index #{index}" if (( n > 8 ) || ( n < 1 ))

      ## The mask is 0xff
      [ n, 0xff ]
    end

    filters["mark"] = Mark.expand( filters["mark"], intf_marks )
  end

  def parameters
    [ "s-intf" ]
  end
end
