class OSLibrary::DhcpServerManager < Alpaca::OS::ManagerBase
  class DynamicEntry
    def initialize( expiration, mac_address, ip_address, hostname, client_id )
      @expiration, @mac_address, @ip_address, @hostname, @client_id = 
        expiration, mac_address, ip_address, hostname, client_id
    end
    
    attr_reader :expiration, :mac_address, :ip_address, :hostname, :client_id

    ## compare the mac addresses of the two entries
    def <=>( o )
      @mac_address <=> o.mac_address
    end
  end
  
  def dynamic_entries
    raise "base class, override in an os specific class"
  end
end
