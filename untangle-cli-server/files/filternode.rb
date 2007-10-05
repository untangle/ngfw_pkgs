#!/usr/local/bin/ruby
#
# filternode.rb - Base class from which all specific UVM Filter Nodes are derived, e.g., 
# WebFilter, etc.  Contains functionality shared by all such filters.
#
# Copyright (c) 2007 Untangle Inc., all rights reserved.
#
# @author <a href="mailto:ken@untangle.com">Ken Hilton</a>
# @version 0.1
#

require 'ucli_common'
include UCLICommon
require 'ucli_util'
include UCLIUtil

class UVMFilterNode

    include Proxy
    
    DefaultTimeoutMillis = 600000

    attr_reader :uvmRemoteContext

    def initialize
        @diag = Diag.new(DEFAULT_DIAG_LEVEL)
	@diag.if_level(2) { puts! "Initializing UVMFilterNode..." }
        
        ## Retrieve the factory
        begin
            @factory = com.untangle.uvm.client.RemoteUvmContextFactory.factory
            connect
        rescue Exception
            puts! "Error: unable to connect to Remote UVM Context Factory -- UVM server may not be running."
            raise
        end
                
        ## This just guarantees that all of the connections are terminated.
        at_exit { disconnect }

	@diag.if_level(2) { puts! "Done initializing UVMFilterNode..." }
    end

    #
    # Server support methods
    #
    def connect
      ## Just in case
      begin
        @factory.logout 
      rescue
        ## ignore errors
      end
      
      @uvmRemoteContext = @factory.systemLogin( DefaultTimeoutMillis )
      
      ## Register the remote context as a proxy.
      register( @uvmRemoteContext )
      true
    end

    def disconnect
      return if @uvmRemoteContext.nil?
      begin
        @factory.logout
      rescue
        ## ignore errors
      end
      @uvmRemoteContext = nil
      true
    end

end # UVMFilterNode

