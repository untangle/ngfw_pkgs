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
require 'configelem'

class Restore < UVMConfigElement

  def initialize
    @diag = Diag.new(DEFAULT_DIAG_LEVEL)
    @diag.if_level(3) { puts! "Initializing #{get_node_name()}..." }
    super
    @diag.if_level(3) { puts! "Done initializing #{get_node_name()}..." }
  end
  
  def get_node_name()
    "Restore"
  end
  
  protected
    def get_help_text()
      return <<-HELP
- restore from <filename[.backup]>
    -- Restore #{BRAND} server settings from local file.
    HELP
    end

    def cmd_from_file(*args)
      return restore_from_file(*args)
    end

    def restore_from_file(*args)
      if (args.length < 1)
          msg = ERROR_INCOMPLETE_COMMAND
          @diag.if_level(3) { puts! msg }
          return msg
      elsif !File.exist?(args[0]) && !File.exist?("#{args[0]}.backup")
          msg = "Backup file '#{args[0]}' not found, nor was '#{args[0]}.backup' - can't restore."
          @diag.if_level(3) { puts! msg }
          return msg
      end
      
      begin
        filename = !File.exist?(args[0]) && File.exist?("#{args[0]}.tgz") ? "#{args[0]}.tgz" : args[0]
        @@uvmRemoteContext.restoreBackup(filename)
        msg = "Restoration of #{BRAND} server settings from '#{filename}' complete."
        @diag.if_level(3) { puts! msg }          
        return msg
      rescue Exception => ex
        msg = "Error: unable to open/read '#{filename}': " + ex
        @diag.if_level(3) { puts! msg }
        return msg
      end
    end
end

