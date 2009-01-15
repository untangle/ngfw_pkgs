#
# $HeadURL: svn://chef/work/pkgs/untangle-net-alpaca/files/var/lib/rails/untangle-net-alpaca/lib/os_library/network_manager.rb $
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

class OSLibrary::Null::NetworkManager < OSLibrary::NetworkManager
  include Singleton

  NetClassDir = "/sys/class/net"
  InterfacesStatusFile = "/etc/network/run/ifstate"

  def get_interfaces_status_file
    return InterfacesStatusFile
  end

  def interfaces
    logger.debug( "Running inside of the network manager for debian" )

    interfaceArray = []

    devices=`cd #{NetClassDir};echo */device | sed 's|/device||g' | sort`.split

    devices.each do |os_name|

      bus_id = File.readlink("#{NetClassDir}/#{os_name}/device").sub(/.*devices\//, '')
      vendor=get_vendor( os_name )

      ## For some reason, on some systems this causes ruby to hang, use 'cat' instead.
      # mac_address = File.open( "#{NetClassDir}/#{os_name}/address", "r" ) { |f| f.readline.strip }
      mac_address = `cat "#{NetClassDir}/#{os_name}/address"`.strip
      
      logger.debug( "found network device: #{os_name}, mac: #{mac_address}, vendor: #{vendor}, bus_id: #{bus_id}" )
      interfaceArray << PhysicalInterface.new( os_name, mac_address, bus_id, vendor )
    end
    
    interfaceArray
  end

  ## This should commit and update all of the network related settings.
  def commit
    puts "ignoring commit for null OS"
  end

  def get_vendor( os_name )
    subsystem="#{NetClassDir}/#{os_name}/device/subsystem"
    if (!File.exists?(subsystem))
       # 2.6.16 compatibility:
       subsystem="#{NetClassDir}/#{os_name}/device/bus"
    end

    bus = File.readlink(subsystem).sub(/.*\//, '')

    uevent="#{NetClassDir}/#{os_name}/device/uevent"
    vendor_id = `awk '/(PCI_ID|PRODUCT)/ { sub( /^[^=]*=/, "" );  print $0 }' #{uevent}`.strip
    
    return "Unknown" if ApplicationHelper.null?( vendor_id ) || ApplicationHelper.null?( bus )

    vendor_id = vendor_id.sub( /[:\/].*/, "" )
    
    case bus
    when "usb"
      vendor = `zcat -f /usr/share/misc/usb.ids | awk '/^#{vendor_id}/ { $1 = "" ; print $0 }'`.strip
    when "pci"
      vendor = `awk '/^#{vendor_id}/ { $1 = "" ; print $0 }' /usr/share/misc/pci.ids`.strip
    else return "Unknown"
    end
    
    return "Unknown" if ApplicationHelper.null?( vendor )
    return vendor
  end

  def get_media( interface )
    case "#{interface.speed}-#{interface.duplex}"
    when "10-full" then return "10-full-duplex" 
    when "10-half" then return "10-half-duplex" 
    when "100-full" then return "100-full-duplex" 
    when "100-half" then return "100-half-duplex"
    end

    logger.warn( "Unknown media #{interface.speed},#{interface.duplex}" ) unless interface.speed == "auto"
    
    ## default.
    return "auto"
  end
end
