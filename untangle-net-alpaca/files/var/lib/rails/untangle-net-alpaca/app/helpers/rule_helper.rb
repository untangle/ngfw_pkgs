module RuleHelper
  ## Not using a hash because hashes are not sorted
  FilterTypes = [[ "Source Address".t, "s-addr" ], [ "Destination Address".t, "d-addr" ],
                 [ "Source Port".t, "s-port" ], [ "Destination Port".t, "d-port" ],
                 [ "Source Interface".t, "s-intf" ], [ "Destination Interface".t, "d-intf" ],
                 [ "Time".t, "time" ], [ "Day of Week".t, "day-of-week" ],
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

  Scripts = [ "rule_builder", "rule/textbox", "rule/checkbox", "rule/ip_address", "rule/port", "rule/interface", "rule/day", "rule/time", "rule/protocol" ]
end
