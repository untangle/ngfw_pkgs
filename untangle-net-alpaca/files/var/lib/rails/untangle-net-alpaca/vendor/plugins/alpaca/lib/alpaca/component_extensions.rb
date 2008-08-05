module Alpaca::ComponentExtensions
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

      ## logger.debug( "Found the class #{klazz}" )
      @components << klazz.new( self, params, session, request )
    end
  end
end

ActionController::Base.send :include, Alpaca::ComponentExtensions
