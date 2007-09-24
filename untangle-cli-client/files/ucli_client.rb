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
require 'ucli_common'
include UCLICommon

#
# The UCLI Client effects a command line interface used to send operational and diagnostic
# commands to an Untangle server and to the filter nodes running on it.  The UCLIClient
# functionality current includes (as of 9/5/07):  ***TODO: NEEDS TO BE UPDATED.
#   1) Command line editing with history.
#   2) Quick commands via reference to historical commands, e.g., !2, !eval, which would run
#       command #2 or the most recent command beginning with the prefix "eval", respectively.
#   3) The ability to send raw Ruby code, either as a command line or as a file, to the Untangle
#       server for execution there.
#   4) Commands, both UCLI internal and external (ie, system commands) can be sent to the
#       effective UCLI server or to the host of the UCLI client.
#   5) Commands beginning with an Untangle UVM node name are passed to the UCLI server along
#       along with any command arguments for execution.
#   6) Inline command scripts can be written in the UCLI client console and routed to
#       multiple UCLI servers using the "with" command.
#
# Note that the UCLIClient can be caused to reinitialize itself without shutting down by sending
# its process a SIGHUP, i.e., kill -1.
#
# To Do:
#   - Save history to file
#   - Autoload, ie, .uclirc file.
#   - Logon/log off - how?  Server ACL with password?
#   - Feedback for failed remote command
#   - history N
#   - tasks command to review background tasks
#
# Open Issues:
#   - Do we need to save/load history?
#   - Do we need a .ucli file so various settings can be runtime configured per user?
#   - Should the history indicator character, i.e., '!', be abstacted?
#   - Is a DRb.service_shutdown required?
#   - Do we need aliases?
#
class UCLIClient
   
    # Constants
    DEFAULT_PORT = 7777
    FORBIDDEN_BACKGROUND_COMMANDS = %w{ with ^#\d }     # commands that cannot be run in the background
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
        @config_filename = ".ucli"
        @running = false
        @cmd_num = 1
        @history = []
        @history_size = 50
        @history_lock = Mutex.new
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
            ["close #X", true, "close connection to #{@server_name} #X -- close #1"],
            ["servers", true, "list servers currently under management by this #{client_name} session."],
            ["webfilter #X", true, "Send command to webfilter #X -- enter 'webfilter help' for details."],
            ["with <server #s|##> <-i>]", true, "Send multiple commands to servers #, #..., ## for all servers, -i for interactive -- with #1 #2 ..."],
            ["tasks", false, "List all background tasks currently running."],
            ["cleanup", false, "Cleanup client resources, e.g., garbage collect, release stored task outputs, etc."],
            ["source", false, "Source (i.e., run) the given script (use '.' as shortcut) -- source file or . file"],
            ["%X", false, "Display output of background task 'X' -- %1"],
            ["#X", true, "Switch effective server to server ID 'X' -- #3"],
            # The following are not top level commands but are included here so tab completion will support them.
            ["localhost", false, nil],
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
        @drb_server = nil                   # Active drb server from uvm_servers array (defined below.)
        @server_id = 0
        @servers_lock = Mutex.new       # Obtain this lock before manipulating any of the server related objects.
        
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
            @servers_lock.synchronize do
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
        if @running
            puts! "${client_name} main loop is not reenterant."
            return
        else
            @running = true
        end
        connect_to_all_ucli_servers
        launch_server_pong
        print! @welcome
        
        loop do
            cmd_s = readline("[##{@server_id}:#{@cmd_num}] ", true)
            next if (cmd_s.nil? || cmd_s.length == 0)

            cmd_a = run_command(cmd_s)
            next if cmd_a.nil?
            
            # Only commands entered into the top level "shell" are added to the session history
            @history_lock.synchronize {
                @history.shift unless @history.length < @history_size
                @history << [@cmd_num,cmd_a.join(' '),@server_id]
                @cmd_num += 1
            }
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
                if (/#{cmd}/ =~ cmd_a[0])
                    puts! "Error: '#{cmd_a[0]}' may not be executed in the background."
                    return
                end
            }
            cmd_a.pop # remove '&' from arg list - background tasks are handled WITHIN this client and not by the system that runs the command in the back ground.
            
            # Cache effective drb server object BEFORE launching thread - this way if
            # the user or a command changes the effective server while the thread is
            # starting up we won't be effected, ie, caused to send any server commands
            # to the wrong server.
            drb_server = nil
            @servers_lock.synchronize { drb_server = @drb_server[2] }
            
            @tasks_lock.synchronize {
                # must store task record before creating thread so command processor can tell if the command is in the background or not.
                task_index = @task_num-1
                @tasks[task_index] = [nil, cmd_s, @task_num, true, ""]  # [ task thread, cmd string, task num, background?, output]
                t = Thread.new(task_index) { |t_idx|
                    Thread.current[:drb_server] = drb_server
                    Thread.current[:task_index] = t_idx
                    Thread.current[:background] = true
                    res = self.__send__(*cmd_a);
                    @tasks_lock.synchronize { @tasks[t_idx][4] = res }
                    puts! "\nDone (#{cmd_a.join(' ')}) - use command '%#{t_idx+1}' to view output."
                }
                @tasks[task_index][0] = t
                @task_num += 1
            }
            
            cmd_a << "&" # restore popped '&'
        else
            self.__send__(*cmd_a)
        end
        cmd_a   # return command components IFF command is run, whether or not its succesful.
    end
    
    
    # Preprocess a pending command: perform history replacement, etc.
    def preprocess(cmd)
        cmd_a = shellwords cmd
        cmd = cmd_a[0].strip
        
        # Check for meta-commands first, ie, histrory, etc.
        @history_lock.synchronize {
            
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
            elsif cmd_a[0] == "."
                cmd_a[0] = "source"                     # convert abbr. for script source command                     
            elsif (/^\..*/ =~ cmd)
                cmd_a = cmd.split('.')
                cmd_a[0] = "source"                     # convert abbr. for script source command                     
            end
        }
        cmd_a
    end

    def command_requires_server(command)
        cmd = @commands_with_help.detect { |c|
            command == c[0]
        }
        # if command is unknown or is known but marked as requires server then return true
        # (unknown commands may be system commands which require our server to be running
        # in order for them to be run.)
        return cmd.nil? || (cmd[1] == true) 
    end
    
    # Clean dynamic resources as necessary to keep client under control
    def cleanup
        
        # Remove/dereference resources held by finished tasks so GC can clean them up.
        @tasks_lock.synchronize {
            @tasks.each_with_index { |task,i|
                if task[0] && !task[0].status
                    @tasks[i] = [nil, nil, nil, nil]
                end
            }
        }
        
    end
    
    #
    #   Support (non-CLI command) methods
    #
    
    # Launch thread to ping server and advise user if server can't be connected to.
    def launch_server_pong
        @server_ping_thread = Thread.new do
            loop do
                sleep @server_ping_frequency
                @servers_lock.synchronize do
                    @ucli_servers.each { |svr|
                        pong_(svr, 2, 0, 0)
                    }
                end
            end
        end
    end

    # ***TODO: perhaps refactor this code to use open(), so the DRB logic is not duplicated.
    def connect_to_all_ucli_servers
        @servers_lock.synchronize do
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
    
    def method_missing(method_id, *args)
        
        begin
            cmd = method_id.id2name
            if /^:/ =~ cmd          # request to run a local system command
                if cmd.length > 1
                    cmd = cmd.slice(1,cmd.length-1)
                    if (args.length > 0) then cmd << (' '  + args.join(' ')) end
                    @diag.if_level(3) { puts! "Executing '#{cmd}'" }
                    begin
                        pipe = IO.popen(cmd, "r")   # note pipe is half duplex so no need to close_write
                        lines = []
                        pipe.readlines.each { |line|
                            puts! line unless Thread.current[:background]
                            lines << line
                        }
                        return lines
                    rescue IOError => ex
                        err = "Error: unable to execute '#{cmd}' - command not found or not executable."
                        @diag.if_level(3) { puts! err ; p ex }
                        return nil
                    end
                else
                    raise Exception, "malformed command."
                end
            elsif /^#\d+/ =~ cmd            # request to change effective server
                svr_id = $&[1..-1].to_i                
                @servers_lock.synchronize do
                    if (svr_id >= 1) && (svr_id <= @ucli_servers.length)
                        @drb_server = @ucli_servers[svr_id-1]
                        @server_id = svr_id
                        # cmd_a is passed back as initialized above
                    else
                        puts! "Error: invalid server ID - use the 'servers' command for a list of valid server IDs"
                        return nil
                    end
                end
            elsif (/^%\d+$/ =~ cmd)     # request to display output of task %X
                output = get_task_output($&[1..-1].to_i)
                output.each { |line| puts! line } if output
            else    # send unknown method request to server for processing
                server = Thread.current[:drb_server]
                @servers_lock.synchronize do
                    server = @drb_server[2]
                end unless server

                res = server.__send__(cmd, args);
                res.each { |r| puts! r } if res && !Thread.current[:background]
                return res
            end
        rescue Exception => ex
            puts! "Error: invalid, malformed or unknown command '#{cmd}' - " + ex
            @diag.if_level(2) { p ex }
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
        @history_lock.synchronize {
            if args.nil? || args.length == 0
                @history.each { |h| puts! "[#{h[0]}] #{h[1]} (##{h[2]})"}
            elsif /^#\d+/ =~ args[0]
                begin
                    svr_id = $&[1..-1].to_i
                    raise Exception if svr_id < 1 || svr_id > @ucli_servers.length
                    @history.each { |h| puts! "[#{h[0]}] #{h[1]}" if h[2] == svr_id }
                rescue Exception => ex
                    puts! "Error: invalid server number."
                    @diag.if_level(3) { p ex }
                    return
                end
            end
        }
    end
    
    # Pass the given Ruby code to the UCLI server for execution.
    # Argument can either be a text String or file containing Ruby code.  UCLI Server
    # taint level may restrict certain code from being executed for security reasons.
    def ruby(*args)
        begin
            server = Thread.current[:drb_server]
            @servers_lock.synchronize do
                server = @drb_server[2];
            end unless server
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

    # ***TODO: add support for "pong #X", to pong a server w/out changing the active server.
    def pong(*args)
        server = nil
        @servers_lock.synchronize do
            server = @drb_server
        end
        pong_(server, -1, -1, -1)
    end

    # List open/connected-to UCLI servers and display in console.
    def servers(*args)
        servers = nil
        @servers_lock.synchronize do
            servers = @ucli_servers;
        end
        unless servers.length == 0
            svr_num = 1
            servers.each { |svr|
                puts! "##{svr_num}: #{svr[0]}:#{svr[1]}" if svr[2]
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
        @servers_lock.synchronize do
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
            
            puts! "#{args[0]} opened as server ##{@server_id}"
        end
        pong []
    end
    
    # Open a connection to a UCLI sever and add to open servers list.
    def close(*args)

        puts! "Close not yet implemented."
        return
    
        #if /^#\d+/ =~ args[0]
        #    svr_idx = ($&[1..-1].to_i) - 1
        #else
        #    puts! "Error: invalid server number."
        #    return
        #end
        #
        #@servers_lock.synchronize do
        #    closed_server = @ucli_servers[svr_idx][2]
        #    @ucli_servers[svr_idx] = [nil,nil,nil]
        #    if closed_server == @drb_server
        #        
        #    end
        #end
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
        @servers_lock.synchronize {
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

        source_file = nil
        if args.length >= 1
            source_file = args.pop if File.exist?(args[args.length-1])
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
        commands = []
        if source_file
            begin
                commands = File.readlines(source_file)
            rescue Exception => ex
                puts! "Error: can't read 'with' script '#{source_file}'"
                @diag.if_level(3) { p ex }
            end
        else
            cmd_num = 1
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
        end
        
        return if commands.length < 1   # nothing to do

        # Code to disallow with scripts with background tasks.        
        #commands.each_with_index { |cmd,i|
        #    if /.*&$/ =~ cmd
        #        puts "Error: 'with' scripts may not run tasks in the background (see line #{i+1})"
        #        return
        #    end
        #}

        # Send commands to each server...
        begin            
            svr_ids.each { |svr_id|
                @servers_lock.synchronize {
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
                    raise CommandFiled if cmd_a.nil?
                }
            }
        rescue UserCancel
            puts! "With script halted by user."
        rescue CommandFailed
            puts! "Error: 'with' command '#{cmd}' failed -- halting 'with' processing."
        rescue Interrupt
            puts! "With script interrupted."
        rescue Exception => ex
            puts! "Error: 'with' command processor encountered an unhandled exception: " + ex
        ensure
            puts! "With: waiting for background tasks to complete." if @tasks.length > 0
            @tasks_lock.synchronize {
                @tasks.each { |t| t[0].join }   # wait for any tasks spawned by this 'with script' to finish
                @tasks = tasks                  # BEFORE restoring state of @tasks and @drb_server
            }
            @servers_lock.synchronize {
                @drb_server = drb_server
            }
        end
            
    end

    # List all active tasks
    def tasks(*args)
        @tasks_lock.synchronize {
            @tasks.each { |task|
                if task[0]
                    t = "[#{task[2]}] #{task[1]}"
                    t << (task[0].status ? " (in progress)" : " (done)")
                    t << " '#{task[4][0].slice(0,20)}...'" unless
                    puts! t
                end
            }
        }
    end

    def get_task_output(task_num)
        @tasks_lock.synchronize {
            if task_num < 1 || task_num > @tasks.length
                puts! "Error: invalid task number."
                return []
            elsif @tasks[task_num-1][4].nil?
                puts! "Error: task #{task_num} had no output or has already been cleaned up - output not available."
                return []
            else
                return @tasks[task_num-1][4]
            end
        }
    end
    
    def save(*args)
        if args.length < 2
            puts! "Error: missing argument(s) - save requires a task ID and a filename."
            return
        end
        
        if /^%\d+$/ =~ args[0]
            begin
                output = get_task_output($&[1..-1].to_i)
                if output.nil? || output.length < 1
                    puts "Error: task #{args[0]} has no output to save."
                    return
                end
            
                if File.exists? args[1]
                    print! "File '#{args[1]}' already exists - overwrite (y/n)? "
                    return unless getyn("y")
                    File.delete args[1]
                end
                
                File.open(args[1], "w") { |f|
                    output.each { |l| f.write l }
                }
            rescue NoMethodError => ex
                puts! "Error: invalid task ID '#{args[0]}'}"
                @diag.if_level(3) { p ex }
            rescue Exception => ex
                puts! "Error: unable to write to file '#{args[1]}'."
                @diag.if_level(3) { p ex }
            end
        else
            puts! "Error: invalid task ID '#{args[0]}'"
        end
    end

    def source(*args)
        if args.nil? || args.length < 1
            puts! "Error: invalid arguments - run requires the name of a file to source."
            return
        end
        if !File.exists? args[0]
            puts! "Error: script file '#{args[0]}' not found."
            return
        end
        
        begin
            interactive = (args[-1] == "-i")
            script = File.readlines(args[0])
            script.each { |cmd|
                cmd.chomp!
                puts! cmd if interactive
                run_command cmd if cmd && cmd != ""
            } unless script.nil? || script.length == 0
        rescue Exception => ex
            puts! "Error: unable to open or read from file '#{args[0]}' - check permissions."
            @diag.if_level(3) { p ex }
        end
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
