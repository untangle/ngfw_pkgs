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
class UVMFilterNode

    include Proxy

    private
        
        DefaultTimeoutMillis = 600000
    
        # @@factory_lock guards @@factory AND @@uvmReoteContext
        @@factory_lock = Mutex.new
        @@factory = nil
        @@uvmRemoteContext = nil

    public
        def initialize
            @diag = Diag.new(DEFAULT_DIAG_LEVEL)
            @diag.if_level(2) { puts! "Initializing UVMFilterNode..." }
            
            begin
                @@factory_lock.synchronize {
                    if !@@factory
                        @@factory = com.untangle.uvm.client.RemoteUvmContextFactory.factory
                        connect
                    end
                } 
            rescue Exception => ex
                puts! "Error: unable to connect to Remote UVM Context Factory; UVM server may not be running -- " + ex
                raise
            end
                    
            ## This just guarantees that all of the connections are terminated.
            at_exit { @@factory_lock.synchronize { disconnect } }
    
            @diag.if_level(2) { puts! "Done initializing UVMFilterNode..." }
        end

    private
        # Caller MUST have obtained @@factory_lock before calling this method.
        def connect
          ## Just in case
          begin
            @@factory.logout 
          rescue
            ## ignore errors
          end

          # TODO: Add exception handling.    
          @@uvmRemoteContext = @@factory.systemLogin( DefaultTimeoutMillis )
          ## Register the remote context as a proxy.
          register( @@uvmRemoteContext )
          true
        end

        # Caller MUST have obtained @@factory_lock before calling this method.
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

end # UVMFilterNode

