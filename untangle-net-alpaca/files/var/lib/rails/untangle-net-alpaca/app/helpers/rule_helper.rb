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

require "gettext"

module RuleHelper
  include GetText

  ## Not using a hash because hashes are not sorted
  FilterTypes = [[ _("Source Address"), "s-addr" ], 
                 [ _("Destined Local"), "d-local" ], [ _("Destination Address"), "d-addr" ],
                 [ _("Source Port"), "s-port" ], [ _("Destination Port"), "d-port" ],
                 [ _("Source Interface"), "s-intf" ],
                 ## Destination interface is too tricky to handle, and
                 ## it doesn't provide a lot of benefit.
                 ## [ _("Destination Interface"), "d-intf" ],
                 ## Time is presently not supported.
                 ## [ _("Time"), "time" ], [ _("Day of Week"), "day-of-week" ],
                 [ _("Protocol"), "protocol" ]]
  
  DayOfWeek = [[ "sunday", _("Sunday") ],
               [ "monday", _("Monday") ],
               [ "tuesday", _("Tuesday") ],
               [ "wednesday", _("Wednesday") ],
               [ "thursday", _("Thursday") ],
               [ "friday", _("Friday") ],
               [ "saturday", _("Saturday") ]]

  DayOfWeekJavascript = DayOfWeek.map { |d| "new Array( '#{d[0]}', '#{d[1]}' )" }.join( ", " )
  
  ProtocolList = [[ "tcp", _("tcp") ],
                  [ "udp", _("udp") ],
                  [ "icmp", _("icmp") ],
                  [ "gre", _("gre") ],
                  [ "esp", _("esp") ],
                  [ "ah", _("ah") ],
                  [ "sctp", _("sctp") ]]

  ProtocolListJavascript = ProtocolList.map { |d| "new Array( '#{d[0]}', '#{d[1]}' )" }.join( ", " )

  Scripts = [ "rule_builder" ]

  ## This is used to separate each parameter in a rule
  Separator = "&&"
  
  ## This is used to separate the type from the parameter
  TypeSeparator = "::"
  
  def self.is_valid_port?( port_str )
    port = port_str.to_i
    return false if ( port.to_s != port_str )
    return false if (( port < 0 ) || ( port > 0xFFFF ))
    return true
  end
end
