require "ipaddr"

class OSLibrary::NetworkManager
  DefaultMTU = 1500
  
  include OSLibrary::Manager
  
  CIDR = {
    "0"  => "0.0.0.0",
    "1"  => "128.0.0.0",
    "2"  => "192.0.0.0",
    "3"  => "224.0.0.0",
    "4"  => "240.0.0.0",
    "5"  => "248.0.0.0",
    "6"  => "252.0.0.0",
    "7"  => "254.0.0.0",
    "8"  => "255.0.0.0",
    "9"  => "255.128.0.0",
    "10" => "255.192.0.0",
    "11" => "255.224.0.0",
    "12" => "255.240.0.0",
    "13" => "255.248.0.0",
    "14" => "255.252.0.0",
    "15" => "255.254.0.0",
    "16" => "255.255.0.0",
    "17" => "255.255.128.0",
    "18" => "255.255.192.0",
    "19" => "255.255.224.0",
    "20" => "255.255.240.0",
    "21" => "255.255.248.0",
    "22" => "255.255.252.0",
    "23" => "255.255.254.0",
    "24" => "255.255.255.0",
    "25" => "255.255.255.128",
    "26" => "255.255.255.192",
    "27" => "255.255.255.224",
    "28" => "255.255.255.240",
    "29" => "255.255.255.248",
    "30" => "255.255.255.252",
    "31" => "255.255.255.254",
    "32" => "255.255.255.255"
  }
  
  ## Parse a netmask and convert to a netmask string.
  ## 24 -> 255.255.255.0
  ## 255.255.255.0 -> 255.255.255.0
  ## Raises an exception if the netmask is not valid
  def self.parseNetmask( netmask )
    IPAddr.new( "255.255.255.255/#{netmask}" ).to_s
  end

  ## Just a little helper used to convey interfaces
  class PhysicalInterface
    def initialize( os_name, mac_address, bus, vendor )
      @os_name, @mac_address, @bus_id, @vendor = os_name, mac_address, bus, vendor
    end
    
    def to_s
      "physical-interface <#{os_name},#{mac_address},#{bus}>"
    end

    attr_reader :os_name, :mac_address, :bus, :vendor
  end
  
  ## This should return 
  ## an array of PhysicalInterfaces that are on the box.
  def interfaces
    raise "base class, override in an os specific class"
  end

  ## This should commit and update all of the network related settings.
  def commit
    raise "base class, override in an os specific class"
  end

  ## The address has been changed from underneath us.
  def update_address
    raise "base class, override in an os specific class"
  end
end
