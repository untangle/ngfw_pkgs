# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base
  layout "main"

  DefaultTitle = "Untangle Net Alpaca"
  
  # Pick a unique cookie name to distinguish our session data from others'
  session :session_key => '_untangle-net-alpaca_session_id'
  
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
end
