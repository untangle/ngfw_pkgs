class OSLibrary::UvmManager < Alpaca::OS::ManagerBase
  ## Interface index for the VPN Interface
  VpnIndex = 8

  ## This should commit and update all of the packet filter settings.
  def commit
    raise "base class, override in an os specific class"
  end
end
