class UvmController < ApplicationController  
  def manage
  end

  def generate_rules
    ## Execute all of the packet filter rules.
    os["packet_filter_manager"].run_services
  end
  
  def commit_rules
    ## Commit all of the packet filter rules.
    os["packet_filter_manager"].commit    
  end
end
