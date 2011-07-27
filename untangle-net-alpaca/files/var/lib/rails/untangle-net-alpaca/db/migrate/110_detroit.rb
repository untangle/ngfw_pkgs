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
class Detroit < Alpaca::Migration
  def self.up
    alpaca_settings = AlpacaSettings.find( :first )

    # If the settings aren't nil this is an upgrade
    if !alpaca_settings.nil?
      modules_disabled = alpaca_settings.modules_disabled
      modules_disabled = "" if modules_disabled.nil?
      modules_enabled = alpaca_settings.modules_enabled
      modules_enabled = "" if modules_enabled.nil?
      sip_helper_enabled = !modules_disabled.include?( "nf_nat_sip" ) || !modules_disabled.include?( "nf_conntrack_sip" )

      if (sip_helper_enabled) 
        # the new default is disabled
        # if its enabled, it now needs to be explicitly enabled
        print "SIP helper was enabled - migrating settings\n"
        modules_enabled += " nf_nat_sip nf_conntrack_sip "
        alpaca_settings.modules_enabled = modules_enabled.strip
      end
      if (!sip_helper_enabled) 
        # the new default is disabled
        # if its disabled, it now doesn't need to be explicitly disabled
        print "SIP helper was disabled - migrating settings\n"
        modules_disabled = modules_disabled.gsub( "nf_nat_sip", "" )
        modules_disabled = modules_disabled.gsub( "nf_conntrack_sip", "" )
        alpaca_settings.modules_disabled = modules_disabled.strip
      end
      alpaca_settings.save

      change_column_default(:alpaca_settings, :modules_disabled, "")
      change_column_default(:alpaca_settings, :modules_enabled, "")
    end

  end

  def self.down
  end

end
