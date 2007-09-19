#!/usr/local/bin/ruby
#
# ucli_client.rb - Untangle Command Line Interface Client
#
# Copyright (c) 2007 Untangle Inc., all rights reserved.
#
# @author <a href="mailto:ken@untangle.com">Ken Hilton</a>
# @version 0.1
#

require 'drb'
require 'readline'
include Readline
require 'abbrev'
require 'optparse'
require 'thread'
require 'shellwords'
include Shellwords

require 'ucli_util'
include UCLIUtil

#
# The UCLI Client effects a command line interface used to send operational and diagnostic
# commands to an Untangle server and to the filter nodes running on it.  The UCLIClient
# functionality current includes (as of 9/5/07):  ***TODO: NEEDS TO BE UPDATED.
#   1) Command line editing with history.
#   2) Quick commands via reference to historical commands, e.g., !2, !eval, which would run
#       command #2 or the most recent command beginning with the prefix "eval", respectively.
#   3) The ability to send raw Ruby code, either as a command line or as a file, to the Untangle
#       server for execution there.
#   4) Any unknown command is passed on to the user's effective shell assuming it is a Linux
#       system command of some type: this allows virtually anything to be done from the UCLI Client
#       without having to shell out.
#   5) More high level functionality is expected in the near future, e.g., operational commands such as
#       "add a user", diagnostic commands such as "dump the state of Java object XYZ", etc., etc.
#
# Note that the UCLIClient can be caused to reinitialize itself without shutting down by sending
# its process a SIGHUP, i.e., kill -1.
#
# To Do:
#   - Save history to file
#   - Autoload, ie, .uclirc file.
#   - Logon/log off - how?  Server ACL with password?
#   - Feedback for failed remote command
#   - Quote handling on command line?  Do we need it?
#   - Command level help strings.
#   - history N
#   - tasks command to review background tasks
#
# Open Issues:
#   - Do we need to save/load history?
#   - Do we need a .ucli file so various settings can be runtime configured per user?
#   - Should the history indicator character, i.e., '!', be abstacted?
#   - Is a DRb.service_shutdown required?
#   - Should history include the history command itself, like csh, tcsh?
#   - Do we need aliases?
#   - Do we need to manage/shrink the task list so its objects can be freed up?
#
class UCLIClient
   
    # Constants
    DEFAULT_PORT = 7777
    FORBIDDEN_BACKGROUND_COMMANDS = %w{ with }     # commands that cannot be run in the background
    FORBIDDEN_WITH_COMMANDS = %w{ open quit exit with history tasks servers } 
            
    # Accessors
    attr_reader :client_name, :welcome, :server_name, :history_size, :commands, :verbose
   
    #
    #   Initialization related methods
    #
    def initialize(options)
        init(options)
        DRb.start_service
    end

    def init(options)
        # Setup defaults
        @brand = "Untangle"
        @client_name = "UCLI Client"
        @server_name = "UCLI Server"
        @config_filename = ".uclirc"
        @cmd_num = 1
        @history = []
        @history_size = 20
        @welcome = "\nWelcome to the #{@client_name} - type 'help' for assistance.\n\n"
        @server_ping_thread = nil
        @server_ping_frequency = 60
        @verbose = 1
        @tasks = []
        @tasks_lock = Mutex.new
        @task_num = 1
        @diag = Diag.new(3)
        
        # Commands legend and creation of readline auto-completion abbreviations
        @commands_with_help = [
            # Cmd name     Svr Required    Help text
            ["history", false, "display command history, up to #{@history_size} events"],
            ["ruby", true, "send Ruby code to sever for execution -- ruby statement | file"],
            ["quiet", false, "quiet all but alert level #{@client_name} messages"],
            ["verbose", false, "set level of messages/chatter from #{@client_name} -- verbose [integer]"],
            ["pong", true, "test responsiveness of UCLI server"],
            ["quit", false, "terminate after user confirmation"],
            ["exit", false, "terminate immediately"],
            ["help", false, "display help information"],
            ["open", false, "open connection to #{@server_name} -- open (host-name|ip):port"],
            ["servers", true, "list servers currently under management by this #{client_name} session."],
            ["webfilter #X", true, "Send command to webfilter #X -- enter 'webfilter help' for details."],
            ["with <server #s|##> <-i>]", true, "Send multiple commands to servers #, #..., ## for all servers, -i for interactive -- with #1 #2 ..."],
            ["tasks", false, "List all background tasks currently running."],
            # The following are not top level commands but are included here so tab completion will support them.
            ["block-list", false, nil],
            ["block", false, nil],
            ["block-list", false, nil],
            ["pass-list", false, nil],
            ["categories", false, nil],
            ["url", false, nil],
            ["mime", false, nil],
            ["file", false, nil],
            ["eventlog", false, nil]
        ]
        @commands = [];
        @commands_with_help.each {|c| commands << c[0]}
        @abbrevs = @commands.abbrev
        Readline.completion_proc = proc do |string|
            @abbrevs[string]
        end
        
        # Setup signals to trap
        trap("HUP") { puts! "\nReinitializing client (per SIGHUP)...\nPress [Enter] to continue."; self.init }
        
        # We start w/no uvm servers: server can be loaded and opened via our dot file
        # and/or specified via a command line options.
        @ucli_servers = []
        @drb_server = nil               # Active drb server from uvm_servers array (defined below.)
        @server_id = 0
        @client_lock = Mutex.new
        
        # Process config file
        process_config_file(@config_filename)
        
        # Process command line options
        process_options(options)
    end

    # Process command line options    
    def process_options(options)
        opts = OptionParser.new
        opts.banner = "Usage: #{File.basename(__FILE__)} [OPTIONS]"
        ucli_server_host = nil
        opts.on("-h", "--host HOST", String, "UCLI server host name or IP address.") { |host|
            ucli_server_host = host
        }
        ucli_server_port = DEFAULT_PORT
        opts.on("-p", "--port PORT", Integer, "UCLI server port number.") { |port|
            ucli_server_port = port
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
        
        if !ucli_server_host.nil?
            # Since this method could be called outside the context of object initialization
            # we must sync before changing the state of the server list.
            @client_lock.synchronize do
                @ucli_servers << [ucli_server_host, ucli_server_port, nil];
            end
        end

    end
    
    # Process config file settings ***TODO
    def process_config_file(config_filename)
        # TBC
        # Read config params
        # Read list of servers to open in format of: uvm-1=ip:port, uvm-2=ip:port
    end

     #
     # Main CLI loop: read a command line (w/abbreviation/tab-completion support),
     # preprocess it for command history references, execute the command, and add
     # command to history for future reference.
     #
    def run
        connect_to_all_ucli_servers
        launch_server_pong
        print! @welcome
        
        loop do
            cmd_s = readline("[##{@server_id}:#{@cmd_num}] ", true)
            next if (cmd_s.nil? || cmd_s.length == 0)

            cmd_a = run_command(cmd_s)
            next if cmd_a.nil?
            
            # Only commands entered into the top level "shell" are added to the session history
            @history.shift unless @history.length < @history_size
            @history << [@cmd_num,cmd_a.join(' ')]
            @cmd_num += 1
            
            @cleanup
        end
    end
    
    # Runs given command and returns an array of the words composing the command actually run,
    # which may differ from the given command string if, say, history substitution is performed.
    def run_command(cmd_s)
        
        cmd_a = preprocess(cmd_s);
        return nil if (cmd_a.nil? || cmd_a.length == 0)
        
        if (@drb_server.nil? || @drb_server[2].nil?) && command_requires_server(cmd_a[0])
            puts! "There is no open #{@server_name}: at least one server must be opened before this command can be issued."
            return nil            
        end

        # ***TODO: need to handle case of "foo&", which is distinct from "foo &" (note the space between 'foo' and '&')
        if cmd_a[-1] == "&"
            FORBIDDEN_BACKGROUND_COMMANDS.detect { |cmd|
                if (cmd == cmd_a[0])
                    puts! "Error: '#{cmd}' cannot be executed in the background."
                    return
                end
            }
            cmd_a.pop # remove '&' from arg list
            @tasks_lock.synchronize {
                @tasks << [Thread.new { self.__send__(*cmd_a); puts! "Done (#{cmd_a.join(' ')})" }, cmd_s, @task_num]
                @task_num += 1
            }
            cmd_a << "&" # restore popped '&'
        else
            self.__send__(*cmd_a)
        end
        cmd_a   # return command components IFF command is run
    end
    
    
    # Preprocess a pending command: perform history replacement, etc.
    def preprocess(cmd)
        #cmd_a = cmd.strip.split
        cmd_a = shellwords cmd
        cmd = cmd_a[0].strip
        
        # Check for meta-commands first, ie, histrory, server selection...
        if (/^!!/ =~ cmd)                           # User wants the last command run again
            hist_cmd = @history[-1]
            cmd_a = hist_cmd[1].split
            puts! hist_cmd[1]                       # Echo actual command used to console, as other shells do
        elsif (/^![\d]+$/ =~ cmd)                   # It appears to be a historical command number
            cmd_num = $&[1..-1].to_i                # Strip bang from command #         
            hist_cmd = @history.detect {|h|         # Find history with effective command #
                h[0] == cmd_num
            }
            if hist_cmd.nil?
                puts! "Command ##{cmd_num} not found."
                return nil
            end
            puts! hist_cmd[1]                       # Echo actual command used to console, as other shells do
            cmd_a = hist_cmd[1].split               # Use found historical command
        elsif (/^!\w+$/ =~ cmd)                     # It appears to be a historical command prefix
            prefix = $&[1..-1]                      # Strip bang from command prefix
            hist_cmd = @history.reverse.detect {|h| # Find history with effective command prefix
                /^#{prefix}/ =~ h[1]
            }
            if hist_cmd.nil?
                puts! "Command with prefix '#{prefix}' not found."
                return nil
            end
            puts! hist_cmd[1]                       # Echo actual command used to console, as other shells do
            cmd_a = hist_cmd[1].split               # Use found historical command
        elsif (/^#\d+$/ =~ cmd)
            svr_id = $&[1..-1].to_i                
            @client_lock.synchronize do
                if (svr_id >= 1) && (svr_id <= @ucli_servers.length)
                    @drb_server = @ucli_servers[svr_id-1]
                    @server_id = svr_id
                    # cmd_a is passed back as initialized above
                else
                    puts! "Error: invalid server number - valid server numbers at this moment are 1...#{@ucli_servers.length}"
                    return nil
                end
            end
        end
        cmd_a
    end

    def command_requires_server(command)
        cmd = @commands_with_help.detect { |c|
            command == c[0]
        }
        # if command is unknown or is known but marked as requires server then return true
        return cmd.nil? || (cmd[1] == true) 
    end
    
    # Clean dynamic resources as necessary to keep client under control
    def cleanup
        
        # Remove/dereference finished tasks from task list so GC can clean them up.
        @tasks_lock.synchronize {
            live_tasks = []
            @tasks.each { |task|
                live_tasks << task if task.status
            }
            @tasks = live_tasks
        } if @tasks.length > MAX_TASKS_LENGTH
        
    end
    
    #
    #   Support (non-CLI command) methods
    #
    
    # Launch thread to ping server and advise user if server can't be connected to.
    def launch_server_pong
        @server_ping_thread = Thread.new do
            sleep @server_ping_frequency    # Give server connections a chance to come up - sleep first, then loop
            loop do
                @ucli_servers.each { |svr|
                    pong_(svr, 2, 0, 0)
                    # spread pongs out over the range of time over which to check the servers;
                    # This way the pongs don't create as much overhead on the client.
                    sleep @server_ping_frequency / @ucli_servers.length
                }
            end
        end
    end

    def connect_to_all_ucli_servers
        @client_lock.synchronize do
            unless @ucli_servers.nil? || @ucli_servers.length == 0
                svr_num = 1
                @ucli_servers.each { |uvm|
                    message "Connecting to #{@server_name} ##{svr_num}: #{uvm[0]}:#{uvm[1]}...\n", 1
                    uvm[2] = DRbObject.new(nil, "druby://#{uvm[0]}:#{uvm[1]}")
                    svr_num += 1
                }
                @drb_server = @ucli_servers[0]
                @server_id = 1
            end
        end
    end

    # Cleanly shutdown the CLI
    def shutdown
        @tasks.each { |t| t[0].join }  # wait for any remaining background tasks to complete.
    end
    
    # Display message to console IFF message level is <= verbosity level
    def message(msg, level=1)
        puts! msg unless level > @verbose
    end

    # Pong (ie, "ping") server and issue messages based on given message levels for each type of server response.
    def pong_(svr, success_msg_lvl=2, error_msg_lvl=0, failure_msg_lvl=0)
        begin
            expected_response = "pong"
            response = svr[2].pong(expected_response);
            if response != expected_response
                message "\n#{@server_name} at #{svr[0]}:#{svr[1]} responded incorrectly to pong: #{response}.", error_msg_lvl
            else
                message "#{@server_name} at #{svr[0]}:#{svr[1]} appears to be responsive.", success_msg_lvl
            end
        rescue Exception => ex
            message "\nUnable to contact #{@server_name} at #{svr[0]}:#{svr[1]}: " + ex + "\n", failure_msg_lvl
        end
    end
   
    #
    #   CLI Command Handlers
    #
    
    # Assume unknown commands, i.e., missing methods, are requests to run some external
    # Linux command.  If command prefixed by ':' then run locally, else run remotely on server.
    def method_missing(method_id, *args)
        begin
            cmd = method_id.id2name
            if /^:/ =~ cmd
                if cmd.length > 1
                    res = system(cmd.slice(1,cmd.length-1) + ' '  + args.join(' '));  # execute command locally - output will go to console
                    puts! "Error - command not found." unless res
                else
                    raise Exception, "malformed command."
                end
            elsif /^#/ =~ cmd   # trap server select and do nothing, so command is added to history.
                return 
            else
                server = nil
                @client_lock.synchronize do
                    server = @drb_server[2]
                end
		# *** WIP
                res = server.execute(cmd + ' ' + args.join(' '));  # execute command on remote server host - print output to console
                #res = server.__send__(cmd + ' ' + args.join(' '));  # execute command on remote server host - print output to console
                res.each { |r| puts! r } if res
            end
        rescue Exception
            puts! "Error: invalid, malformed or unknown command '#{cmd}'."
        end
    end
    
    # Display UCLI help info
    def help(*args)
        print "\nSupported commands: #{@commands.join(', ')}\n"
        @commands_with_help.sort{|x,y| x <=> y }.each { |c| print "- #{c[0]} - #{c[2]}\n" unless c[2].nil? }
        print! <<-HERE
- module-name help - Get help on commands supported by a module: webfilter help
- #X - Select UVM server number X for subsequent commands.
- !! - Execute last/most recent command
- !{number} - Execute historical command 'number'
- !{prefix} - Execute most recent historical command beginning with 'prefix'
- command - Execute non-UCLI command on UCLI server host.
- :command - Execute non-UCLI command on UCLI client host.
- When entering a command, press [Tab] for command auto-completion.
    
        HERE
    end
    
    # Quit: exit w/confirmation
    def quit(*args)
        print! "Are you sure [y/n]? "
        exit(args) if STDIN.gets.chomp.downcase == "y"
    end

    # Exit w/out confirmation
    def exit(*args)
        raise Interrupt, "exiting..."
    end

    # Display command history in console    
    def history(*args)
        @history.each { |h| puts! "[#{h[0]}] #{h[1]}" }
    end
    
    # Pass the given Ruby code to the UCLI server for execution.
    # Argument can either be a text String or file containing Ruby code.  UCLI Server
    # taint level may restrict certain code from being executed for security reasons.
    def ruby(*args)
        begin
            server = nil
            @client_lock.synchronize do
                server = @drb_server[2];
            end
            if File.exist?(args[0])
                server.ruby(IO.read(args[0]))
            else
                server.ruby(args.join(' '))
            end
        rescue DRb::DRbConnError
            puts! "Unable to connect to #{@server_name} at #{@server_host}:#{@server_port} - is the #{@server_name} running (try the 'pong' command to check)?"
        rescue Exception => ex
            puts! "Unable to run the given code - server returned the following error(s):\n" + ex
        end        
    end

    # Disable all but alert level messages, ie, message w/level < 0
    def quiet
        @verbose = 0
    end
    
    # Set verbose level - it no arg provided then display the current level.
    def verbose(*args)
        begin
            if args.nil? || args.length == 0
                puts! @verbose
            else
                @verbose = args[0].to_i
            end
        rescue Exception # catch failure to convert args[0] to an integer
            puts! "Invaid verbose setting #{args[0]}: must be an integer."
        end
    end

    # Check effective server responsiveness with all message levels set to alert.
    # ***TODO: add support for "pong #X", to pong a server w/out changing the active server.
    def pong(*args)
        server = nil
        @client_lock.synchronize do
            server = @drb_server
        end
        pong_(server, -1, -1, -1)
    end
    
    # List open/connected-to UCLI servers and display in console.
    def servers(*args)
        servers = nil
        @client_lock.synchronize do
            servers = @ucli_servers;
        end
        unless servers.length == 0
            svr_num = 1
            servers.each { |svr|
                puts! "##{svr_num}: #{svr[0]}:#{svr[1]}"
                svr_num += 1
            }
        else
            puts! "There are no servers currently open."
        end
    end

    # Open a connection to a UCLI sever and add to open servers list.
    def open(*args)
        # Validate host address format
        server_to_open = args[0].split(':')
        if (server_to_open.length != 2) || !(server_to_open[1] =~ /\d+/)
            puts! "Error: invalid server address - valid addresses are of the form (host-name|ip):port"
            return
        end

        # Ensure server is not already opened
        servers = nil
        @client_lock.synchronize do
            found = @ucli_servers.detect { |svr|
                # found if host name and port match  ***TODO: what if IP of an open host is used or visa versa?
                (svr[0] == server_to_open[0]) && (svr[1] == server_to_open[1].to_i)
            }
            if found
                puts! "Server #{args[0]} is aleady open (type 'servers' to review open servers.)"
                return
            end
        
            # Connect to server and add to list of open servers
            @ucli_servers << [server_to_open[0], server_to_open[1], DRbObject.new(nil, "druby://#{server_to_open[0]}:#{server_to_open[1]}")]
            @drb_server = @ucli_servers[-1]
            @server_id = @ucli_servers.length
        end
    end
    
    # Dymamically collect UCLI client commands and apply them to list of servers, e.g.,
    #   with #2 #3
    #   [1] pong
    #   [2] webfilter list
    #   [3] end
    # Note: all commands are sent to one server before going on to the next server. "-i" as the final
    # argument does so in interactive mode, ie, user is prompted before sending commands to each server.
    def with(*args)

        # Fetch state we'll need to restore when we're done
        ucli_servers = nil
        server_id = nil
        drb_server = nil
        tasks = nil
        @client_lock.synchronize {
            ucli_servers = @ucli_servers
            server_id = @server_id
            drb_server = @drb_server
        }
        @tasks_lock.synchronize {
            tasks = @tasks
            @tasks = []
        }
        
        if args.length >= 1
            interactive = args[args.length-1] == "-i"
            args.pop if interactive
        end

        # Get list of server ids to which the 'with' commands shall be applied
        if args.length < 1
            # if no server given then apply to the current server
            svr_ids = [server_id]
        elsif args[0] == "##"
            # if '##' given then apply to all open servers
            svr_ids = Array.new(ucli_servers.length)
            svr_ids.fill {|i| i + 1}
        else
            begin 
                svr_ids = args.join(' ').delete('#').split
                svr_ids.each_with_index { |n,i| svr_ids[i] = n.to_i }
                svr_ids.uniq!
                svr_ids.each { |id|
                    raise Exception if (id < 1) || (id > ucli_servers.length)
                }
            rescue Exception
                # Catches all server id errors, ie, to_i failure, # out of range, etc.
                puts! "Error: Invalid server number(s) given."
                return
            end
        end
            
        # Read commands in local loop to apply to server list
        cmd_num = 1
        commands = []
        loop do
            cmd_s = readline("[#{cmd_num}] ", true)
            next if cmd_s.nil? || cmd_s.length == 0
            break if cmd_s == "end"
            if FORBIDDEN_WITH_COMMANDS.include?(cmd_s) || (cmd_s =~ /^[!#].*/)
                puts! "Error: '#{cmd_s}' is not allowed within a 'with' script."
                next
            end
            commands << cmd_s
            cmd_num += 1
        end
            
        return if commands.length < 1   # nothing to do

        # Send commands to each server...
        begin            
            svr_ids.each { |svr_id|
                @client_lock.synchronize {
                    @drb_server = ucli_servers[svr_id-1]
                }
                
                if interactive
                    print! "Send 'with' commands to server ##{svr_id} (y/n)? "
                    raise UserCancel, "user interrupt" if !getyn("y")
                end
                
                # Must not hold client lock while running commands, as certain commands need the lock.
                commands.each { |cmd|
                    puts! cmd if interactive
                    cmd_a = run_command(cmd)
                    raise Interrupt if cmd_a.nil?
                }
            }
        rescue UserCancel
            puts! "With script halted by user."
        rescue Interrupt
            puts! "Error: 'with' command '#{cmd}' failed -- halting 'with' processing."
        rescue Exception => ex
            puts! "Error: 'with' command processor encountered an unhandled exception: " + ex
        ensure
            @tasks_lock.synchronize {
                @tasks.each { |t| t[0].join }   # wait for any tasks spawned by this 'with script' to finish
                @tasks = tasks                  # BEFORE restoring state of @tasks and @drb_server
            }
            @client_lock.synchronize {
                @drb_server = drb_server
            }
        end
            
    end

    #def policies(*args)
        #@drb_server[2].getPolicies
    #end
    
    # List all active tasks
    def tasks(*args)
        @tasks_lock.synchronize {
            @tasks.each { |task|
                puts! "[#{task[2]}] #{task[1]}" if task[0].status
            }
        }
    end
    
    # Send a webfilter command to server.
    def webfilter(*args)
        puts! @drb_server[2].webfilter(args)
    end

end # UCLIClient

if __FILE__ == $0

#
#   Main loop: continue to recreate and run CLI until a valid quit is encountered.
#
loop do
    ucli_client = UCLIClient.new(ARGV)
    
    begin
        ucli_client.run
        raise RuntimeError, "command interpreter returned unexpectedly."
    rescue Interrupt
        ucli_client.shutdown
        break
    rescue Exception => ex
        puts "#{ucli_client.client_name} has encountered techinical difficulties: " + ex
        p ex
        puts "Restarting #{ucli_client.client_name}...\n"
    end
    
    ucli_client.shutdown
end

exit(0)

end # if __FILE__
