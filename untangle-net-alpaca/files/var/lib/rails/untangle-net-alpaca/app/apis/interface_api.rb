class InterfaceApi < ActionWebService::API::Base
  inflect_names false
  
  ## Reload all of the addresses
  ## api_method :update_address, :expects => [ { :interface_name => :string }, { :wait_for => :boolean } ], :returns => [ {:status => :boolean }]
end
