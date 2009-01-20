#
# $HeadURL$
# Copyright (c) 2007-2008 Untangle, Inc.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License, version 2,
# as published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but
# AS-IS and WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE, TITLE, or
# NONINFRINGEMENT.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA.
#
require "ipaddr"

class OSLibrary::NetworkManager < Alpaca::OS::ManagerBase
  DefaultMTU = 1500
  
#Removed above a class A for overly broad netmask
  CIDR = {
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

  FULL_CIDR = CIDR.merge( {
    "0"  => "0.0.0.0",
    "1"  => "128.0.0.0",
    "2"  => "192.0.0.0",
    "3"  => "224.0.0.0",
    "4"  => "240.0.0.0",
    "5"  => "248.0.0.0",
    "6"  => "252.0.0.0",
    "7"  => "254.0.0.0" }  )

  NETMASK_TO_CIDR = FULL_CIDR.invert()

  TEST_CONNECTIVITY_TIMEOUT = 20

  class ConnectivityStatus
    def initialize( success, tcp_status, dns_status )
      @success, @tcp_status, @dns_status = success, tcp_status, dns_status
    end

    attr_reader :success, :tcp_status, :dns_status
  end

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
      "physical-interface <#{os_name},#{mac_address},#{bus_id},#{vendor}>"
    end

    attr_reader :os_name, :mac_address, :bus_id, :vendor
  end
  
  ## This should return 
  ## an array of PhysicalInterfaces that are on the box.
  def interfaces
    raise "base class, override in an os specific class"
  end

  def internet_connectivity?( host="updates.untangle.com" )
    require "resolv"
    require "socket"
    require "thread"
    result = [false, "Timeout"]
    t = Thread.new do
      begin
        address = Resolv.getaddress( host )
        s = TCPSocket.new( address, "http" )
        s.close
        result = [true, "TCP"]
      rescue Errno::ECONNREFUSED
        result = [true, "TCP"] #TODO does this make sense
      rescue Timeout::Error, StandardError
        result = [false, "TCP"]
      rescue ResolvError
        result = [false, "DNS"]
      end
    end
    sleep 0.1
    t.join(TEST_CONNECTIVITY_TIMEOUT)
    return result
  end

  def internet_connectivity_v2?( host="updates.untangle.com" )
    result = internet_connectivity?( host )
    success = result[0]
    tcp_status = success
    dns_status = ( result[1] != "DNS" )
    ConnectivityStatus.new( success, tcp_status, dns_status )
  end

  ## This should commit and update all of the network related settings.
  def commit
    raise "base class, override in an os specific class"
  end
end
