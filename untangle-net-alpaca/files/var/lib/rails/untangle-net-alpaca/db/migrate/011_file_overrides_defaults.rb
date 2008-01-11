class FileOverridesDefaults < ActiveRecord::Migration
  def self.up
    FileOverride.new( :enabled => false, :writable => true, 
                      :path => "/etc/network/interfaces" ).save
    FileOverride.new( :enabled => false, :writable => true, 
                      :path => "/etc/network/run/ifstate" ).save
    FileOverride.new( :enabled => false, :writable => true, 
                      :path => "/etc/resolv.conf" ).save
    FileOverride.new( :enabled => false, :writable => true, 
                      :path => "/etc/dnsmasq.conf" ).save
    FileOverride.new( :enabled => false, :writable => true, 
                      :path => "/etc/untangle-net-alpaca/dnsmasq-hosts" ).save
    FileOverride.new( :enabled => false, :writable => true, 
                      :path => "/etc/hostname" ).save
    FileOverride.new( :enabled => false, :writable => true, 
                      :path => "/etc/ddclient.conf" ).save
    FileOverride.new( :enabled => false, :writable => true, 
                      :path => "/etc/default/ddclient" ).save
    FileOverride.new( :enabled => false, :writable => true, 
                      :path => "/etc/ppp/pap-secrets" ).save
    FileOverride.new( :enabled => false, :writable => true, 
                      :path => "/etc/untangle-net-alpaca/arps" ).save
    FileOverride.new( :enabled => false, :writable => true, 
                      :path => "/etc/untangle-net-alpaca/routes" ).save

  end

  def self.down
  end

end
