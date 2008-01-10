class OSLibrary::DhcpManager < Alpaca::OS::ManagerBase  
  ## This is the current DHCP configuration on an interface.
  ## To retrieve this, use get_dhcp_status( os_name )
  class DhcpStatus
    Unset = "&nbsp;"
    def initialize( ip = Unset, netmask = Unset, default_gateway = Unset, dns_1 = Unset, dns_2 = Unset )
      @ip, @netmask, @default_gateway, @dns_1, @dns_2 = ip, netmask, default_gateway, dns_1, dns_2 
    end

    attr_reader :ip, :netmask, :default_gateway, :dns_1, :dns_2
  end

  ## This should be overriden by the o/s specific value.
  def get_dhcp_status( os_name )
    raise "base class, override in an os specific class"
  end

  ## This should commit and update all of the dhcp settings
  def commit
    raise "base class, override in an os specific class"
  end
end
