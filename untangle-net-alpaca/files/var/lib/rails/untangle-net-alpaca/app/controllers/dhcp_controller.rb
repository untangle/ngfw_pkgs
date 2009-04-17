## REVIEW This should be renamed to dhcp_server_controller.
## REVIEW Should create a consistent way to build these tables.
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
class DhcpController < ApplicationController
  def get_settings
    warnings = []
    settings = { "warnings" => warnings }

    dhcp_server_settings = DhcpServerSettings.find( :first )
    dhcp_server_settings = DhcpServerSettings.new if dhcp_server_settings.nil?

    if dhcp_server_settings.enabled == true and \
        ( dhcp_server_settings.start_address.nil? \
          or dhcp_server_settings.end_address.nil? \
          or dhcp_server_settings.start_address.length == 0 \
          or dhcp_server_settings.end_address.length == 0 )
      warnings << "DHCP::StartAndEndRequired"
    elsif ! Interface.valid_dhcp_server?
      warnings << "DHCP::IncorrectSubnet"
    end

    settings["dhcp_server_settings"] = dhcp_server_settings

    settings["dhcp_static_entries"] = DhcpStaticEntry.find( :all )

    if ( dhcp_server_settings.enabled )
      settings["dhcp_dynamic_entries"] = os["dhcp_server_manager"].dynamic_entries
    else
      settings["dhcp_dynamic_entries"] = []
    end

    json_result( :values => settings )
  end
  
  def set_settings
    s = json_params
    
    ## Check for duplicate MAC Addresses
    mac_addresses = {}
    ip_addresses = {}
    static_entries = s["dhcp_static_entries"]
    unless static_entries.nil?
      static_entries.each do |se|
        ma, ip = se["mac_address"], se["ip_address"]
        return json_error( "Duplicate MAC Address '%s'" % (ma)) unless mac_addresses[ma].nil?
        return json_error( "Duplicate IP Address '%s'" % (ip)) unless ip_addresses[ip].nil?
        mac_addresses[ma] = 0
        ip_addresses[ip] = 0
      end

      DhcpStaticEntry.destroy_all
      static_entries.each { |entry| DhcpStaticEntry.new( entry ).save }
    end
    
    dhcp_server_settings = DhcpServerSettings.find( :first )
    dhcp_server_settings = DhcpServerSettings.new if dhcp_server_settings.nil?
    dhcp_server_settings.update_attributes( s["dhcp_server_settings"] )
    dhcp_server_settings.save

    os["dhcp_server_manager"].commit
    
    json_result
  end

  def get_leases
    json_result( :values =>os["dhcp_server_manager"].dynamic_entries )
  end
  
  alias_method :index, :extjs

  alias_method :secret_field, :extjs
end
