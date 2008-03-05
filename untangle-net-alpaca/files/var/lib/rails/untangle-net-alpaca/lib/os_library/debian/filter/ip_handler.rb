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
class OSLibrary::Debian::Filter::IPHandler
  include Singleton
  
  def handle( parameter, value, filters )
    is_src = ( parameter == 's-addr' )
    if ( value.include?( "-" ))
      range_start, range_end, extra = value.split( "-" )
      raise "invalid range #{value}" unless extra.nil?
      range_start = IPAddr.new( "#{range_start}/32" )
      range_end = IPAddr.new( "#{range_end}/32" )
      filters[parameter] = "-m iprange --#{is_src ? "src" : "dst"}-range #{range_start}-#{range_end}"
    elsif ( value.include?( "," ))
      ## This will be significantly improved by using IPset.
      filters[parameter] = value.split( "," ).uniq.map do |ip|
        IPAddr.new( ip )
        ## Review ( support - )
        filters[parameter] = "--#{is_src ? "source" : "destination"} #{ip}"
      end
    else
      ## just verify that it parses
      IPAddr.new( value )
      filters[parameter] = "--#{is_src ? "source" : "destination"} #{value}"
    end
  end

  def parameters
    [ "s-addr", "d-addr" ]
  end
end
