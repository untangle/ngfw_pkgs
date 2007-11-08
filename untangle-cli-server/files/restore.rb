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

class Restore < UVMRemoteApp
  include CmdDispatcher
  include RetryLogin

  def initialize
    @diag = Diag.new(DEFAULT_DIAG_LEVEL)
    @diag.if_level(3) { puts! "Initializing #{get_node_name()}..." }
    super
    @diag.if_level(3) { puts! "Done initializing #{get_node_name()}..." }
  end
  
  def get_node_name()
    "Restore"
  end
  
  def execute(args)
    # TODO: BUG: if we don't return something the client reports an exception
    # @diag.if_level(3) { puts! "#{get_node_name}::execute(#{args.join(', ')})" }

    begin
      retryLogin {
        return args.empty? ? ERROR_INCOMPLETE_COMMAND : dispatch_cmd(args, false)
      }
    rescue Exception => ex
      @diag.if_level(3) { puts! ex; puts! ex.backtrace }
      return "Error: Unhandled exception -- " + ex
    end    
  end

  protected
    def cmd_help(tid)
      return <<-HELP
- restore from <filename[.backup]>
    -- Restore ${BRAND} server settings from local file.
    HELP
    end

    def cmd_from(*args)
      return restore_from_file(*args)
    end

    def restore_from_file(*args)
      begin
        puts! "Restore from file."
        bytes = Array.new(args[0].length).to_java :byte
        i = 0
        args[0].each_byte { |b| bytes[i] = b ; i += 1; }
        @@uvmRemoteContext.restoreBackup(bytes)
        msg = "Restoration of #{BRAND} server settings from file complete."
        @diag.if_level(3) { puts! msg; puts! ex; puts! ex.backtrace }          
        return msg + ": #{ex}"
      rescue Exception => ex
        msg = "Error: restore of server settings from file failed."
        @diag.if_level(3) { puts! msg; puts! ex; puts! ex.backtrace }          
        return msg + ": #{ex}"
      end
    end

end

