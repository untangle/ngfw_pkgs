class OSLibrary::DhcpManager < Alpaca::OS::ManagerBase  
  ## This should commit and update all of the dhcp settings
  def commit
    raise "base class, override in an os specific class"
  end
end
