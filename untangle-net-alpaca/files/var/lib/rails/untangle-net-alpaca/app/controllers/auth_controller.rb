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

  def do_login
    s = json_params
    
    v = verify_account( s["username"], s["password"] )
    unless ( v == true )
      return json_error( v )
    end

    path = session[:return_to]
    path = "/alpaca/network" if path.nil?
    
    json_result( :values => { "path" => path })
  end
  
  alias_method :login, :extjs
  def index
    redirect_to( :action => "login" )
  end
  
  def do_logout
    session[:username] = nil
    session[:return_to] = nil

    json_result
  end

  def logout
    if session[:username].nil?
      session[:return_to] = nil
      return redirect_to( :action => "login" )
    end
    
    extjs
  end
    
  private

  def verify_account( username, password )
    if ( ApplicationHelper.null?( username  )|| ApplicationHelper.null?( password ))
      return "Specify a username and password"
    end
    
    unless PamAuth.new( "rails" ).authenticate( username, password )
      return "Invalid username or password"
    end

    ## Validate that the user is in the correct group.
    groups = AlpacaGroups
    groups = [ "root" ] if ( groups.nil? || groups.empty? )
    # Compatibility with <6.0 and >6.0 coreutils:
    membergroups = `groups #{username}`.sub(/.*:/, "").split;
    if (groups & membergroups).empty?
      ## Review: Should we send this message?
      return "'#{username}' is not allowed to administer the box."
    end
      
    session[:username] = username

    return true
  end  
end
