#!/usr/bin/ruby

require "sqlite3"

DefaultRailsHome = "/var/lib/rails/untangle-net-alpaca/"

rails_home = ARGV[0]
if ( rails_home.nil? || !File.exist?( "#{rails_home}/log/mongrel.pid" )) 
  rails_home = DefaultRailsHome
end

## 
pid_file="#{rails_home}/log/mongrel.pid"
exit unless File.exist?( pid_file )
pid=`cat #{pid_file}`
db_file =`sudo lsof -p #{pid} 2>/dev/null | awk ' /database.*\.db$/ { print $9 }'| head -n 1`.strip

exit if db_file.nil? || db_file.empty?
exit unless File.exist?( db_file )

puts "Cleaning up the database file: '#{db_file}'"

db = SQLite3::Database.new( db_file )

db.transaction do |connection|
  ip_networks = {}

  ## Find all of the ip-networks
  connection.execute( "SELECT id FROM ip_networks ORDER BY ID" ) do |row|
    ## Just add up the ids
    ip_networks[row[0]] = true
  end

  ## Find all of the nat-policies
  nat_policies = {}
  connection.execute( "SELECT id FROM nat_policies " ) do |row|
    nat_policies[row[0]] = true
  end
  
  ## Find all of the ones that are used.
  ## Do not delete the ones used by statics
  connection.execute( "SELECT ip_network_id FROM intf_statics_ip_networks" ) do |row|
    ## Delete those from the set
    ip_networks.delete( row[0] )
  end

  ## Do not delete the ones used by dynamics.
  connection.execute( "SELECT ip_network_id FROM intf_dynamics_ip_networks" ) do |row|
    ## Delete those from the set
    ip_networks.delete( row[0] )
  end
  
  ## Do not delete the nat_policies
  connection.execute( "SELECT nat_policy_id FROM intf_statics_nat_policies" ) do |row|
    ## Delete those from the set
    nat_policies.delete( row[0] )
  end

  ip_networks_array = []
  ip_networks.each_key { |k| ip_networks_array << k }

  unless ip_networks_array.empty?
    puts "executing : DELETE FROM ip_networks WHERE id IN (#{ip_networks_array.join( "," )})"
    connection.query( "DELETE FROM ip_networks WHERE id IN (#{ip_networks_array.join( "," )})" )
  end

  nat_policies_array = []
  nat_policies.each_key { |k| nat_policies_array << k }


  unless nat_policies_array.empty?
    puts "executing : DELETE FROM nat_policies WHERE id IN (#{nat_policies_array.join( "," )})"
    connection.query( "DELETE FROM nat_policies WHERE id IN (#{nat_policies_array.join( "," )})" )
  end
end

