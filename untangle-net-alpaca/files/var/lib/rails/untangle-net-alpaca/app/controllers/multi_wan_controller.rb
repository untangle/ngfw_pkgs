#
# $HeadURL: svn://chef/work/pkgs/untangle-net-alpaca/files/var/lib/rails/untangle-net-alpaca/app/controllers/interface_controller.rb $
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
class MultiWanController < ApplicationController
  def get_settings
    settings = {}
    
    failover_settings = {
      "enabled" => true
    }

    settings["failover_settings"] = failover_settings

    settings["interfaces"] = Interface.find( :all ).sort{ |a,b| a.index <=> b.index }

    ## Array of tests that the user has defined.
    settings["user_tests"] = [{
                                "enabled" => true,
                                "description" => "Ping sonic default gateway",
                                "type" => "ping",
                                "delay" => 5,
                                "timeout" => 3, 
                                "failures" => 7,
                                "params" => { "ping_address" => "1.2.3.4" },
                                "interface" => 1
                              },{
                                "enabled" => true,
                                "description" => "Web request to my web server.",
                                "type" => "http",
                                "delay" => 10,
                                "timeout" => 3, 
                                "failures" => 3,
                                "params" => { "http_url" => "http://www.untangle.com" },
                                "interface" => 2
                              }]

    settings["status"] = [{
                            "start_time" => ( Time.new - 1100 ),
                            "end_time" => ( Time.new - 1000 ),
                            "description" => "Web request to my web server.",
                            "interface" => 1,
                            "online" => true
                          },{
                            "start_time" => ( Time.new - 1400 ),
                            "end_time" => ( Time.new - 1500 ),
                            "description" => "Web request to my web server.",
                            "interface" => 1,
                            "online" => false
                          }]

    settings["uptimes"] = [{
                             "interface" => "-1",
                             "percent" => 100,
                             "duration" => 14,
                             "unit" => "days"
                           },{
                             "interface" => "1",
                             "percent" => 86,
                             "duration" => 12,
                             "unit" => "days"
                           },{
                             "interface" => "2",
                             "percent" => 92,
                             "duration" => 11,
                             "unit" => "days"
                           }]

    json_result( :values => settings )
  end

  def set_settings
    json_result
  end

  alias_method :failover, :extjs
end
