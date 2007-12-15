class OSLibrary::PackageManager < Alpaca::OS::ManagerBase
  include Singleton
  def installed?( package )
    return false
  end
  def install( package )
    return false
  end
end
