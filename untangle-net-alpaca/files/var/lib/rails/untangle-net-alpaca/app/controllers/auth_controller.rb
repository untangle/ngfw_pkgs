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
require "pam_auth"

class AuthController < ApplicationController
  ## REVIEW : This should be configurable
  AlpacaGroups = [ "alpaca", "root", "admin" ]

  ## Page to redirect to on a fresh login.
  DefaultPage = { :controller => "network" }

  ## Indicate that you do not need to be authenticated to view these pages.
  def authentication_required
    false
  end

  def index
    login
    render( :action => 'login' )
  end

  def login
  end
  
  def logout
    if session[:username].nil?
      session[:return_to] = nil
      return request_login 
    end
  end
  
  ## Check a users credentials and then log them in
  def check_credentials
    ## Clear out the existing username
    session[:username] = nil

    credentials = params[:credentials]
    if ( credentials.nil? )
      credentials = {}
    end
    username = credentials[:username]
    password = credentials[:password]

    if ( ApplicationHelper.null?( username  )|| ApplicationHelper.null?( password ))
      return request_login( "Specify a username and password" ) 
    end

    unless PamAuth.new( "rails" ).authenticate( username, password )
      return request_login( "Invalid username or password" )
    end

    ## Validate that the user is in the correct group.
    groups = AlpacaGroups
    groups = [ "root" ] if ( groups.nil? || groups.empty? )

    if `groups #{username} | awk '/:.*(#{groups.join("|")})/ { print $1 }'`.strip.empty?
      ## Review: Should we send this message?
      return request_login( "'#{username}' is not allowed to administer the box." )
    end
      
    session[:username] = username
    return_to = session[:return_to] 
    session[:return_to] = nil

    logger.debug "Returning to default " + url_for( DefaultPage ) if ApplicationHelper.null?( return_to )

    return redirect_to( url_for( DefaultPage ) ) if ApplicationHelper.null?( return_to )

    logger.debug "Returning to: #{return_to}"
    redirect_to( return_to )
  end

  def end_session
    session[:username] = nil
    
    redirect_to( url_for( DefaultPage ) )
  end

  private

  def request_login( msg = nil )
    logger.debug msg
    flash[:warning] = msg  unless msg.nil?
    login
    render :action => 'login'
  end
end
