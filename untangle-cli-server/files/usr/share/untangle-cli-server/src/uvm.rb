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
require 'filternode'

class Uvm < UVMFilterNode
  include CmdDispatcher
  include RetryLogin
  
  NODE_NAME = "uvm"
  UVM_MIB_ROOT = UVM_FILTERNODE_MIB_ROOT + ".0"

  def initialize
    @diag = Diag.new(DEFAULT_DIAG_LEVEL)
    @diag.if_level(3) { puts! "Initializing #{get_node_name()}..." }
    super
    @diag.if_level(3) { puts! "Done initializing #{get_node_name()}..." }
  end
  
  def get_uvm_node_name()
    NODE_NAME
  end
  
  def get_node_name()
    "UVM"
  end
  
  def get_mib_root()
    UVM_MIB_ROOT
  end  
  
  def execute(args)
    # TODO: BUG: if we don't return something the client reports an exception
    @diag.if_level(3) { puts! "Protofilter::execute(#{args.join(', ')})" }

    begin
      retryLogin {
        # Get tids of all protocol filters once and for all commands we might execute below.
        tids = get_filternode_tids(get_uvm_node_name())
        if empty?(tids) then return (args[0] == "snmp") ? nil : ERROR_NO_PROTOFILTER_NODES ; end

        begin
          tid, cmd = *extract_tid_and_command(tids, args, ["snmp"])
        rescue InvalidNodeNumber, InvalidNodeId => ex
            msg = ERROR_INVALID_NODE_ID + ": " + ex
            @diag.if_level(3) { puts! msg ; p ex}
            return msg
        rescue Exception => ex
          msg = "Error: protofilter encountered an unhandled exception: " + p
        end
        @diag.if_level(3) { puts! "TID = #{tid}, command = #{cmd}" }

        return dispatch_cmd(args.empty? ? [cmd, tid] : [cmd, tid, *args])
      }
    rescue Exception => ex
      @diag.if_level(3) { puts! ex; puts! ex.backtrace }
      return "Uncaught exception #{ex}"
    end    
  end

  # What should the deault UVM command do?  Return info about the UVM node?
  def cmd_(*args)
    return "There is no default command for 'uvm'"
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
  end

end
