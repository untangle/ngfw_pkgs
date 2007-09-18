## Methods for operating on a particular operaiting system / distribution
module OSLibrary
  ## Key is a unique identifier to distringuish the OS/Kernel/Distribution
  ## If it is nil, it will get the default os.
  def OSLibrary.getOS( key = nil )
    key = key.underscore
    require_dependency( "os_library/#{key}/os.rb" )
    
    key = key.camelize
    return eval( "OSLibrary::#{key}::OS.instance" )
  end

  module Logging
    def logger
      ActionController::Base.logger rescue nil
    end
  end

  ## REVIEW should this go into os_library/os.rb
  module OSBase
    include OSLibrary::Logging

    ## Retrieve a module for the Os
    def manager( name )
      name = name.camelize
      f_name = name.underscore
      base = self.class
      
      while ( !base.nil? && ( base.include?( OSBase )))
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
          
          return eval( "#{fqn}.instance" )
        rescue LoadError => load_error
          logger.warn( "Unable to load the file #{fileName}, #{load_error}" )
        end

        base = base.superclass
      end

      raise LoadError.new( "Unable to load #{name}" )
    end    
  end

  module Manager
    include OSLibrary::Logging
  end
end
