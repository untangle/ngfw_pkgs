## These are settings for the DNS server
class DnsServerSettings < ActiveRecord::Base
  def self.create_default
    DnsServerSettings.create( :enabled => true, :suffix => "example.com" )
  end
end
