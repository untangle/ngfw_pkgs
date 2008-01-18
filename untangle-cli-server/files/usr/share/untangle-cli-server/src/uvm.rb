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

class Uvm < UVMRemoteApp
  include CmdDispatcher
  
  #UVM_MIB_ROOT = UVM_FILTERNODE_MIB_ROOT + ".0"

  def initialize
    @@diag.if_level(3) { puts! "Initializing UVM..." }
    super
    @@diag.if_level(3) { puts! "Done initializing UVM..." }
  end
  
  #def get_mib_root()
    #UVM_MIB_ROOT
  #end  
  
  def execute(args)
    # TODO: BUG: if we don't return something the client reports an exception
    @@diag.if_level(3) { puts! "Uvm::execute(#{args.join(', ')})" }

    begin
      retryLogin {
    	return "There is no default command for 'uvm'" if args.empty?
	cmd = args.shift
        return dispatch_cmd([cmd, nil, *args])
      }
    rescue Exception => ex
      @@diag.if_level(3) { puts! ex; puts! ex.backtrace }
      return "Uncaught exception #{ex}"
    end    
  end

  # What should the deault UVM command do?  Return info about the UVM node?
  def cmd_(*args)
  end
  
  def cmd_kill_all_sessions(*args)
    return kill_all_sessions()
  end
  
  protected
  def cmd_help(tid, *args)
    return <<HELP
- uvm kill all sessions 
    -- Terminate/kill all open UVM network user sessions.
HELP
  end

  # Kill all network sessions currently active on the effective UVM server.
  def kill_all_sessions(policy=nil)
	pMgr = @@uvmRemoteContext.policyManager()
	pMgr.shutdownSessions(nil)
	return "Kill all sessions request sent to #{BRAND} server."
  end

end

