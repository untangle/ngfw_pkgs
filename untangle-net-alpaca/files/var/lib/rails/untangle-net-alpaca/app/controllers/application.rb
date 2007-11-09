# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base
  @components = nil

  layout "main"

  DefaultTitle = "Untangle Net Alpaca"

  RegisterMenuMethod = "register_menu_items"
  
  # Pick a unique cookie name to distinguish our session data from others'
  session :session_key => '_untangle-net-alpaca_session_id'
  
  before_filter :build_menu_structure
  before_filter :reload_managers
  before_filter :setLocale
  before_filter :setStylesheets
  before_filter :setScripts
  before_filter :authenticate
  
  def setLocale
    settings = LocaleSetting.find( :first )
    
    ## Do nothing if the value doesn't exist, this way it will go to the default setting
    Locale.set( settings.key ) unless settings.nil?
  end

  def setStylesheets
    @stylesheets = []
    begin
      @stylesheets = stylesheets
    rescue
    end
  end
  
  def setScripts
    @scripts = []
    begin
      @scripts = scripts
    rescue
    end
  end

  ## Build the menu structure
  def build_menu_structure
    menu_organizer = Alpaca::Menu::Organizer.instance
    menu_organizer.flush
    menu_organizer.register_item( "/main", Alpaca::Menu::Item.new( 0, "Main Menu", "#blank", "layouts/main_menu" ))
    
    iterate_components do |component|
      next unless component.methods.include?( RegisterMenuMethod )
      component.send( RegisterMenuMethod, menu_organizer )
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

    if session[:username].nil?
      session[:return_to] = @request.request_uri
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
      @components << klazz.new( params, session, request )
    end
  end
end
