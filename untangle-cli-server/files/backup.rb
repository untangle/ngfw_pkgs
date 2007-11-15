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

class Backup < UVMRemoteApp
  include CmdDispatcher
  include RetryLogin

  def initialize
    @diag = Diag.new(DEFAULT_DIAG_LEVEL)
    @diag.if_level(3) { puts! "Initializing #{get_node_name()}..." }
    super
    @diag.if_level(3) { puts! "Done initializing #{get_node_name()}..." }
  end
  
  def get_node_name()
    "Backup"
  end
  
  def execute(args)
    # TODO: BUG: if we don't return something the client reports an exception
    @diag.if_level(3) { puts! "#{get_node_name}::execute(#{args.join(', ')})" }

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
- backup to_disk
    -- Backup ${BRAND} server settings on the server's local hard drive.
- backup to_usb
    -- Backup ${BRAND} server settings on the server's USB-key drive.
- backup to_file filename
    -- Backup ${BRAND} server settings to <filename> on the calling system.
    HELP
    end

    def cmd_to_disk(*args)
      backup_to_disk()
    end

    def cmd_to_usb(*args)
      backup_to_usb()
    end
  
    def cmd_to_file(*args)
      backup_to_file()
    end

    def backup_to_disk()
      begin
        @@uvmRemoteContext.localBackup()
      rescue Exception => ex
        msg = "Error: local backup failed"
        @diag.if_level(3) { puts! msg; puts! ex; puts! ex.backtrace }          
        return msg + ": #{ex}"
      end
      return "Backup to #{BRAND} server local disk complete."
    end

    def backup_to_usb()
      begin
        @@uvmRemoteContext.usbBackup()
      rescue Exception => ex
        msg = "Error: USB-key backup failed"
        @diag.if_level(3) { puts! msg; puts! ex; puts! ex.backtrace }          
        return msg + ": #{ex}"
      end
      return "Backup to #{BRAND} server USB-key complete."
    end

    def backup_to_file()
      begin
        settings = @@uvmRemoteContext.createBackup() # returns byte array but we can't send this Java type back to a Ruby client.
        @diag.if_level(3) { puts! "create backup succeeded." }          
        res = "" # so, convert byte array to raw string so we can pass it back via DRb.
        settings.each {|s| res << s } 
        @diag.if_level(3) { puts! "conversion from byte[] to string succeeded." }          
        return res
      rescue Exception => ex
        msg = "Error: failed to obtain backup data from server."
        @diag.if_level(3) { puts! msg; puts! ex; puts! ex.backtrace }          
        return nil
      end
      return nil
    end

end

