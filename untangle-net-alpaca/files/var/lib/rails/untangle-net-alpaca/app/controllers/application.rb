# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base
  include RelativePath

  @components = nil

  layout "main"

  DefaultTitle = "Untangle Net Alpaca"

  RegisterMenuMethod = "register_menu_items"
  
  # Pick a unique cookie name to distinguish our session data from others'
  session :session_key => '_untangle-net-alpaca_session_id'

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

  before_filter :update_activity_time, :except => :session_expiry
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

  def setStylesheets
    @stylesheets = ( self.respond_to?( "stylesheets" )) ? stylesheets : []
  end
  
  def setScripts
    @scripts = ( self.respond_to?( "scripts" )) ? scripts : []
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
      redirect_to :controller => "auth"
      return false
    end
  end

  ## override to indicate that authentication is not required.
  def authentication_required
    true
  end

  ## Useful for iterating all of the component modules.  This is where
  ## Global parameters are set, things like the menu structure and the
  ## initialization functions for the wizard.
  def iterate_components
    load_components if @components.nil?
    
    @components.each { |component| yield( component ) }
  end

  def load_components
    @components = []

    Dir.new( "#{RAILS_ROOT}/lib/alpaca/components" ).each do |component|
      next if /_component.rb$/.match( component ).nil?

      ## convert the string to camel caps, and strip of the rb
      component = component.sub( /.rb$/, "" ).camelize
      
      ## Load the manager for this os, this will complete all of the initialization at
      klazz = Alpaca::Components.const_get( component )

      logger.debug( "Found the class #{klazz}" )
      @components << klazz.new( self, params, session, request )
    end
  end
end
