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
class QosController < ApplicationController
  def get_settings
    settings = {}

    qos_settings = QosSettings.find( :first )
    qos_settings = QosSettings.new if qos_settings.nil?
    settings["qos_settings"] = qos_settings
    
    settings["qos_rules"] = QosRule.find( :all )
    settings["bandwidth"] = os["qos_manager"].estimate_bandwidth_v2
    settings["status"] = os["qos_manager"].status_v2
    settings["start_time"] = os["qos_manager"].start_time

    json_result( :values => settings )
  end

  def get_statistics
    json_result( :values => os["qos_manager"].status_v2 )
  end
  
  def set_settings
    s = json_params
    
    qos_settings = QosSettings.find( :first )
    qos_settings = QosSettings.new if qos_settings.nil?
    qos_settings.update_attributes( s["qos_settings"] )
    qos_settings.save

    QosRule.destroy_all
    position = 0
    s["qos_rules"].each do |entry| 
      qos_rule = QosRule.new( entry )
      qos_rule.position = position
      position += 1
      qos_rule.save
    end

    os["packet_filter_manager"].commit

    json_result
  end

  alias_method :index, :extjs
end
