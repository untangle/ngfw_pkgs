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

require 'filternode'
require 'common'

class Support < UVMFilterNode
  include CmdDispatcher
  include RetryLogin

  def initialize
    @diag = Diag.new(DEFAULT_DIAG_LEVEL)
    @diag.if_level(3) { puts! "Initializing #{get_node_name()}..." }
    super
    @diag.if_level(3) { puts! "Done initializing #{get_node_name()}..." }
  end
  
  def get_uvm_node_name()
    return "Error: this is not a UVM node."
  end
  
  def get_node_name()
    "Support"
  end
  
  def get_mib_root()
    raise Exception, "Error: #{get_node_name()} does not offer SNMP support."
  end  
  
  def execute(args)
    # TODO: BUG: if we don't return something the client reports an exception
    @diag.if_level(3) { puts! "Support::execute(#{args.join(', ')})" }

    begin
      retryLogin {
        return dispatch_cmd(args)
      }
    rescue Exception => ex
      @diag.if_level(3) { puts! ex; puts! ex.backtrace }
      return "Error: Unhandled exception -- " + ex
    end    
  end

  protected
    def cmd_help(tid, *args)
      return <<-HELP
- support allow access [true|false]
    -- Query the value of Support Access Restrictions "Allow" setting - change value to [true|false] if provided.
- support allow send [true|false]
    -- Query the value of Support Access Restrictions "Send" setting - change value to [true|false] if provided.
    HELP
    end

    def cmd_allow_access(*args)
      allow_access(*args)
    end
  
    def allow_access(*args)
      settings = @@uvmRemoteContext.networkManager().getAccessSettings()
      if args.length > 0
        begin
          settings.setIsSupportEnabled(validate_bool(args[0], "access"))
          @@uvmRemoteContext.networkManager().setAccessSettings(settings)
        rescue Exception => ex
          @diag.if_level(3) { puts! ex; puts! ex.backtrace }          
          return ex
        end
      end
      msg = "Support access is #{ settings.getIsSupportEnabled() ? 'allowed.' : 'not allowed.'}"
      @diag.if_level(3) { puts! msg }          
      return msg
    end

end
