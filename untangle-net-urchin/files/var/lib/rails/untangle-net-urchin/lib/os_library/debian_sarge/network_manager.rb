require_dependency "os_library/debian/network_manager"

class OSLibrary::DebianSarge::NetworkManager < OSLibrary::Debian::NetworkManager
  def interfaces
    logger.debug( "Running inside of the network manager for debian sarge" )
  end
end
