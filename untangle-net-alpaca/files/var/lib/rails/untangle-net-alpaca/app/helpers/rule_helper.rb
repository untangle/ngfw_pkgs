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
module RuleHelper
  ## Not using a hash because hashes are not sorted
  FilterTypes = [[ "Source Address".t, "s-addr" ], 
                 [ "Destined Local".t, "d-local" ], [ "Destination Address".t, "d-addr" ],
                 [ "Source Port".t, "s-port" ], [ "Destination Port".t, "d-port" ],
                 [ "Source Interface".t, "s-intf" ],
                 ## Destination interface is too tricky to handle, and
                 ## it doesn't provide a lot of benefit.
                 ## [ "Destination Interface".t, "d-intf" ],
                 ## Time is presently not supported.
                 ## [ "Time".t, "time" ], [ "Day of Week".t, "day-of-week" ],
                 [ "Protocol".t, "protocol" ]]
  
  DayOfWeek = [[ "sunday", "Sunday".t ],
               [ "monday", "Monday".t ],
               [ "tuesday", "Tuesday".t ],
               [ "wednesday", "Wednesday".t ],
               [ "thursday", "Thursday".t ],
               [ "friday", "Friday".t ],
               [ "saturday", "Saturday".t ]]

  DayOfWeekJavascript = DayOfWeek.map { |d| "new Array( '#{d[0]}', '#{d[1]}' )" }.join( ", " )
  
  ProtocolList = [[ "icmp", "icmp".t ],
                  [ "tcp", "tcp".t ],
                  [ "udp", "udp".t ],
                  [ "gre", "gre".t ],
                  [ "esp", "esp".t ],
                  [ "ah", "ah".t ],
                  [ "sctp", "sctp".t ]]

  ProtocolListJavascript = ProtocolList.map { |d| "new Array( '#{d[0]}', '#{d[1]}' )" }.join( ", " )

  Scripts = [ "rule_builder" ]

  ## This is used to separate each parameter in a rule
  Separator = "&&"
  
  ## This is used to separate the type from the parameter
  TypeSeparator = "::"
  

  # Returns a list of interfaces and an array of
  def self.get_edit_fields( params )
    interfaces = Interface.find( :all )
    interfaces.sort! { |a,b| a.index <=> b.index }

    ## REVIEW.
    ## (UVM dependent) VPN Special case
    interfaces << Interface.new( :index => 8, :name => "VPN" )
    
    ## This is a javascript array of the interfaces
    interfaces = interfaces.map { |i| "new Array( '#{i.index}', '#{i.name.t}' )" }

    filters = params[:filters]

    unless ApplicationHelper.null?( filters )
      parameter_list = filters.split( Separator ).map do |f| 
        rule = Rule.new
        rule.parameter, rule.value = f.split( TypeSeparator )
        rule
      end
    end

    if ( parameter_list.nil? || parameter_list.empty? )
      r = Rule.new
      r.parameter, r.value = FilterTypes[0][1], ""
      parameter_list = [r]
    end

    [ interfaces, parameter_list ]
  end

  def self.is_valid_port?( port_str )
    port = port_str.to_i
    return false if ( port.to_s != port_str )
    return false if (( port < 0 ) || ( port > 0xFFFF ))
    return true
  end
end
