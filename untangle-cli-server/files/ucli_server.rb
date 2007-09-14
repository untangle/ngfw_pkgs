#!/usr/local/bin/ruby
#
# ucli_server.rb - Untangle Command Line Interface Server
#
# Copyright (c) 2007 Untangle Inc., all rights reserved.
#
# @author <a href="mailto:ken@untangle.com">Ken Hilton</a>
# @version 0.1
#

# Use full UVM server functionality (requires jruby, etc.)?
UVM=true

if UVM
require 'java'
require 'proxy'
require '_debug'
end

require 'drb'
require 'optparse'
require 'ucli_util'

# UCLI server base class: contains no JRuby code so it can be run as a "stub" on systems without the
# untangle server.  See UVMServer below for the real meat-and-potatos server.
class UCLIServer
    
    attr_reader :server_name, :server_host, :server_port

    # Shared error messages
    ERROR_INCOMPLETE_COMMAND = "Error: incomplete command - arguments required."
    ERROR_UNKNOWN_COMMAND = "Error: unknown command"
    ERROR_NOT_WEBFILTER_NODES = "No web filter modules are installed on the effective server."
    
    WEBFILTER_NODE_NAME = "untangle-node-webfilter"
    
    # Server initialization and setup
    def initialize(options)
        init(options)
    end

    def init(options)
        # Setup defaults
        @server_host = 'localhost'
        @server_port = 7777
        @server_name = "UCLI Server"

        @diag = Diag.new(3)
        
        # Process command line options
        process_options(options)
    end

    def process_options(options)
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
    end
    
    # Server main loop
    def run
        puts! "Starting #{@server_name} at #{@server_host}:#{@server_port}..."
        DRb.start_service("druby://#{@server_host}:#{@server_port}", self)
        puts! "#{@server_name} started."
        DRb.thread.join
    end

    def shutdown
    end

    # Methods to handle server requests
    def ruby(ruby)
        eval(ruby)
    end
    
    def pong(expected_response)
	@diag.if_level(2) { puts! "I've been ponged." }
        return expected_response;
    end

    # This method is not correct: we don't know if the command was not found or not.
    def execute(cmd)
        `#{cmd}`
    end
    
    def reset
    end
    
end

