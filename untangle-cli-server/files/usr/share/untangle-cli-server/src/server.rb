#!/usr/bin/jruby
#
# $HeadURL:$
# Copyright (c) 2003-2007 Untangle, Inc. 
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
$:.unshift File.dirname(__FILE__)

# Should server restarts be controlled interactively (used for debugging)?
INTERACTIVE = false

require 'drb'
require 'optparse'
require 'thread.rb'

require 'common'
include NUCLICommon
require 'util'
include NUCLIUtil

#
#   NUCLI server core class ***TODO: doc the extensibilty if this class and the
#   component API.
#
class NUCLIServer
    
    attr_reader :server_name, :server_host, :server_port

    # Server initialization and setup
    def initialize(options)
        init(options)
    end
    
    def init(options)
        @diag = Diag.new(DEFAULT_DIAG_LEVEL)
	@diag.if_level(2) { puts! "Initializing NUCLIServer..." }

        # Setup defaults
        @server_host = 'localhost'
        @server_port = ENV['NUCLI_PORT'] || 6971
        @server_name = "NUCLI Server"

        # Process command line options
        process_options(options)

        # TODO: Rename this
        @component_methods = []
        @component_lock = Mutex.new
        @loaded_elements = []

	# Logging
	@logging = false
	log_file = "#{ENV['UVM_ROOT']}/var/log/uvm/nucliserver.log"
	STDOUT.reopen(File.open(log_file, "a")) if @logging

        # Misc
	@start_time = Time.now
        @running = false
        trap("HUP") { self.reset }
        
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
        if @running then message("${server_name} main loop is not reenterant.", 0); return; end
        @running = true

	at_exit { DRb.stop_service ; DRb.thread.kill if DRb.thread }
        
        puts! "Starting #{@server_name} on #{@server_host}:#{@server_port}..."
        DRb.start_service("druby://#{@server_host}:#{@server_port}", self)
        puts! "#{@server_name} started at #{Time.now}."
        DRb.thread.join
    end

    #
    # Methods to handle server requests
    #
    def method_missing(method_id, args)
        begin
            args = [] if args.nil?
            node = method_id.id2name
            @diag.if_level(3) { puts! "'#{node}' method not found - attempting to dynamically load component..." }

            @component_lock.synchronize {
                # Attempt to load a filter node with the name of the missing method.
                @diag.if_level(3) { puts! "Trying to require '#{node}'" }
                require node
                @diag.if_level(3) { puts! "Found code for '#{node}'" }
                
                # If successful, create an new instance of the filter node loaded via require.
                class_name = UVMRemoteApp.last_subclass
                self.instance_variable_set("@#{node}", eval("#{class_name}.new"))
                instance_eval("@loaded_elements << @#{node}")
                @diag.if_level(3) { puts! "Dynamic element instanced" ; p @loaded_elements }
                
                # Now define the missing method such that it delegates to the instance of the filter node.
                self.instance_eval %{
                    def #{node}(params_ary)
						@component_lock.synchronize {
							@#{node}.execute(params_ary)
						}
                    end
                    @component_methods << :#{node}
                }
                @diag.if_level(3) { puts! "Filter node delegator created." ; p methods }
                                
                # At this point, future calls to the missing method will be handed by the delegator 
		# method we just created above.
            }
            
            # Lastly, fulfill the call for which the method was missing in the first place
            return self.__send__("#{node}", args)

        rescue LoadError => ex
            # #{node}.rb not found 
            return ERROR_UNKNOWN_COMMAND 
        rescue NameError, NoMethodError => ex
            msg = "Error: component '#{node}' does not have the proper structure - " + ex
            @diag.if_level(3) { puts! msg; p ex }
            return msg
        rescue Exception => ex
            msg = "Error: unable to load component '#{method_id}': " + ex
            @diag.if_level(3) { puts! msg; p ex }
            return msg
        end
    end

    def execute(cmd)
        cmd = cmd.strip
        @diag.if_level(3) { puts! "Executing '#{cmd}'" }
        begin
            output = `#{cmd}`
            return ($? >> 8) == 127 ? "Error: command '#{cmd}' not found." : output
        rescue IOError => ex
            err = "Error: unable to execute '#{cmd}' - command not found or not executable."
            @diag.if_level(3) { puts! err ; p ex }
            return err
        end
    end

    def rsh(*args)
	if empty?(args)
            return ERROR_UNKNOWN_COMMAND
        else
            return execute("#{args.join(' ')}")
        end
    end
    
    def ruby(ruby)
        begin
            return eval(ruby)
        rescue Exception => ex
            err = "Error: the Ruby code received for evaluation has thrown an unhandled exception -- " + ex
            @diag.if_level(3) { puts! err ; p ex ; p ruby }
            return err
        end
    end
    
    # Respond to "pong" w/expected_response: used to check if sever is alive.
    def pong(expected_response)
	@diag.if_level(3) { puts! "I've been ponged." }
        return expected_response
    end

    # ***TODO: this works but I don't fully understand it.  Need to study.  See this link for a start:
    # http://groups.google.com/group/comp.lang.ruby/browse_thread/thread/f991a8a9adc34574/5361f7b93427ca60?hl=en&lnk=gst&q=remove+instance+method&rnum=8#5361f7b93427ca60
    def delete_method(name)
        class << self; self end.     # overcome remove being private ...
        __send__(:remove_method,name) 
    end
    
    def reset
      # Remove added components (removing their delegator methods will cause them to be reloaded.)
      @diag.if_level(3) { p self.methods.sort }
      @component_lock.synchronize {
        @component_methods.each { |meth_name|
            delete_method meth_name
        }
        @component_methods = []
      }
      @diag.if_level(3) { p self.methods.sort }
    end
    
    def shutdown
        exit(0)
    end

    def info(*args)
	"Start time: #{@start_time}\n"
    end

end


if __FILE__ == $0

restarts = 0
max_restarts_per_min = 5
start_time = Time.now

loop do
    ucli_server = nil
    begin
        ucli_server = NUCLIServer.new(ARGV)
        ucli_server.run
        break
    rescue Interrupt
        break
    rescue Exception => ex
        puts! "#{ucli_server.nil? ? "The NUCLI Server" : ucli_server.server_name} has encountered an unhandled exception: " + ex
	if INTERACTIVE
	    print! "Restart server (y/n)? "
	    break unless getyn("y")
	else
	    restarts += 1
	    mins = (1.0 + ((Time.now() - start_time) / 60)).floor
	    if (restarts / mins) > max_restarts_per_min
		puts! "Maximum restarts (#{max_restarts_per_min}) per minute exceeded: terminating."		
		exit(-1)
	    else
                puts! "Restarting #{ucli_server.nil? ? "The NUCLI Server" : ucli_server.server_name}...\n"
	    end
	end
    ensure
        #ucli_server.shutdown
    end
    
end # loop

exit 0

end # if __FILE__
