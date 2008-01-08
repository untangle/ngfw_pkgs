#!/usr/bin/ruby

require 'drb'

# Constants
DEFAULT_PORT = 6971

# If watcher is already running complain and exit.
pid = `ps aux | egrep 'nucli\-watcher\.rb' | grep -v egrep`.split[1]
if pid != nil
	puts "Error: nucli-watcher is already running (see PID #{pid})."
	exit 1
end

# Check that nucli-server program is available: if not complain and exit
NUCLI_SERVER = "#{ENV[UVM_ROOT]}/usr/share/untangle/bin/nucli-server"
if !File.exist(NUCLI_SERVER)
	puts "Error: nucli-server (file) cannot be found."
	exit 3
end

# If all preconditions are met then process command line options
opts = OptionParser.new
opts.banner = "Usage: #{File.basename(__FILE__)} [OPTIONS]"
nucli_port = ENV['NUCLI_PORT'] || DEFAULT_PORT
opts.on("-p", "--port PORT", Integer, "NUCLI server port number.") { |port|
    nucli_port = port
}
opts.on("-?", "--help", "Display help.") {
    puts! opts.to_s
    exit 0
}

remainder = opts.parse(options);
if remainder.length > 0
    print! "Unknown options encountered: #{remainder}\nContinue [y/n]? "
    exit 1
end

# Launch and then watch nucli-server
DRb.start_service
while true
	begin
		# Execute the server
		exec(NUCLI_SERVER) unless server_pid
		sleep 3
	
		# Setup DRb connection
		svr = DRbObject.new(nil, "druby://localhost:#{nucli_port}")

		# Watch server
		expected_response = "watcher"
		responsive = true
		while responsive
			responsive = svr.pong(expected_response) == expected_response
			if !responsive
				# If server fails to respond try several more times in more rapid 
				# succession - if any responce then we're OK - server may just be heavily
				# loaded.  If not, then deem server non-responsive.
				5.times {
					responsive ||= svr.pong(expected_response) == expected_response
					sleep 3
				}
			else
				sleep 20
			end
		end

		# Kill non-responsive server, if its still running...
		kill_server
	rescue Exception => ex
		puts "#{File.basename(__FILE__)} has encountered an unhandled exception: " + ex
		p ex
		puts ex.backtrace
	end
end

def server_pid
	`ps aux | egrep 'org\.jruby\.Main.*server\.rb' | grep -v egrep`.split[1]
end

def kill_server(pid = nil)
	pid ||= server_pid
	if pid
		Process.kill("KILL", pid)
		Process.wait(pid)
	end
end

# EOF
