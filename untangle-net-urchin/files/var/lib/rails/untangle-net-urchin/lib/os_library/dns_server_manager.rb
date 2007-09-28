class OSLibrary::DnsServerManager
  include OSLibrary::Manager
  
  ## This should commit and update all of the packet filter settings.
  def commit
    raise "base class, override in an os specific class"
  end
end
