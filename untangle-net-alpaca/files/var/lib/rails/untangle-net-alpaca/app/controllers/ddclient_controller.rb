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
class DdclientController < ApplicationController
  def index
    manage
    render :action => 'manage'
  end

  def manage
    @ddclient_settings = DdclientSettings.find( :first )
    @ddclient_settings = DdclientSettings.new if @ddclient_settings.nil?
  end

  def save
    ## Review : Internationalization
    return redirect_to( :action => "manage" ) if ( params[:commit] != "Save".t )

    ddclient_settings = DdclientSettings.find( :first )
    ddclient_settings = DdclientSettings.new if ddclient_settings.nil?
    ddclient_settings.update_attributes( params[:ddclient_settings] )
    ddclient_settings.save
    
    os["ddclient_manager"].commit

    ## Review : should have some indication that is saved.
    return redirect_to( :action => "manage" )
  end

end
