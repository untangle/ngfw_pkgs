class OSLibrary::DnsServerManager < Alpaca::OS::ManagerBase
  class DynamicEntry
    def initialize( ip_address, hostname )
      @ip_address, @hostname = ip_address, hostname
    end
    
    attr_reader :ip_address, :hostname

    ## compare the ip addresses of the two entries
    def <=>( o )
      @ip_address <=> o.ip_address
    end
  end
  
  def dynamic_entries
    raise "base class, override in an os specific class"
  end

  def commit
    raise "base class, override in an os specific class"
  end
end
