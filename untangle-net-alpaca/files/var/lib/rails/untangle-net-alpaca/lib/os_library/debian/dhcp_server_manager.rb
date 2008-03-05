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
class OSLibrary::Debian::DhcpServerManager < OSLibrary::DhcpServerManager
  include Singleton

  DnsMasqLeases = "/var/lib/misc/dnsmasq.leases"

  def register_hooks
  end


  ## Sample entry
  ## 1193908192 00:0e:0c:a0:dc:a9 10.0.0.112 gobbleswin 01:00:0e:0c:a0:dc:a9
  def dynamic_entries
    entries = []
    begin
      ## Open up the dns-masq leases file and print create a table for each entry
      File.open( DnsMasqLeases ) do |f|
        f.each_line do |line|
          expiration, mac_address, ip_address, hostname, client_id = line.split( " " )
          next if mac_address.nil? || ip_address.nil?
          expiration = Time.at( expiration.to_i )

          entries << DynamicEntry.new( expiration, mac_address, ip_address, hostname, client_id )
        end
      end
    rescue Exception => exception
      logger.warn( "Error reading " + DnsMasqLeases.to_s + " " + exception.to_s )
    end
    entries.sort!
    entries
  end

  def commit
    os["dns_server_manager"].commit
  end
end

