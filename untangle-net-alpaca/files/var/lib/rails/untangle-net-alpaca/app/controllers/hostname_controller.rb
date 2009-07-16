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
class HostnameController < ApplicationController
  def get_settings
    settings = {}

    hostname_settings =  HostnameSettings.find( :first )
    hostname_settings = HostnameSettings.new if hostname_settings.nil?
    settings["hostname_settings"] = hostname_settings

    ddclient_settings = DdclientSettings.find( :first )
    ddclient_settings = DdclientSettings.new if ddclient_settings.nil?
    ddclient_settings["password"] = ApplicationHelper::PASSWORD_STRING
    settings["ddclient_settings"] = ddclient_settings

    ## Need the possible values for the combobox.
    settings["ddclient_services"] = OSLibrary::DdclientManager::ConfigService.map { |k,v| k }
    
    ## Dns server settings used to load the search domain.
    dns_server_settings = DnsServerSettings.find( :first )
    dns_server_settings = DnsServerSettings.create_default if dns_server_settings.nil?
    settings["dns_server_settings"] = dns_server_settings
    
    json_result( :values => settings )
  end
  
  def set_settings
    s = json_params
    
    hostname_settings = HostnameSettings.find( :first )
    hostname_settings = HostnameSettings.new if hostname_settings.nil?
    hostname_settings.attributes =  s["hostname_settings"]
    
    ## Validate the hostname
    return json_error( "Invalid hostname" ) unless validator.is_hostname?( hostname_settings.hostname )

    ddclient_settings = DdclientSettings.find( :first )
    ddclient_settings = DdclientSettings.new if ddclient_settings.nil?
    if ( s["ddclient_settings"]["password"] == ApplicationHelper::PASSWORD_STRING )
      s["ddclient_settings"].delete( "password" )
    end
        
    ddclient_settings.attributes = s["ddclient_settings"]
    if ( ddclient_settings.hostname.nil?() ||
         ( ddclient_settings.hostname.length() == 0 ))
      ddclient_settings.hostname = hostname_settings.hostname
    end

    dns_server_settings = DnsServerSettings.find( :first )
    dns_server_settings = DnsServerSettings.create_default if dns_server_settings.nil?
    dns_server_settings.attributes = s["dns_server_settings"]

    ## Validate the hostname suffix
    return json_error( "Invalid DNS suffix" ) unless validator.is_hostname?( dns_server_settings.suffix )

    hostname_settings.save
    ddclient_settings.save
    dns_server_settings.save

    os["hostname_manager"].commit

    json_result
  end
  
  alias_method :index, :extjs
end
