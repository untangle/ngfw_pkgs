#!/usr/bin/jruby
#
# server.rb - New Untangle Command Line Interface (NNUCLI) Server
#
# Copyright (c) 2007 Untangle Inc., all rights reserved.
#
# @author <a href="mailto:ken@untangle.com">Ken Hilton</a>
# @version 0.1
#

# Should server restarts be controlled interactively (used for debugging)?
INTERACTIVE = $DEBUG

require 'drb'
require 'optparse'
require 'thread'

require 'common'
include NUCLICommon
require 'util'
include NUCLIUtil
#require 'ucli_api'
#include NUCLIApi

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
        @server_port = 7777
        @server_name = "NUCLI Server"

        # Process command line options
        process_options(options)

        @component_methods = []
        @component_lock = Mutex.new

        # Misc
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
        
        puts! "Starting #{@server_name} at #{@server_host}:#{@server_port}..."
        DRb.start_service("druby://#{@server_host}:#{@server_port}", self)
        puts! "#{@server_name} started."
        DRb.thread.join
    end

    #
    # Methods to handle server requests
    #
    def method_missing(method_id, args)
        begin
            puts! "svr mthd msng"
            p args
            
            args = [] if args.nil?
            node = method_id.id2name
            @diag.if_level(3) { puts! "'#{node}' method not found - attempting to dynamically load component..." ; p args }

            @component_lock.synchronize {
                # Attempt to load a node CLI with the name of the missing method.
                require node
                
                # If successful, create an new instance of the node CLI loaded via the require.
                self.instance_variable_set("@#{node}", eval("#{node.capitalize}.new"))
                
                # Now define the missing method such that it delegates to the instance of the node CLI.
                self.instance_eval %{
                    def #{node}(params_ary)
                        @#{node}.execute(params_ary)
                    end
                    @component_methods << :#{node}
                }
                # At this point, future calls to the missing method will be handed by the delegator we just created above.
            }
            
            # Lastly, fulfill the call for which the method was missing in the first place
            return self.__send__("#{node}", args)

        rescue LoadError
            # #{node}.rb not found so assume the missing method is really a program to run.
            res  = execute("#{node} #{args.join(' ') if args}")
            return res
        rescue NameError, NoMethodError => ex
            msg = "Error: component '#{node}' does not have the proper structure - " + ex
            @diag.if_level(3) {
                puts! "#{msg}"
                p ex
            }
            return msg
        rescue Exception => ex
            msg = "Error: unable to load component '#{method_id}': " + ex
            @diag.if_level(2) {
                puts! "#{msg}"
                p ex
            }
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
        # ***TBD
    end

end


if __FILE__ == $0

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
            puts! "Restarting #{ucli_server.nil? ? "The NUCLI Server" : ucli_server.server_name}...\n"
	end
    ensure
        #ucli_server.shutdown
    end
    
end # loop

exit 0

end # if __FILE__
