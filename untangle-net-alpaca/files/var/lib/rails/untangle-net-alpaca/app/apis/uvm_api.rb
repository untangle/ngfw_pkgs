class InterfaceApi < ActionWebService::API::Base
  inflect_names false
  
  ## Restart the iptables rules
  api_method :generate_rules, :expects => [], :returns []
  
  ## Commit all of the iptables rules, run this at start to ensure that the uvm scripts are
  ## in /etc/untangle-net-alpaca/iptables-rules.d
  api_method :commit_rules, :expects => [], :returns []
end
