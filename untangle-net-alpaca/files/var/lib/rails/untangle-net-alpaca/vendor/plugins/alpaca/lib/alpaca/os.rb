require "singleton"

module Alpaca::OS
  include Logging

  @@current_os = nil

  def []( name )
    manager( name )
  end
  
  def manager( name )
    name = name.camelize
    f_name = name.underscore
    base = self.class
    
    while ( !base.nil? && ( base.include?( Alpaca::OS )))
      fileName = "#{base.name.underscore.sub( /os$/, f_name )}.rb"
      success = false
      
      begin
        require_dependency( fileName )
        
        ## This is the fully qualified name of the manager
        fqn = base.name.sub( /OS$/, name )

        ## Have to return the object
        ## The eval is the lesser of the two evals
        # b = Module
        # fqn.split( "::" ).each { |p| b = b.const_get(  p ) }
        ## assuming it implements singleton
        # return b.instance
          
        manager = eval( "#{fqn}.instance" )

        ## Only return managers.
        return manager if manager.class.include? Alpaca::OS::ManagerBase

        logger.debug( "#{manager} does not include ManagerBase" )
      rescue LoadError => load_error
        logger.warn( "Unable to load the file #{fileName}, #{load_error}" )
      end

      base = base.superclass
    end
      
    raise LoadError.new( "Unable to load them OS Manager #{name}" )
  end

  def self.included( current_os )
    logger.warn( "Redefining the OS" ) unless @@current_os.nil?

    ## Force it to include singleton
    current_os.send :include, Singleton unless current_os.include?( Singleton )

    @@current_os = current_os.instance
  end

  def self.current_os
    raise LoadError.new( "An OS is presently not selected" ) if @@current_os.nil?

    ## Return the current os.
    @@current_os
  end
  
end
