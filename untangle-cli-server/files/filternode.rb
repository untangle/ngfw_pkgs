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

require 'common'
include NUCLICommon
require 'util'
include NUCLIUtil
require 'thread'

class FilterNodeAPIVioltion < Exception
# TODO: perhaps this should derive from a more specific type of Exception?
end

class UVMFilterNode

    include Proxy

    protected
        DefaultTimeoutMillis = 600000
        # @@filter_node_lock guards @@factory AND @@uvmReoteContext
        @@filter_node_lock = Mutex.new
        @@factory = nil
        @@uvmRemoteContext = nil

    public
        def initialize
            @diag = Diag.new(DEFAULT_DIAG_LEVEL)
            @diag.if_level(2) { puts! "Initializing UVMFilterNode..." }
            
            begin
                @@filter_node_lock.synchronize {
                    if @@factory.nil?
                        @@factory = com.untangle.uvm.client.RemoteUvmContextFactory.factory
                        connect
                    end
                } 
            rescue Exception => ex
                puts! "Error: unable to connect to Remote UVM Context Factory; UVM server may not be running -- " + ex
                raise
            end
                    
            ## This just guarantees that all of the connections are terminated.
            at_exit { @@filter_node_lock.synchronize { disconnect } }
    
            @diag.if_level(2) { puts! "Done initializing UVMFilterNode..." }
        end

    protected
        # Caller MUST have obtained @@filter_node_lock before calling this method.
        def connect
          ## Just in case
          begin
            @@factory.logout 
          rescue
            ## ignore errors
          end

          # TODO: Add exception handling.
          login

          ## Register the remote context as a proxy.
          register @@uvmRemoteContext
          true
        end

        def login
            @@uvmRemoteContext = @@factory.systemLogin( DefaultTimeoutMillis )
        end
        
        # Caller MUST have obtained @@filter_node_lock before calling this method.
        def disconnect
          return if @@uvmRemoteContext.nil?
          begin
            @@factory.logout
          rescue
            ## ignore errors
          end
          @@uvmRemoteContext = nil
          true
        end
    
    public
        # If derived class does not override this method then its not a valid filter node.
        def execute(args)
            raise FilterNodeAPIVioltion, "Filter nodes does not implement the required 'execute' method"
        end
        

end # UVMFilterNode

