#! /usr/local/bin/ruby

require 'db'

uk = UntangleKey.new

puts  "Content-Type: text/plain"
puts

puts "license_key | ip_address | passphrase"
puts "-------------------------------------"
puts "-------------------------------------"

uk.listAllKeys.each { |row| 
  puts row
}

uk.close
