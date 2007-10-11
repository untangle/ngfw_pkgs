require_dependency "os_library/debian/network_manager"

class OSLibrary::Debian::OverrideManager < OSLibrary::OverrideManager
  include Singleton
end
