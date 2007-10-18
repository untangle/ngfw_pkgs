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

# Local exception definitions
class FilterNodeException < Exception
end
class FilterNodeAPIVioltion < FilterNodeException
end
class InvalidNodeNumber < Exception
end
class InvalidNodeId < Exception
end

class UVMFilterNode

    include Proxy

    protected

        UVM_FILTERNODE_MIB_ROOT = ".1.3.6.1.4.1.2021.1234"
        
        DefaultTimeoutMillis = 600000
        
        # @@filternode_lock guards @@factory AND @@uvmReoteContext
        @@filternode_lock = Mutex.new
        @@factory = nil
        @@uvmRemoteContext = nil

    protected
        # Caller MUST have obtained @@filternode_lock before calling this method.
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

    protected
        def login
            @@uvmRemoteContext = @@factory.systemLogin( DefaultTimeoutMillis )
        end
        
    protected
        # Caller MUST have obtained @@filternode_lock before calling this method.
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
    
    protected
        # Given a filter node command request in the standard format, e.g., filternode [#X|Y] command
        # return a 2 element array conposed of the effective tid and command and strip these items
        # from the provided args array.
        def extract_tid_and_command(tids, args)
            if /^#\d+$/ =~ args[0]
                begin
                    node_num = $&[1..-1].to_i()
                    raise FilterNodeException if (node_num < 1) || (node_num > tids.length)
                    tid = tids[node_num-1]
                    cmd = args[1]
                    args.shift
                    args.shift
                rescue Exception => ex
                    raise InvalidNodeNumber, "#{args[0]}"
                end
            elsif /^\d+$/ =~ args[0]
                begin
                    rtid = $&.to_i
                    node_num = -1
                    tid = tids.detect { |jtid|
                        node_num += 1
                        rtid.to_s == jtid.to_s  # rtid is a ruby int, jtid is Java OBJECT - can't compare directly so use to_s
                    }
                    raise ArgumentError unless tid
                    cmd = args[1]
                    args.shift
                    args.shift
                rescue Exception => ex
                    raise InvalidNodeId, "#{args[0]}"
                end
            else
                cmd = args[0]
                tid = tids[0]
                args.shift
            end
            
            return [tid, cmd]
        end

    public
        def initialize
            @diag = Diag.new(DEFAULT_DIAG_LEVEL)
            @diag.if_level(2) { puts! "Initializing UVMFilterNode..." }
            
            begin
                @@filternode_lock.synchronize {
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
            at_exit { @@filternode_lock.synchronize { disconnect } }
    
            @diag.if_level(2) { puts! "Done initializing UVMFilterNode..." }
        end

    public
        # If derived class does not override this method then its not a valid filter node.
        def execute(args)
            raise FilterNodeAPIVioltion, "Filter nodes does not implement the required 'execute' method"
        end

        

end # UVMFilterNode

