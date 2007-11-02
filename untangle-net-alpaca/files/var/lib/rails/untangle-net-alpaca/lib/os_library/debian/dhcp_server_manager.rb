class OSLibrary::Debian::DhcpServerManager < OSLibrary::DhcpServerManager
  include Singleton

  DnsMasqLeases = "/var/lib/misc/dnsmasq.leases"

  def register_hooks
  end

  ## Sample entry
  ## 1193908192 00:0e:0c:a0:dc:a9 10.0.0.112 gobbleswin 01:00:0e:0c:a0:dc:a9
  def dynamic_entries
    entries = []
    ## Open up the dns-masq leases file and print create a table for each entry
    File.open( DnsMasqLeases ) do |f|
      f.each_line do |line|
        expiration, mac_address, ip_address, hostname, client_id = line.split( " " )
        expiration = Time.at( expiration.to_i )
        entries << DynamicEntry.new( expiration, mac_address, ip_address, hostname, client_id )
      end
    end
    entries.sort!
    entries
  end
end

