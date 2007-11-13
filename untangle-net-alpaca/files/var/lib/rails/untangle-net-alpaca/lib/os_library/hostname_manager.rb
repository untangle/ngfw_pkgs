class OSLibrary::HostnameManager < Alpaca::OS::ManagerBase
  ## Retrieve the current hostnanme
  def current
    raise "base class, override in an os specific class"
  end

  def commit
    raise "base class, override in an os specific class"
  end
end

