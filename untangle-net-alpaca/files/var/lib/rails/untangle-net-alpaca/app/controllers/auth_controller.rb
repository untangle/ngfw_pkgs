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
