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

  ## Wizard helper routines
  api_method :wizard_start, :expects => [], :returns => []

  ## save external interface as a static address
  # @param ip
  # @param netmask
  # @param default_gateway
  # @param dns_1
  # @param dns_2
  api_method( :wizard_external_interface_static, :expects => [:string, :string, :string, :string, :string], 
              :returns => [] )

  ## save external interface for Dynamic
  api_method( :wizard_external_interface_dynamic, :expects => [], :returns => [] )

  ## save external interface for PPPoE
  # @param username
  # @param password
  api_method( :wizard_external_interface_pppoe, :expects => [:string, :string], :returns => [] )

  ## save internal interface as a bridge.
  api_method( :wizard_internal_interface_bridge, :expects => [], :returns => [] )

  ## setup the internal interface for NAT.
  # @param ip
  # @param netmask
  # @param dhcp_start
  # @param dhcp_end
  # @param suffix (dns suffix)
  api_method( :wizard_internal_interface_nat, :expects => [:string, :string, :string, :string, :string], 
              :returns => [] )

end
