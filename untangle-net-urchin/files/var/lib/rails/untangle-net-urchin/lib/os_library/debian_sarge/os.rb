require_dependency "os_library/debian/os"

class OSLibrary::DebianSarge::OS < OSLibrary::Debian::OS
  include OSLibrary::OSBase
  include Singleton
end
