# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base
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
    menu_organizer.flush
    menu_organizer.register_item( "/main", Alpaca::Menu::Item.new( 0, "Main Menu", "#blank", "layouts/main_menu" ))
    
    Dir.new( "#{RAILS_ROOT}/app/controllers" ).each do |controller|
      next if /_controller.rb$/.match( controller ).nil?
      
      ## convert the string to camel caps, and strip of the rb
      controller = controller.sub( /.rb$/, "" ).camelize
      
      ## Load the manager for this os, this will complete all of the initialization at
      klazz = Module.const_get( controller ) rescue next

      logger.debug "found #{controller} #{klazz}"

      controller = klazz.new
      next unless controller.methods.include?( RegisterMenuMethod )
      controller.send( RegisterMenuMethod )
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
end
