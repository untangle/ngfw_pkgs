# -*-ruby-*-
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

# Determines the linux distribution we're running on.
class Alpaca::OS::OSUtils
  def self.distribution
    File.open("/etc/issue") { |f|
      issue = f.readline.split(' ')
      if issue[0] == "Debian"
        verindex = 2
      else
        verindex = 1
      end
      return case issue[verindex]
        when "3.1"       then "debian_sarge"
        when "4.0"       then "debian_etch"
        when "lenny/sid" then "debian_sid"
        when /7\.10.*/   then "ubuntu_gutsy"
        when /8\.04.*/   then "ubuntu_hardy"
        else
          logger.warn( "Unable to determine OS, assuming sarge" )
          "debian_sarge"
        end
    }
  end
end      
