#!/usr/local/bin/ruby
#
# ucli_server.rb - Untangle Command Line Interface Server
#
# Copyright (c) 2007 Untangle Inc., all rights reserved.
#
# @author <a href="mailto:ken@untangle.com">Ken Hilton</a>
# @version 0.1
#

# Should server restarts be controlled interactively (used for debugging)
INTERACTIVE = $DEBUG

require 'drb'
require 'optparse'

require 'ucli_common'
include UCLICommon
require 'ucli_util'
include UCLIUtil

require 'webfilter'

#
#   UCLI server base class: contains no JRuby code so it can be run as a "stub" on systems without the
#   untangle server.  See UVMServer below for the real meat-and-potatos server.
#   @author <a href="mailto:ken@untangle.com">Ken Hilton</a>
#
class UCLIServer
    
    attr_reader :server_name, :server_host, :server_port

    # Server initialization and setup
    def initialize(options)
        init(options)
    end

    def init(options)
        @diag = Diag.new(DEFAULT_DIAG_LEVEL)
	@diag.if_level(2) { puts! "Initializing UCLIServer..." }

        # Setup defaults
        @server_host = 'localhost'
        @server_port = 7777
        @server_name = "UCLI Server"

        # Process command line options
        process_options(options)

	@diag.if_level(2) { puts! "Done initializing..." }
    end

    # Process and apply command line options
    def process_options(options)
	@diag.if_level(2) { puts! "Processing options..." }

        opts = OptionParser.new
        opts.banner = "Usage: #{File.basename(__FILE__)} [OPTIONS]"
        opts.on("-h", "--host HOST", String, "#{@server_name} host name or IP address.") { |host|
            @server_host = host
        }
        opts.on("-p", "--port PORT", Integer, "#{@server_name} port number.") { |port|
            @server_port = port
        }
        opts.on("-?", "--help", "Display help.") {
            puts! opts.to_s
            exit(0)
        }
        remainder = opts.parse(options);
        if remainder.length > 0
            print! "Unknown options encountered: #{remainder}\nContinue [y/n]? "
            raise Interrupt unless STDIN.gets.chomp.downcase == "y"
        end

	@diag.if_level(2) { puts! "Done processing options..." }
    end
    
    # Server main loop
    def run
        puts! "Starting #{@server_name} at #{@server_host}:#{@server_port}..."
        DRb.start_service("druby://#{@server_host}:#{@server_port}", self)
        puts! "#{@server_name} started."
        DRb.thread.join
    end

    def shutdown
        # ***TBD
    end

    #
    # Methods to handle server requests
    #
    def ruby(ruby)
        self.instance_eval(ruby)
    end
    
    # Respond to "pong" w/expected_response: used to check if sever is alive.
    def pong(expected_response)
	@diag.if_level(2) { puts! "I've been ponged." }
        return expected_response;
    end

    # ***TODO: this method is not correct. `` returns output but not whether the command
    # was found or not.  System() tells us if the command was found but does not yield
    # the output. popen() succeeds when the given command is not found and does not appear
    # to have a way to detect this case.  We could use system() with output redirection
    # but then we have to manage temp files in a thread safe manner and also have to cover
    # the case where the command itself may have I/O redirection or pipes. So we'll go with
    # `cmd` for now and work on this later.
    def execute(cmd)
        @diag.if_level(3) { puts! "Executing '#{cmd}'" }
        `#{cmd}`
    end
    
    def reset
        # ***TBD
    end
    
    def method_missing(method_id, *args)
        begin
            node = method_id.id2name
            @diag.if_level(3) { puts! "#{node} method not found - attempting to dynamically load component..." ; p args }

            # Attempt to load a component with the name of the missing method.
            require node
            
            # If successful, create an new instance of the component loaded via the require.
            self.instance_variable_set("@#{node}", eval("#{node.capitalize}.new"))
            
            # Now define the missing method such that it delegates to the loaded component.
            self.instance_eval %{
                def #{node}(params)
                    @#{node}.execute(params)
                end
            }
            
            # Lastly, fulfill the call for which the method was missing in the first place
            self.send("#{node}", *args)
            # At this point, future calls to the missing method will be handed by the delegator we just created.

        rescue LoadError
            # #{node}.rb not found so assume the missing method is really a program to run.
            return `#{node} #{args.join(' ')}`
        rescue Exception => ex
            msg = "Error: unable to load component for command '#{method_id}' " + ex
            @diag.if_level(2) {
                puts! "#{msg}"
                p ex
            }
            return msg
        end
    end
end

#
#   UVMServer extends UCLIServer adding functionality to send commands to
#   various UMV components, e.g. filter nodes, configuration, etc.
#   @author <a href="mailto:ken@untangle.com">Ken Hilton</a>
#
class UVMServer < UCLIServer
    
    #
    # Server initialization and setup
    #
    def initialize(options)
        super options
	@diag.if_level(2) { puts! "Initializing UVMServer..." }
        
        # Init/setup server filter interfaces
        #if UVM
        #    @webfilter = WebFilter.new
        #end

	@diag.if_level(2) { puts! "Done initializing UVMServer..." }
    end

    #def webfilter(args)
    #    res = nil
    #    begin
    #        res = @webfilter.execute(args)
    #    rescue Exception => ex
    #        res = "#{server_name}:webfilter has raised an unhandled exception -- " + ex
    #        @diag.if_level(1) { puts! res }
    #    end
    #    return res
    #end

end # UVMServer

if __FILE__ == $0

loop do
    ucli_server = nil
    begin
        if UVM
            puts! "Creating UVM CLI Server..."
            ucli_server = UVMServer.new(ARGV)
        else
            puts! "Creating Simple UCLI Server..."
            ucli_server = UCLIServer.new(ARGV)
        end
        trap("HUP") { ucli_server.reset }
        ucli_server.run
        break
    rescue Interrupt
        break
    rescue Exception => ex
        puts! "#{ucli_server.nil? ? "The UCLI Server" : ucli_server.server_name} has encountered an unhandled exception: " + ex
	if INTERACTIVE
	    puts! "Restart server (y/n)? "
	    break unless getyn("y")
	else
            puts! "Restarting #{ucli_server.nil? ? "The UCLI Server" : ucli_server.server_name}...\n"
	end
    ensure
        #ucli_server.shutdown
    end
end # loop

exit 0

end # if __FILE__
