class OSLibrary::DhcpManager < Alpaca::OS::ManagerBase  
  ## This is the current DHCP configuration on an interface.
  ## To retrieve this, use get_dhcp_status( os_name )
  class DhcpStatus
    Unset = "unset"
    def initialize( ip = Unset, netmask = Unset, default_gateway = Unset, dns_1 = Unset, dns_2 = Unset )
      @ip = ( ip.nil? ) ? Unset : ip
      @netmask = ( netmask.nil? ) ? Unset : netmask
      @default_gateway = ( default_gateway.nil? ) ? "" : default_gateway
      @dns_1 = ( dns_1.nil? ) ? Unset : dns_1
      @dns_2 = ( dns_2.nil? ) ? Unset : dns_2
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
