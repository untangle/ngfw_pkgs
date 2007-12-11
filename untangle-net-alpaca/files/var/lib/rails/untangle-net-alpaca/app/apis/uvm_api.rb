class UvmApi < ActionWebService::API::Base
  inflect_names false
  
  ## Restart the iptables rules
  api_method :generate_rules, :expects => [], :returns => []
  
  ## Commit all of the iptables rules, run this at start to ensure that the uvm scripts are
  ## in /etc/untangle-net-alpaca/iptables-rules.d
  api_method :commit_rules, :expects => [], :returns => []

  ## Create a new session redirect
  ## Returns a unique identifier to delete the session redirect later.
  api_method :session_redirect_create, :expects => [:string, :string, :integer], :returns => [:boolean]

  ## Delete a session redirect
  api_method :session_redirect_delete, :expects => [:string, :string, :integer], :returns => [:boolean]
end
