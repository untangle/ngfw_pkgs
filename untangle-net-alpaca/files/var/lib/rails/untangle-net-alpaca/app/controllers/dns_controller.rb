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
class DnsController < ApplicationController
  def get_settings
    settings = {}

    dns_server_settings = DnsServerSettings.find( :first )
    dns_server_settings = DnsServerSettings.create_default if dns_server_settings.nil?
    
    settings["dns_server_settings"] = dns_server_settings

    settings["dns_static_entries"]
    settings["dns_static_entries"] = DnsStaticEntry.find( :all )

    dhcp_server_settings = DhcpServerSettings.find( :first )
    dhcp_server_settings = DhcpServerSettings.new if dhcp_server_settings.nil?
    settings["dhcp_server_settings"] = dhcp_server_settings

    ## Retrieve all of the dynamic entries from the DHCP server manager
    if ( dns_server_settings.enabled and dhcp_server_settings.enabled )
      settings["dns_dynamic_entries"] = os["dns_server_manager"].dynamic_entries
    else
      settings["dns_dynamic_entries"] = []
    end

    ## Retrieve all of the local dns servers (can reuse this method for local dns)
    settings["upstream_servers"] = DnsUpstreamServers.find( :all )
        
    json_result( :values => settings )
  end

  def set_settings
    s = json_params
    
    dns_server_settings = DnsServerSettings.find( :first )
    dns_server_settings = DnsServerSettings.create_default if dns_server_settings.nil?
    dns_server_settings.update_attributes( s["dns_server_settings"] )
    
    unless validator.is_hostname?( dns_server_settings.suffix )
      return json_error( "Invalid Domain Name Suffix '%s'" % ( dns_server_settings["suffix"] ))
    end

    dns_server_settings.save

    ## Save all of the static entries
    DnsStaticEntry.destroy_all
    s["dns_static_entries"].each { |entry| DnsStaticEntry.new( entry ).save }

    ## Save all of the upstream servers
    DnsUpstreamServers.destroy_all
    s["upstream_servers"].each { |entry| DnsUpstreamServers.new( entry ).save }
    
    os["dns_server_manager"].commit

    json_result
  end
  
  def get_leasese
    dns_server_settings = DnsServerSettings.find( :first )
    dns_server_settings = DnsServerSettings.create_default if dns_server_settings.nil?
    
    dhcp_server_settings = DhcpServerSettings.find( :first )
    dhcp_server_settings = DhcpServerSettings.new if dhcp_server_settings.nil?
    
    leases = []
    if ( dns_server_settings.enabled and dhcp_server_settings.enabled )
      leases = os["dns_server_manager"].dynamic_entries
    end
    
    json_result( :values => leases )
  end
  
  alias_method :index, :extjs

  alias_method :local_dns, :extjs    
end
