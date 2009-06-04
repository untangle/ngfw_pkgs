#
# $HeadURL: svn://chef/work/pkgs/untangle-net-alpaca/files/var/lib/rails/untangle-net-alpaca/app/controllers/firewall_controller.rb $
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
class PacketFilterController < ApplicationController
  def get_settings
    settings = {}
    settings["user_rules"] = Firewall.find( :all, :conditions => [ "system_id IS NULL" ] )
    settings["system_rules"] = Firewall.find( :all, :conditions => [ "system_id IS NOT NULL" ] )

    ## Interface enumeration
    settings["interface_enum"] = build_interface_enum()

    json_result( :values => settings )
  end

  def set_settings
    s = json_params

    ## Destroy all of the user rules
    Firewall.destroy_all( "system_id IS NULL" )
    position = 0
    s["user_rules"].each do |entry|
      rule = Firewall.new( entry )
      rule.position = position
      rule.save
      position += 1
    end
    
    s["system_rules"].each do |entry|
      rule = Firewall.find( :first, :conditions => [ "system_id = ?", entry["system_id"]] )
      next if rule.nil?
      rule.enabled = entry["enabled"]
      rule.save
    end

    ## Commit all of the packet filter rules.
    os["packet_filter_manager"].commit
    
    json_result
  end

  alias_method :index, :extjs
end
