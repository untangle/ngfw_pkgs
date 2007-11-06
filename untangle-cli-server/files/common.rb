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
module NUCLICommon

DEFAULT_DIAG_LEVEL = 3
BRAND = "Untangle"

# Shared error messages & strings - Perhaps we'll package these another way.
ERROR_INCOMPLETE_COMMAND = "Error: incomplete command -- missing required arguments (see help.)"
ERROR_UNKNOWN_COMMAND = "Error: unknown command"
ERROR_COMMAND_FAILED = "Error: unable to execute command"
ERROR_INVALID_NODE_ID = "Error: invalid node identifier"

# Exceptions
class UserCancel < Interrupt
end

# Ruby "extensions"
module Kernel
    private
        # returns the name of the method that calls 'this_method'
        def this_method
            caller[0] =~ /`([^']*)'/ and $1
        end
end
    
end # UCLICommon

module CmdDispatcher
  #
  # Calls a method for processing the specified command.
  #
  # The name of the method should be the command name prefixed with _prefix_.
  # The command name is defined to be the first element of the _args_ array.
  # The remaining elements will be used as paramaters to the method call
  #
  
  protected
  def dispatch_cmd(args, prefix = "cmd")
    catch :unknown_command do
      return dispatch_cmd_helper(prefix, args)
    end
    return ERROR_UNKNOWN_COMMAND + " -- '#{args.join(' ')}'"
  end

  private
  def dispatch_cmd_helper(prefix, args)
    cmd_name = args.empty? ? "" : args[0]
    new_args = args[1..-1]
    full_name = "#{prefix}_#{cmd_name}"
    matches = candidates(full_name)
    if respond_to?(full_name) and (new_args.empty? or candidates("#{full_name}_#{new_args[0]}") == 0) then
      begin
        return send(full_name, *new_args)
      rescue ArgumentError => ex
        @diag.if_level(3) {
          puts! "Dispatching failure: " + full_name + "(" + new_args.inspect  + ")"
          puts! ex
          puts! ex.backtrace
        }
        return ERROR_INCOMPLETE_COMMAND
      end
    elsif matches > 0 and args.length > 0
      return dispatch_cmd_helper(full_name, new_args)
    end
    throw :unknown_command
  end
  
  def candidates(cmd_name)
    methods.select { |m| m =~ /^#{cmd_name}/ }.length
  end
end



module RetryLogin

  # ***Ken says... Aaron Read (another of our engineers) thinks this belongs at a lower level of the UVM API.  I'll
  # review this with him and get back to you :)
  # 
  # Runs the asociated block. If the block throws an LoginExpiredException, it logs in
  # and runs the block again.
  def retryLogin
    retried = false
    begin
      yield
    rescue com.untangle.uvm.client.LoginExpiredException => ex
      if !retried
        retried = true
        @diag.if_level(2) { puts! "Login expired - logging back on and trying one more time" ; p ex }
        @@filter_node_lock.synchronize { login }
        retry
      else
        raise
      end
    end
  end
end

