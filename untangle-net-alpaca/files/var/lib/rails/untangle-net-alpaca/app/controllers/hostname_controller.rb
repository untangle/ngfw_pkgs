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
  def manage
    @hostname_settings = HostnameSettings.find( :first )

    @hostname_settings = HostnameSettings.new if @hostname_settings.nil?
    
    if ApplicationHelper.null?( @hostname_settings.hostname )
      @hostname_settings.hostname = os["hostname_manager"].current
    end

    @ddclient_settings = DdclientSettings.find( :first )
    @ddclient_settings = DdclientSettings.new if @ddclient_settings.nil?

    ## Dns server settings used to load the search domain.
    @dns_server_settings = DnsServerSettings.find( :first )
    @dns_server_settings = DnsServerSettings.create_default if @dns_server_settings.nil?

    ## this allows this method to be aliased.
    render :action => 'manage'
  end

  def save
    ## Review : Internationalization
    return redirect_to( :action => "manage" ) if ( params[:commit] != "Save".t )

    hostname_settings = HostnameSettings.find( :first )
    hostname_settings = HostnameSettings.new if hostname_settings.nil?
    hostname_settings.attributes =  params[:hostname_settings]

    ## Validate the hostname
    return redirect_to( :action => "manage" ) unless validator.is_hostname?( hostname_settings.hostname )

    hostname_settings.save
    
    ddclient_settings = DdclientSettings.find( :first )
    ddclient_settings = DdclientSettings.new if ddclient_settings.nil?
    ddclient_settings.update_attributes( params[:ddclient_settings] )
    if ( params[:ddclient_settings][:hostname].nil?() ||
         params[:ddclient_settings][:hostname].length() == 0 )
      ddclient_settings.hostname = hostname_settings.hostname
    end
    ddclient_settings.save

    dns_server_settings = DnsServerSettings.find( :first )
    dns_server_settings = DnsServerSettings.create_default if dns_server_settings.nil?
    dns_server_settings.attributes = params[:dns_server_settings]

    ## Validate the hostname suffix
    return redirect_to( :action => "manage" ) unless validator.is_hostname?( dns_server_settings.suffix )

    dns_server_settings.save

    os["hostname_manager"].commit

    ## Review : should have some indication that is saved.
    return redirect_to( :action => "manage" )
  end

  alias :index :manage
end
