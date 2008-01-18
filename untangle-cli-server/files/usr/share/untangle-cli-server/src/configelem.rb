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

require 'remoteapp'

class UVMConfigElement < UVMRemoteApp

    include CmdDispatcher

    public
        def initialize
            @@diag.if_level(3) { puts! "Initializing UVMConfigElement..." }
            
            super
    
            @stats_cache = {}
            @stats_cache_lock = Mutex.new

            @@diag.if_level(3) { puts! "Done initializing UVMConfigElement..." }
        end

    public
        def execute(args)
          # TODO: BUG: if we don't return something the client reports an exception
          @@diag.if_level(3) { puts! "#{get_node_name}::execute(#{args.join(', ')})" }
      
          begin
            retryLogin {
              return args.empty? ? ERROR_INCOMPLETE_COMMAND : dispatch_cmd(args, false)
            }
          rescue Exception => ex
            @@diag.if_level(3) { puts! ex; puts! ex.backtrace }
            return "Error: Unhandled exception -- " + ex
          end    
        end

    protected
        def get_node_name()
            raise NoMethodError, "Derived class of UVMFilterNode does not implement required method 'get_node_name()'"
        end
        
    protected
        def get_help_text()
            raise NoMethodError, "Derived class of UVMFilterNode does not implement required method 'get_help_text()'"
        end

    protected
        def cmd_(*args)
            return ERROR_INCOMPLETE_COMMAND
        end

    protected
        def cmd_help(*args)
            return get_help_text()
        end

end # UVMFilterNode
