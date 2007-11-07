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

class Support < UVMRemoteApp
  include CmdDispatcher
  include RetryLogin

  def initialize
    @diag = Diag.new(DEFAULT_DIAG_LEVEL)
    @diag.if_level(3) { puts! "Initializing #{get_node_name()}..." }
    super
    @diag.if_level(3) { puts! "Done initializing #{get_node_name()}..." }
  end
  
  def get_node_name()
    "Upgrade"
  end
  
  def execute(args)
    # TODO: BUG: if we don't return something the client reports an exception
    @diag.if_level(3) { puts! "#{get_node_name}::execute(#{args.join(', ')})" }

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
- upgrade automatic [true|false]
    -- Query the value of Upgrade "Automatically install..." setting - change value to [true|false], if provided.
- upgrade schedule sunday|monday|...|saturday hours:minutes
    -- Query the values of Upgrade schedule - change schedule to given values, if provided (all must be given to change any one value.)
    HELP
    end

    def cmd_automatic(*args)
      automatic(*args)
    end
  
    def cmd_schedule(*args)
      schedule(*args)
    end
  
    def automatic(*args)
      if args.length > 0
        begin
          settings = @@uvmRemoteContext.toolboxManager().getUpgradeSettings()  
          settings.setAutoUpgrade(validate_bool(args[0], "autoupgrade"))
          @@uvmRemoteContext.toolboxManager().setUpgradeSettings(settings)
        rescue Exception => ex
          msg = "Error: unable to upgrade schedule to '#{args.join}'"
          @diag.if_level(3) { puts! msg; puts! ex; puts! ex.backtrace }          
          return msg + ": #{ex}"
        end
      end
      settings = @@uvmRemoteContext.toolboxManager().getUpgradeSettings()
      msg = "Upgrade automatically is #{settings.setAutoUpgrade() ? 'enabled.' : 'disabled.'}"
      @diag.if_level(3) { puts! msg }          
      return msg
    end

    def schedule(*args)
      if args.length > 0
        begin
          settings = @@uvmRemoteContext.toolboxManager().getUpgradeSettings()  
          period = settings.getPeriod()
          sched = args.join
          period.setSunday(sched =~ /sun/i ? true : false)
          period.setMonday(sched =~ /mon/i ? true : false)
          period.setTuesday(sched =~ /tuen/i ? true : false)
          period.setWednesday(sched =~ /wed/i ? true : false)
          period.setThursday(sched =~ /thu/i ? true : false)
          period.setFriday(sched =~ /fri/i ? true : false)
          period.setSaturday(sched =~ /sat/i ? true : false)
          if args[-1] && (args[-1] =~ /^\d+:\d+$/)
            at = args[-1].split(':')
            period.setHour(at[0].to_i)
            period.setMinute(at[1].to_i)
          end
          settings.setPeriod(period)
          @@uvmRemoteContext.toolboxManager().setUpgradeSettings(settings)
        rescue Exception => ex
          msg = "Error: unable to upgrade schedule to '#{args.join(' ')}' (check command syntax via help)"
          @diag.if_level(3) { puts! msg; puts! ex; puts! ex.backtrace }          
          return msg + ": #{ex}"
        end
      end
      settings = @@uvmRemoteContext.toolboxManager().getUpgradeSettings()
      period = settings.getPeriod()
      p period
      msg = "Upgrade schedule: "
      msg << "#{!period.getSunday() ? '' : 'Sun '}"
      msg << "#{!period.getMonday() ? '' : 'Mon '}"
      msg << "#{!period.getTuesday() ? '' : 'Tue '}" 
      msg << "#{!period.getWednesday() ? '' : 'Wed '}"
      msg << "#{!period.getThursday() ? '' : 'Thu '}"
      msg << "#{!period.getFriday() ? '' : 'Fri '}"
      msg << "#{!period.getSaturday() ? '' : 'Sat '}"
      msg << "@ #{period.getHour() > 12 ? period.getHour()-12 : period.getHour()}:#{period.getMinute() > 9 ? period.getMinute() : "0" + period.getMinute().to_s} (#{period.getHour() >= 12 ? "PM" : "AM"})"
      @diag.if_level(3) { puts! msg }          
      return msg
    end

end

