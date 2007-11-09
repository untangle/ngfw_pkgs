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

class Router < UVMFilterNode
  include CmdDispatcher
  include RetryLogin

  ERROR_NO_FILTER_NODES = "No Router modules are installed on the effective server."
  UVM_NODE_NAME = "untangle-node-router"
  NODE_NAME = "Router"
  MIB_ROOT = UVM_FILTERNODE_MIB_ROOT + ".7"

  def initialize
    @diag = Diag.new(DEFAULT_DIAG_LEVEL)
    @diag.if_level(3) { puts! "Initializing #{get_node_name()}..." }
    super
    @diag.if_level(3) { puts! "Done initializing #{get_node_name()}..." }
  end
  
  def get_uvm_node_name()
    UVM_NODE_NAME
  end
  
  def get_node_name()
    NODE_NAME
  end
  
  def get_mib_root()
    MIB_ROOT
  end  
  
  def execute(args)
    # TODO: BUG: if we don't return something the client reports an exception
    @diag.if_level(3) { puts! "Router::execute(#{args.join(', ')})" }

    begin
      retryLogin {
        # Get tids of all protocol filters once and for all commands we might execute below.
        tids = get_filternode_tids(get_uvm_node_name())
        if empty?(tids) then return (args[0] == "snmp") ? nil : ERROR_NO_FILTER_NODES ; end

        begin
          tid, cmd = *extract_tid_and_command(tids, args, ["snmp"])
        rescue InvalidNodeNumber, InvalidNodeId => ex
            msg = ERROR_INVALID_NODE_ID + ": " + ex
            @diag.if_level(3) { puts! msg ; p ex}
            return msg
        rescue Exception => ex
          msg = "Error: #{get_node_name} has encountered an unhandled exception: " + ex
          @diag.if_level(3) { puts! msg ; p ex}
          return msg
        end
        @diag.if_level(3) { puts! "TID = #{tid}, command = #{cmd}" }

        if cmd.nil? then
          return list_filternodes(tids)
        else
          return dispatch_cmd(args.empty? ? [cmd, tid] : [cmd, tid, *args])
        end
      }
    rescue Exception => ex
      msg = "Error: #{get_node_name} has encountered an unhandled exception"
      @diag.if_level(3) { puts! msg ; puts! ex; puts! ex.backtrace }
      return msg + ": #{ex}"
    end    
  end

  protected
  def cmd_help(tid, *args)
    return <<-HELP
-- To be implemented.
    HELP
  end

  def cmd_list(tid)
  end

  def cmd_snmp(tid, *args)
    get_statistics(tid, args)
  end

  def cmd_stats(tid, *args)
    get_statistics(tid, args)
  end

end
