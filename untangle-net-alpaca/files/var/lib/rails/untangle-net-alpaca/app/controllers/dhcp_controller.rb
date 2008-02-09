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
  def index
    manage
    render :action => 'manage'
  end

  def create_static_entry
    @static_entry = DhcpStaticEntry.new
    if ! params[:mac_address].nil? && ! params[:ip_address].nil?
      @static_entry.mac_address = params[:mac_address]
      @static_entry.ip_address = params[:ip_address]
      @static_entry.description = params[:description]
    end
  end

  def manage
    @dhcp_server_settings = DhcpServerSettings.find( :first )
    @dhcp_server_settings = DhcpServerSettings.new if @dhcp_server_settings.nil?
    manage_entries
    if ! Interface.valid_dhcp_server?
      flash[:warning] = "DHCP Server is configured on a subnet that is not on any configured interfaces."
    end
  end

  def manage_entries
    @dhcp_server_settings = DhcpServerSettings.find( :first )
    @dhcp_server_settings = DhcpServerSettings.new if @dhcp_server_settings.nil?
    @static_entries = DhcpStaticEntry.find( :all )

    @static_entries = @static_entries.sort_by { |a| IPAddr.parse(a.ip_address).to_i }
    ## Retrieve all of the dynamic entries from the DHCP server manager
    refresh_dynamic_entries
  end

  def static_entries_json
    static_entries = DhcpStaticEntry.find( :all )
    json = ApplicationHelper.active_record_to_json( static_entries )
    render :json => json
  end
  
  def dynamic_entries_json
    dynamic_entries = os["dhcp_server_manager"].dynamic_entries
    json = ApplicationHelper.active_record_to_json( dynamic_entries )
    render :json => json
  end

  def save
    ## Review : Internationalization
    return redirect_to( :action => "manage" ) if ( params[:commit] != "Save".t )

    dhcp_server_settings = DhcpServerSettings.find( :first )
    dhcp_server_settings = DhcpServerSettings.new if dhcp_server_settings.nil?
    dhcp_server_settings.update_attributes( params[:dhcp_server_settings] )
    dhcp_server_settings.save
    
    os["dhcp_server_manager"].commit

    save_entries
    ## Review : should have some indication that is saved.
    return redirect_to( :action => "manage" )
  end

  def save_entries
    static_entry_list = []
    indices = params[:static_entries]
    mac_addresses = params[:mac_address]
    ip_addresses = params[:ip_address]
    descriptions = params[:description]

    position = 0
    unless indices.nil?
      indices.each do |key|
        dse = DhcpStaticEntry.new
        dse.mac_address, dse.ip_address, dse.description = mac_addresses[key], ip_addresses[key], descriptions[key]
        dse.position, position = position, position + 1
        static_entry_list << dse
      end
    end

    DhcpStaticEntry.destroy_all
    static_entry_list.each { |dse| dse.save }

    os["dhcp_server_manager"].commit
    #return redirect_to( :action => "manage_entries" )
  end

  def refresh_dynamic_entries
    ## Retrieve all of the dynamic entries from the DHCP server manager
    @dynamic_entries = os["dhcp_server_manager"].dynamic_entries 
    @dynamic_entries = @dynamic_entries.sort_by { |a| IPAddr.new(a.ip_address).to_i }   
  end

  def stylesheets
    [] ## [ "dhcp/static-entry", "dhcp/dynamic-entry", "borax/list-table" ]
  end

  def scripts
    [] ## [ "dhcp_server_manager" ] 
  end
end
