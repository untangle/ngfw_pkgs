#
# $HeadURL$
# Copyright (c) 2007-2008 Untangle, Inc.
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
module Spawn
  
  # Forks off a long-running section of code and returns the PID of the child process.
  # By default spawn will detach from the child process.   If you want to wait for the 
  # child then call spawn with the option :detach => false and use Process.wait with
  # the returned PID.  Beware that if you use :detach => false and don't wait for or
  # detach from the child then you will leave zombie processes behind.
  def spawn(options = {})
    options.symbolize_keys!
    # The problem with rails is that it only has one connection, so when we fork
    # a new process, we need to reconnect.   I couldn't figure out a more reliable way
    # to do it than this.   It would be better if we only made a new connection in the
    # child process but that doesn't seem to work reliably.
    spec = ActiveRecord::Base.remove_connection
    child = fork do
      ActiveRecord::Base.establish_connection(spec)
      begin
        # run the block of code that takes so long
        yield
      ensure
        ActiveRecord::Base.remove_connection
      end
      # this form of exit doesn't call at_exit handlers
      exit!
    end
    # by default, we will detach unless :detach => false is passed in
    if options[:detach] != false  # (nil || true)
      Process.detach(child)
    end
    # reconnect in the parent process
    ActiveRecord::Base.establish_connection(spec)
    return child
  end

end
