class RuleController < ApplicationController
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
  
  ProtocolList = [[ "icmp", "icmp".t ],
                  [ "tcp", "tcp".t ],
                  [ "udp", "udp".t ],
                  [ "gre", "gre".t ],
                  [ "esp", "esp".t ],
                  [ "ah", "ah".t ],
                  [ "sctp", "sctp".t ]]

  def stylesheets
    [ "rule", "borax/list-table" ]
  end

  def scripts
    [ "rule", "rule/ip_address", "rule/port", "rule/interface", "rule/day", "rule/time", "rule/protocol" ]
  end

  def create_parameter
    @list_id = params[:list_id]
    @filter_types = FilterTypes
  end

  def index
    @filter_types = FilterTypes
    interfaces = Interface.find(:all)
    interfaces.sort! { |a,b| a.index <=> b.index }
    ## This is a javascript array of the interfaces
    @interfaces = interfaces.map { |i| "new Array( '#{i.index}', '#{i.name.t}' )" }


    @day_list = DayOfWeek.map { |d| "new Array( '#{d[0]}', '#{d[1]}' )" }
    @protocol_list = ProtocolList.map { |d| "new Array( '#{d[0]}', '#{d[1]}' )" }
  end
end
