# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.
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

class ApplicationController < ActionController::Base
  @components = nil

  #layout "main"
  layout proc { |controller| controller.request.xhr? ? 'ajax' : 'main' }

  DefaultTitle = "Untangle Net Alpaca"

  RegisterMenuMethod = "register_menu_items"

  filter_parameter_logging "password"
  filter_parameter_logging "ddclient_settings"
  filter_parameter_logging "credentials"
  filter_parameter_logging "argyle"
  
  # Pick a unique cookie name to distinguish our session data from others'
  session :session_key => '_untangle-net-alpaca_session_id', :secret => "guess what everyone is going to share the same secret."

  ## Disable all calls to the API, these are RPC calls.
  session :off, :if => Proc.new { |req| req.path_parameters[:action] == "api" }
  
  ## This has to happen first, since the menu depends on this.
  before_filter :set_config_level
  
  before_filter :build_menu_structure

  ## Perhaps this should be disabled in Production mode
  before_filter :reload_managers
  ## This is disabled until we switch to ruby gettext.
  ## before_filter :setLocale
  before_filter :setStylesheets
  
  before_filter :setScripts
  before_filter :setButtons

  before_filter :update_activity_time, :except => :session_expiry
  before_filter :instantiate_controller_and_action_names
  before_filter :authenticate

  MAX_SESSION_TIME = 30

  def update_activity_time
    #logger.debug( "update_activity_time called"  )
    if !session[:expires_at].nil? && session[:expires_at] < Time.now
      reset_session
    end
    session[:expires_at] = MAX_SESSION_TIME.minutes.from_now
    return true
  end

  def session_expiry
    @time_left = ( session[:expires_at] - Time.now ).to_i
    unless @time_left > 0
      reset_session
      #redict_to( '/' ) this doesn't work
    end
  end

  def set_config_level
    @alpaca_settings = AlpacaSettings.find( :first )
    if @alpaca_settings.nil?
      @alpaca_settings = AlpacaSettings.new
      @alpaca_settings.config_level = AlpacaSettings::Level::Basic.level
      @alpaca_settings.save
    end

    @config_level = @alpaca_settings.get_config_level
  end

  ## This is disabled until we switch to ruby gettext.
  def setLocale
    settings = LocaleSetting.find( :first )
    
    ## Do nothing if the value doesn't exist, this way it will go to the default setting
    Locale.set( settings.key ) unless settings.nil?
  end
  
  def instantiate_controller_and_action_names
    $current_action = action_name
    $current_controller = controller_name
  end 
  

  def setStylesheets
    @stylesheets = ( self.respond_to?( "stylesheets" )) ? stylesheets : [ ]
    @stylesheets << "rack.css"
    @stylesheets << "simple-table.css"

    @skin_stylesheets = [ "/../ext/resources/css/ext-all.css", 
                          "/../skins/default/css/ext-skin.css", "/../skins/default/css/user.css" ]
  end
  
  def setScripts
    @extjs_scripts = [ "/../ext/source/core/Ext.js", "/../ext/source/adapter/ext-base.js",
                       "/../ext/ext-all-debug.js", "/../script/i18n.js" ]

    @alpaca_scripts = [ "e/application", "e/util", "e/page_panel", "e/editor_grid_panel", "e/glue", "e/toolbar" ]

    @javascripts = []
    @javascripts = [ self.scripts ].flatten if self.respond_to?( "scripts" )

    @javascripts.concat( RuleHelper::Scripts )

    @javascripts = @javascripts.uniq
  end

  def setButtons
    @buttons = [ "Help", "Cancel", "Save" ]
  end

  ## Build the menu structure
  def build_menu_structure
    ## No need to waste time builing the menu for an API call
    return if ( request.path_parameters[:action] == "api" )

    menu_organizer = Alpaca::Menu::Organizer.instance
    menu_organizer.flush
    menu_organizer.register_item( "/main", Alpaca::Menu::Item.new( 0, "Main Menu", "#blank", "layouts/main_menu" ))
    
    iterate_components do |component|
      next unless component.respond_to?( RegisterMenuMethod )
      component.send( RegisterMenuMethod, menu_organizer, @config_level )
    end
  end

  ## Reload all of the managers if necessary
  def reload_managers
    Dir.new( "#{RAILS_ROOT}/lib/os_library" ).each do |manager|
      next if /_manager.rb$/.match( manager ).nil?
      
      ## Load the manager for this os, this will complete all of the initialization at
      os["#{manager.sub( /.rb$/, "" )}"]
    end
  end
  
  def authenticate
    ## Nothing needed if authentication is not required on this page.
    return unless authentication_required

    ## Nothing to do if the user is already authenticated
    return if ( session_enabled? && !session[:username].nil? )

    ## Check if they have a nonce
    argyle = params[:argyle]

    unless argyle.nil? || argyle.empty?
      nonces=`head -n 2 /etc/untangle-net-alpaca/nonce 2>/dev/null`.strip.split
      
      ## Test the parameter against the nonce.
      nonces.each do |n| 
        next unless argyle == n.strip
        
        ## This way, they don't have to be authenticated again
        session[:username] = "nonce-authenticated" if session_enabled?

        ## Return indicating that it succeeded
        return
      end
    end
    
    ## Only allowed to use the username/password if the session is disabled.
    unless session_enabled?
      ## Return a page indicating access is denied
      render :nothing => true, :status => 401
      return false
    end

    if session[:username].nil?
      session[:return_to] = request.request_uri
      if request.xhr?
        render :template => "auth/login", :layout => "ajax"
      else
        redirect_to :controller => "auth"
      end
      return false
    end
  end

  ## override to indicate that authentication is not required.
  def authentication_required
    true
  end


  def extjs
    render :template => "application/page", :layout => "extjs"
  end
  
#   unless defined? redirect_to
#     def redirect_to( options = {}, *parameters_for_method_reference )
#       #   case options
#       #   when String
#       logger.debug( "redirecting to url_for: " + url_for( options ) )
#       url = url_for( options ).split( request.host_with_port )[1]
#       if url.nil? or url.length == 0
#         return super( options, *parameters_for_method_reference )
#       end
#       response.redirect( url )
#       response.redirected_to = url
#       @performed_redirect = true
#       #    else
#       #      super( options, *parameters_for_method_reference )
#       #    end
#     end
#   end
  
  def json_params
    a = params[controller_name]
    return  ( a.length == 1 and a[0].is_a?( ::Hash )) ? a[0] : a
  end

  def json_result( *values )
    options = nil
    options = values[0].delete(:options) if values[0].is_a?( ::Hash )
    options = {} if options.nil?

    values = values[0] if ( values.length == 1 and ( values[0].is_a?( ::Hash ) or values[0].is_a?( ::Array )))

    response = { "status" => "success" }
    response["result"] = values unless values.empty?

    unless options[:no_i18n_map]
      response["i18n_map"] = {}
    end

    render :json =>  response.to_json
  end

  def json_error( message, *values )
    values = values[0] if ( values.length == 1 and values[0].is_a?( ::Hash ))
    
    render :json => { "error" => message, "result" => values }.to_json
  end
end
