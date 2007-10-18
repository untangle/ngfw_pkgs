# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base
  layout "main"

  DefaultTitle = "Untangle Net Alpaca"
  
  # Pick a unique cookie name to distinguish our session data from others'
  session :session_key => '_untangle-net-alpaca_session_id'
  
  before_filter :reload_managers
  before_filter :setLocale
  before_filter :setStylesheets
  before_filter :setScripts
  
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

  ## Reload all of the managers if necessary
  def reload_managers
    logger.debug( " Looking for the directory '#{RAILS_ROOT}/lib/os_library'" )
    Dir.new( "#{RAILS_ROOT}/lib/os_library" ).each do |manager|
      logger.debug( "Checking #{manager}" )
      next if /_manager.rb$/.match( manager ).nil?
      logger.debug( "#{manager} passed" )
      
      ## Load the manager for this os, this will complete all of the initialization at
      os["#{manager.sub( /.rb$/, "" )}"]
    end
  end
end
