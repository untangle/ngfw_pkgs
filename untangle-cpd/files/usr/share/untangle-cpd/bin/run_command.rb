#!/usr/bin/env ruby

require "json"
require "net/http"
require "cgi"
require "getoptlong"

class CaptivePortal
  def run_command( command, args = [], options = {} )
    host = options["host"]
    port = options["port"]
    path = options["path"]
    
    host = "127.0.0.1" if host.nil?
    port = "3005" if port.nil?
    path = "/" if path.nil?
    
    command_hash = {}
    command_hash["function"] = command
    
    args.each do |arg|
      key, value = arg.split( ":", 2 )
      
      if value.nil?
        puts "Ignoring the key: #{key}, because it is missing a value."
        next
      end
      
      value = true if ( value == "true" )
      command_hash[key] = value
    end
    
    Net::HTTP.start( host, port ) do |session|
      request = "json_request=#{CGI.escape( command_hash.to_json )}"
      response, json_body = session.post( path, request )
      
      unless ( response.is_a?( Net::HTTPOK ))
        puts "Invalid response: #{response}"
        puts "Body: #{json_body}"
        return
      end
      
      body = JSON.parse( json_body )
      
      if self.class.method_defined?( "display_#{command}" )
         send( "display_#{command}", body )
      else
        puts "Received the message: #{body["message"]}"
      end
    end
  end

  def display_get_active_hosts( body )
    puts "Listing the active hosts."
    
    body["hosts"].each do |host|
      puts "address: %15-s, enabled: %7-s, passive: %7-s, gateway: %15-s" %  [ host["address"], host["enabled"], host["passive"], host["gateway"] ]
    end
  end

  def display_list_functions( body )
    puts "Listing available functions.\n#{body["functions"].join( ", " )}"
  end

  def display_get_config( body )
    puts "Retrieved the configuration.\n#{body["config"].to_json}"
  end

  def display_get_status( body )
    puts "Startup time: #{body["startup_time"].to_json.strip}"
    puts "Retrieved the status\n#{body["faild_status"].to_json}"
  end

  def display_get_uplink_status( body )
    puts "Startup time: #{body["startup_time"].to_json.strip}"
    puts "Retrieved uplink status\n#{body["uplink_status"].to_json}"
  end

  def display_hello_world( body )
    puts "Startup Time: #{body["startup_time"].to_json.strip}"
    puts "#{body["message"]}"
  end
end

opts = GetoptLong.new(
                      [ "--port", GetoptLong::REQUIRED_ARGUMENT ],
                      [ "--host", GetoptLong::REQUIRED_ARGUMENT ]
                      )

options = {}
opts.each { |opt,arg| options[opt.sub( "--", "" )] = arg }

args = [ ARGV ].flatten

if args.empty?
  puts <<EOF
USAGE: #{__FILE__}: [--port <port>] [--host <host>] <command> [key:value]*
For a list of valid commands use the command list_functions.
EOF

  args = [ "list_functions" ] 
end


CaptivePortal.new.run_command( args.shift, args, options )

