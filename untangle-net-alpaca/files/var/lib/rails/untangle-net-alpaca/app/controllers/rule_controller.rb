class RuleController < ApplicationController
  FilterTypes = [[ "Source Address".t, "s-addr" ], [ "Destination Address".t, "d-addr" ],
                 [ "Source Port".t, "s-port" ], [ "Destination Port".t, "d-port" ],
                 [ "Source Interface".t, "s-intf" ], [ "Destination Interface".t, "d-intf" ],
                 [ "Time".t, "time" ], [ "Day of Week".t, "dow" ],
                 [ "Protocol".t, "protocol" ]]

  def stylesheets
    [ "rule/rule", "borax/list-table" ]
  end

  def scripts
    [ "rule", "rule/ip_address", "rule/port", "rule/interface" ]
  end

  def index
    @filter_types = FilterTypes
    interfaces = Interface.find(:all)
    interfaces.sort! { |a,b| a.index <=> b.index }
    ## This is a javascript array of the interfaces
    @interfaces = interfaces.map { |i| "new Array( '#{i.index}', '#{i.name.t}' )" }
  end
end