class UVMServer < UCLIServer
    
    if UVM
        include Proxy
    end
    
    DefaultTimeoutMillis = 600000

    attr_reader :uvmRemoteContext
    
    #
    # Server initialization and setup
    #
    def initialize(options)
        super options
        
        ## Retrieve the factory
        @factory = com.untangle.uvm.client.RemoteUvmContextFactory.factory
        
        ## This just guarantees that all of the connections are terminated.
        at_exit { disconnect }
    end

    #
    # Server support methods
    #
    def connect
      ## Just in case
      begin
        @factory.logout 
      rescue
        ## ignore errors
      end
      
      @uvmRemoteContext = @factory.systemLogin( DefaultTimeoutMillis )
      
      ## Register the remove context as a proxy.
      register( @uvmRemoteContext )
      true
    end

    def disconnect
      return if @uvmRemoteContext.nil?
      begin
        @factory.logout
      rescue
        ## ignore errors
      end
      @uvmRemoteContext = nil
      true
    end

    #
    # Server service methods
    #
    #def getPolicies()
        #@diag.if_level(2) { puts! "getPolicies" }
        #puts! "getPolicies"
      #policies = @uvmRemoteContext.policyManager.getPolicies
      #policies.each { |p|
          #p policies
      #} if policies
    #end

    def webfilter(args)
        
        begin
            # Get tids of all web filters.
            tids = @uvmRemoteContext.nodeManager.nodeInstances(WEBFILTER_NODE_NAME)
            return ERROR_NOT_WEBFILTER_NODES if tids.nil? || tids.length < 1
    
            if /^#/ =~ args[0]
                node_num = (args[0].slice(1,-1).to_i) - 1
                tid = tids[node_num]
                cmd = args[1]
                args.shift
                args.shift
            else
                node_num = 0
                cmd = args[0]
                tid = tids[0]
                args.shift
            end
            
            @diag.if_level(3) { puts! "webfilter: node # = #{node_num}, command = #{cmd}" }
            
            case cmd
            when nil, "", "list"
                # List/enumerate web filter nodes
                @diag.if_level(2) { puts! "webfilter: listing nodes..." }
                webfilter_list = ""
                webfilter_num = 1
                tids.each { |tid|
                    node_ctx = @uvmRemoteContext.nodeManager.nodeContext(tid)
                    desc = node_ctx.getNodeDesc()
                    webfilter_list << "##{webfilter_num} #{desc}\n"
                    webfilter_num += 1
                }
                @diag.if_level(2) { puts! "webfilter: #{webfilter_list}" }
                return webfilter_list
            when "block-list"
                return manage_block_list(tid, args)
            when "pass-list"
                return "Pass-list not yet supported."
            when "eventlog"
                return "Event Log not yet supported."
            else
                return ERROR_UNKNOWN_COMMAND + "-- " + args.join(' ')
            end
        rescue Exception => ex
            msg = "#{server_name}:webfilter has raised an unhandled exception -- " + ex
            @diag.if_level(1) { puts! msg }
            return msg
        end
        
    end

    def manage_block_list(tid, args)
        case args[0]
        when nil, ""
            return ERROR_INCOMPLETE_COMMAND
        when "urls"
            # List blocked URLs
            node_ctx = @uvmRemoteContext.nodeManager.nodeContext(tid)
            node = node_ctx.node()
            settings =  node.getSettings()
            blocked_urls_list = settings.getBlockedUrls()
            blocked_urls = ""
            blocked_urls_list.each { |url|
                blocked_urls << (url.getString() + "\n")
                @diag.if_level(3) { puts! url.getString() }
            } if blocked_urls_list
            return blocked_urls
        when "categories"
        when "mime"
        when "file"
            return "Not yet supported"
        when "block"
            case args[1]
            when nil, ""
                return ERROR_INCOMPLETE_COMMAND
            when "url"
                # Block given URL
                case args[2]
                when nil, ""
                    return ERROR_INCOMPLETE_COMMAND + "-- URL to block is missing."
                else
                    # TBC - verify format of url?
                    node_ctx = @uvmRemoteContext.nodeManager.nodeContext(tid)
                    node = node_ctx.node()
                    settings =  node.getSettings()
                    blocked_urls_list = settings.getBlockedUrls()   
                    begin
                        url = args[2].gsub(/^www./, '')
                        @diag.if_level(2) { puts! "Attempting to add #{url} to blocked list." }
                        stringRule = com.untangle.uvm.node.StringRule.new(url)
                        stringRule.setLog(true) if args[3].nil? || (args[3] == "true")
                        blocked_urls_list.add(stringRule)
                        settings.setBlockedUrls(blocked_urls_list)
                        node.setSettings(settings)
                        msg = "#{args[2]} added to blocked list."
                        puts! msg
                        return msg
                    rescue Exception => ex
                        p ex
                        return "Adding URL to block list failed:\n" + ex
                    end
                end
            when "category"
            when "mime"
            when "file"
                return "Not yet supported."
            else
                return ERROR_UNKNOWN_COMMAND + " -- " + args.join(' ')
            end
        when "unblock"
        else
            return ERROR_UNKNOWN_COMMAND + " -- " + args.join(' ')
        end
    end

end


if __FILE__ == $0

loop do
    begin
        if UVM
            ucli_server = UVMServer.new(ARGV)
            puts! "Creating UVM CLI Server..."
            ucli_server.connect
        else
            ucli_server = UCLIServer.new(ARGV)
            puts! "Creating Simple UCLI Server..."
        end
        trap("HUP") { ucli_server.reset }
        ucli_server.run
        break
    rescue Interrupt
        break
    rescue Exception => ex
        puts! "#{@server_name} has encountered techinical difficulties: " + ex
        puts! "Restarting #{@server_name}...\n"
	p ex
    ensure
        #ucli_server.shutdown
    end
end # loop

exit 0

end # if __FILE__
