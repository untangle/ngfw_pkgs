#
# $HeadURL:$
# Copyright (c) 2003-2007 Untangle, Inc. 
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License, version 2,
# as published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but
# AS-IS and WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE, TITLE, or
# NONINFRINGEMENT.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA.
#
require 'java'
require 'proxy'
require 'debug'
require 'common'
require 'util'
require 'thread'

include NUCLICommon
include NUCLIUtil

#
#   Base class for all NUCLI server UVM objects, i.e., filter nodes and configuration elements.
#
class UVMRemoteApp

    include Proxy

    protected

        DEFAULT_TIMEOUT = 600000
        
        # @@filternode_lock guards @@factory AND @@uvmReoteContext
        @@filternode_lock = Mutex.new
        @@factory = nil
        @@uvmRemoteContext = nil

        @@last_subclass = nil 
  
    public
        def initialize
            @diag = Diag.new(DEFAULT_DIAG_LEVEL)
            @diag.if_level(2) { puts! "Initializing UVMRemoteApp..." }
            
            begin
                if @@factory.nil?
                    @@filternode_lock.synchronize {
                        if @@factory.nil?
                            @@factory = com.untangle.uvm.client.RemoteUvmContextFactory.factory
                            connect
                        end
                    }
                end
            rescue Exception => ex
                puts! "Error: unable to connect to Remote UVM Context Factory; UVM server may not be running -- " + ex
                raise
            end
            
            ## This just guarantees that all of the connections are terminated.
            at_exit { @@filternode_lock.synchronize { disconnect } }
    
            @diag.if_level(2) { puts! "Done initializing UVMRemoteApp..." }
        end

    protected
        def self.inherited(subclass)
          @@last_subclass = subclass
        end

        def self.last_subclass
          @@last_subclass
        end

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
            @@uvmRemoteContext = @@factory.systemLogin( DEFAULT_TIMEOUT )
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
end
