class OSLibrary::Debian::NetworkManager
  include Singleton
  include OSLibrary::Manager

  def interfaces
    logger.debug( "Running inside of the network manager for debian" )
  end
end
