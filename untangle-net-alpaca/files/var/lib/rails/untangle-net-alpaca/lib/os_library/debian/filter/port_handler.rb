## Handle for the Port based filtering
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
class OSLibrary::Debian::Filter::PortHandler
  include Singleton

  def handle( parameter, value, filters )
    is_src = ( parameter == 's-port' )
    
    if ( value.include?( "-" ))
      range_start, range_end, extra = value.split( "-" )
      raise "invalid range #{value}" unless extra.nil?
      
      raise "Invalid range start '#{range_start}'" unless RuleHelper.is_valid_port?( range_start )
      raise "Invalid range end '#{range_end}'" unless RuleHelper.is_valid_port?( range_end )

      ## Create a multiport rule to match the range.
      filters[parameter] = "#{match( parameter)} #{range_start}:#{range_end}"
    else
      value.split( "," ).each { |p| raise "Invalid port '#{p}'" unless RuleHelper.is_valid_port?( p )}
      filters[parameter] = "#{match( parameter)} #{value}"
    end
  end

  def parameters
    [ "s-port", "d-port" ]
  end
  
  def match( parameter )
    match = "-m multiport "
    return "#{match} --source-ports " if ( parameter == "s-port" )
    return "#{match} --destination-ports "
  end
end
  
