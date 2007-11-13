#!/usr/local/bin/ruby
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

require 'drb'
require 'readline'
include Readline
require 'abbrev'
require 'optparse'
require 'thread'
require 'shellwords'
include Shellwords
require 'getoptlong'
    
require 'common'
include NUCLICommon
require 'util'
include NUCLIUtil

#
# The NUCLI Client effects a command line interface used to send operational and diagnostic
# commands to an Untangle server and to the filter nodes running on it.  The NUCLIClient
# functionality current includes (as of 9/5/07):  ***TODO: NEEDS TO BE UPDATED.
#   1) Command line editing with history.
#   2) Quick commands via reference to historical commands, e.g., !2, !eval, which would run
#       command #2 or the most recent command beginning with the prefix "eval", respectively.
#   3) The ability to send raw Ruby code, either as a command line or as a file, to the Untangle
#       server for execution there.
#   4) Commands, both NUCLI internal and external (ie, system commands) can be sent to the
#       effective NUCLI server or to the host of the NUCLI client.
#   5) Commands beginning with an Untangle UVM node name are passed to the NUCLI server along
#       along with any command arguments for execution.
#   6) Inline command scripts can be written in the NUCLI client console and routed to
#       multiple NUCLI servers using the "with" command.
#
# Note that the NUCLIClient can be caused to reinitialize itself without shutting down by sending
# its process a SIGHUP, i.e., kill -1.
#
# To Do:
#   - Save history to file
#   - Autoload, ie, .uclirc file.
#   - Logon/log off - how?  Server ACL with password?
#   - Feedback for failed remote command
#   - history N
#   - jobs command to review background jobs
#
# Open Issues:
#   - Do we need to save/load history?
#   - Do we need a .ucli file so various settings can be runtime configured per user?
#   - Should the history indicator character, i.e., '!', be abstacted?
#   - Is a DRb.service_shutdown required?
#   - Do we need aliases?
#
class NUCLIClient
   
    # Constants
    DEFAULT_PORT = 7777
    FORBIDDEN_BACKGROUND_COMMANDS = %w{ with ^#\d+ } # commands that cannot be run in the background.
    FORBIDDEN_WITH_COMMANDS = %w{ open quit exit with history jobs servers } # commands that cannot be used in a with script.
    FORBIDDEN_COMMAND_LINE_COMMMANDS = %w{ with quit exit history jobs }
    
    # Accessors
    attr_accessor :use_ssh_tunnels, :user
    
    #
    #   Initialization related methods
    #
    def initialize(options)
        init(options)
        begin
            DRb.start_service
        rescue Exception => ex
            message "Fatal error: unable to start DRb server - terminating."
            p ex
            exit(-1)
        end
    end

    def init(options)
        # Setup defaults
        @client_name = "NUCLI Client"
        @server_name = "NUCLI Server"
        @config_filename = ".ucli"
        @running = false
        @history = []
        @history_size = @history_num_to_display = 50
        @history_lock = Mutex.new
        @welcome = "\nWelcome to the #{@client_name} - type 'help' for assistance.\n\n"
        @server_ping_thread = nil
        @server_ping_frequency = 120 # in seconds
        @verbose = 2
        @jobs = []
        @jobs_lock = Mutex.new
        @job_num = 1
        @diag = Diag.new(3)
        @commands_to_execute = []
        @use_ssh_tunnels = false
        @user = 'root'
        
        # Commands legend and creation of readline auto-completion abbreviations
        @commands_with_help = [
            # Cmd name, Server Required, Help text
            ["loadrules", false, "load rules into filter node from given file -- loadrules webfilter filename", nil],
            ["history", false, "display command history, up to #{@history_size} events", nil],
            ["ruby", true, "send Ruby code to sever for execution -- ruby statement | file", nil],
            ["quiet", false, "quiet all but alert level messages", nil],
            ["verbose", false, "set level of messages/chatter from client -- verbose [integer>=0]", nil],
            ["pong", true, "test responsiveness of NUCLI server", nil],
            ["quit", false, "terminate after user confirmation", nil],
            ["exit", false, "terminate immediately", nil],
            ["help", false, "display help information", nil],
            ["open", false, "open connection to server -- open (host-name|ip):port [-l user]", nil],
            ["close", false, "close connection to server #X or host-name -- close #1", nil],
            ["servers", false, "list servers currently under management during this  session.", nil],
            ["webfilter", true, "send command to webfilter -- enter 'webfilter help' for details.", nil],
            ["firewall", true, "send command to firewall -- enter 'firewall help' for details.", nil],
            ["with", true, "send multiple commands to servers, '##' or 'all' for all servers, '-i' for interactive, '-e' for echo -- with host-name #2 #4 -i -e", nil],
            ["jobs", false, "list all background jobs currently running.", nil],
            ["cleanup", false, "cleanup client resources, e.g., release stored job outputs, etc.", nil],
            ["source", false, "source (i.e., run) the given script (use '.' as shortcut) -- source filename or . filename", nil],
            ["%X", false, "display output of background job 'X' -- %1", nil],
            ["#X", false, "switch effective server to server 'X' -- #3", nil],
            ["save", false, "save output stored with job %X to filename -- save %3 myoutput.txt", nil],
            [":command", false, "run external command on local host -- :ls /tmp", nil],
            ["command", false, "run external command on server host -- who", nil],
            ["^%\\d+$", false, nil],
            ["backup", false, "backup #{BRAND} server settings -- backup [to_disk|to_usb|to_file <filename>]", nil],
            ["restore", false, "restore #{BRAND} server settings from local file -- restore <filename.backup>]", nil],
            # The following are not top level commands but are included here so they can be part of the
            # word completion list we pass to readline.  These can be distinguished and filtered from 
            # this list by noting that they have nil for their help text settings.
            ["localhost", false, nil],
            ["block-list", false, nil],
            ["block", false, nil],
            ["pass-list", false, nil],
            ["pass", false, nil],
            ["category", false, nil],
            ["categories", false, nil],
            ["url", false, nil],
            ["mime", false, nil],
            ["file", false, nil],
            ["add", false, nil],
            ["remove", false, nil],
            ["client", false, nil],
            ["localhost", false, nil]
        ]
        @commands = []
        @commands_with_help.each {|cmd|
            @commands << cmd[0]
        }
        @abbrevs = @commands.abbrev
        Readline.completion_proc = proc do |string|
            @abbrevs[string]
        end
        
        # We start w/no uvm servers: server can be loaded and opened via our dot file
        # and/or specified via a command line options.
        @ucli_servers = []
        @drb_server = nil                   # Active drb server from uvm_servers array (defined below.)
        @server_id = 0
        @servers_lock = Mutex.new           # This lock guards @ucli_servers, @drb_server, and @server_id.
        
        # Process config file
        process_config_file(@config_filename) if @config_filename
        
        # Process command line options
        process_options(options) if options
    end

    # Process command line options    
    def process_options(options)
        opts = OptionParser.new
        opts.banner = "Usage: #{File.basename(__FILE__)} [OPTIONS]"
        ucli_server_host = 'localhost'
        opts.on("-h", "--host HOST", String, "NUCLI server host name or IP address.") { |host|
            ucli_server_host = host
        }
        ucli_server_port = DEFAULT_PORT
        opts.on("-p", "--port PORT", Integer, "NUCLI server port number.") { |port|
            ucli_server_port = port
        }
        opts.on("-?", "--help", "Display help.") {
            puts! opts.to_s
            exit(0)
        }
        opts.on("-c", "--command COMMAND", String, "NUCLI command to execute.") { |command|
            @commands_to_execute << command
        }
        opts.on("-u", "--user USERNAME", String, "User to login to NUCLI server as.") { |user|
            @user = user
        }
        opts.on("-t", "--use-ssh-tunnel", "Enable SSH tunneling.") { |user|
            @use_ssh_tunnels = true
        }

        remainder = opts.parse(options);
        if remainder.length > 0
            print! "Unknown options encountered: #{remainder}\nContinue [y/n]? "
            raise Terminate, "unknown command line option(s)." unless getyn("y")
        end

        # TODO: If we ever allow more than one server to be opened via command line options
        # then we'll need to ensure the same host:port is not added twice.
        @servers_lock.synchronize do
            @ucli_servers << [ucli_server_host, ucli_server_port, nil];
        end if ucli_server_host

    end
    
    # Process config file settings ***TODO
    def process_config_file(config_filename)
        # TBC
        # When loading lost list, ensure no host:port is added twice, or
        # add a service method to add a new server and it can enfore this
        # for us.
    end

     #
     # Main CLI command loop: read a command line (w/abbreviation/tab-completion support),
     # preprocess it for command history references, execute the command, and add
     # command to history for future reference.
     #
    def run
        if @running then message("${@client_name} main loop is not reenterant.", 0); return; end
        @running = true

        # Execute commands passed in via the command line then return (don't go interactive)        
        if @commands_to_execute != []
            ## Verify all commands before running any of them.  Run none if any are forbidden
            @commands_to_execute.each { |command|
                command.split(';').each { |cmd|
                    if FORBIDDEN_COMMAND_LINE_COMMMANDS.include?(cmd)
                        puts! "Error: '#{cmd}' cannot be used from the command line.'"
                        return
                    end
                }
            }
            connect_to_all_ucli_servers(true)       # connect quietly
            @commands_to_execute.each { |command|
                command.split(';').each { |cmd|
                    begin
                        run_command(cmd.strip)
                    rescue Exception => ex
                        puts! "Error: command '#{cmd}' failed - terminating.'"
                        return
                    end
                }
            }
            return
        end

        # Interactively collect NUCLI commands and execute them, keeping a historical record.
        connect_to_all_ucli_servers
        launch_server_pong
        
        print! @welcome
        
        cmd_num = 1
        loop do
            cmd_s = readline("[#{@drb_server?@drb_server[0]:'none'}:#{cmd_num}] ", true)
            next if (cmd_s.nil? || cmd_s.length == 0)

            cmd_a = run_command(cmd_s)
            next if cmd_a.nil?
            
            # Only commands entered into the top level "shell" are added to the session history
            @history_lock.synchronize {
                @history.shift unless @history.length < @history_size
                server_name = nil
                @servers_lock.synchronize { server_name = @drb_server.nil? ? "(none)" : @drb_server[0] }
                @history << [cmd_num, cmd_a.join(' '), server_name]
            }
            cmd_num += 1
        end
    end
    
    # Runs given command and returns an array of the words composing the command actually run,
    # which may differ from the given command string if, say, history substitution is performed.
    def run_command(cmd_s)
        
        begin
            cmd_a = preprocess(cmd_s)
            return nil if (cmd_a.nil? || cmd_a.length == 0)
            
            # If no server is active and the command is not a local system command and command requires a sever then disallow command.
            @servers_lock.synchronize {
                if (@drb_server.nil? || @drb_server[2].nil?) && !(/^:/ =~ cmd_s) && !(/^#\d+$/ =~ cmd_s) && command_requires_server(cmd_a[0])
                    puts! "Error: There is no open (or selected) #{@server_name} -- a server must be opened and selected before this command can be issued."
                    return nil            
                end
            }
    
            # ***TODO: need to handle case of "foo&", which is distinct from "foo &" (note the space between 'foo' and '&')
            if cmd_a[-1] == "&"
                FORBIDDEN_BACKGROUND_COMMANDS.detect { |cmd|
                    if (/#{cmd}/ =~ cmd_a[0])
                        puts! "Error: '#{cmd_a[0]}' may not be executed in the background."
                        return
                    end
                }
                cmd_a.pop # remove '&' from arg list - background jobs are handled WITHIN this client and not by the system that runs the command in the back ground.
                
                # Cache effective drb server object BEFORE launching thread - this way if
                # the user or a command changes the effective server while the thread is
                # starting up we won't be effected, ie, caused to send any server commands
                # to the wrong server.
                drb_server = server_id  = nil
                @servers_lock.synchronize { drb_server = @drb_server[2]; server_id = @server_id } if @drb_server
                #if drb_server.nil? then puts! "Bug: there is no effective DRb server.  Recommend restarting #{@client_name}."; return; end
                
                @jobs_lock.synchronize {
                    # must store job record before creating thread so command processor can tell if the command is in the background or not.
                    job_index = @job_num-1
                    @jobs[job_index] = [nil, cmd_s, @job_num, true, "", server_id]  # [ job thread, cmd string, job num, background?, output, server_id of job]
                    t = Thread.new(job_index) { |job_idx|
                        Thread.current[:drb_server] = drb_server
                        Thread.current[:job_index] = job_idx
                        Thread.current[:background] = true
                        res = self.__send__(*cmd_a);
                        @jobs_lock.synchronize { @jobs[job_idx][4] = res }
                        puts! "\nDone (#{cmd_a.join(' ')}) - use command '%#{job_idx+1}' to view output."
                    }
                    @jobs[job_index][0] = t
                    @job_num += 1
                }
                
                cmd_a << "&" # restore popped '&'
            else
                self.__send__(*cmd_a)
            end
            return cmd_a   # return command components IFF command is run, whether or not its succesful.
        rescue TypeError
            puts! "#{@client_name} has encountered a 'Type Error'"
            puts! "Try quoting your command to preserve argument types, i.e., '#{cmd_s}'"
            return cmd_a
        end
    end
    
    
    # Preprocess a pending command: perform history replacement, short cut replacement, etc.
    def preprocess(cmd)
        
        cmd = cmd.gsub(/%20/,' ')
        cmd = cmd.gsub(/&$/, ' &') if /[^\s]&$/ =~ cmd  # ensure background job indicator is seen as a separate word in the command (add white space if neccessary)
        cmd_a = shellwords cmd                          # preprocess command with shell-words quoting rules, eg, quoted words are treated as one word, etc.
        cmd = cmd_a[0].strip                            # normalize the effective command word.
        
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
                cmd_a[0] = "source"                     # convert abbr. for script source command (case of ". script" => "source script")              
            elsif (/^\..*/ =~ cmd)
                cmd_a = cmd.split('.')
                cmd_a[0] = "source"                     # convert abbr. for script source command (case of ".script" => "source script")
            elsif (/@.*/ =~ cmd)
                eval("p #{$&}")                         # debugging support: print value of member variable
                return nil                              # terminate command.
            end
        }
        cmd_a
    end

    # if command is unknown or is known but marked as requires an effective and open
    # server to be run then return true (unknown commands may be system commands which
    # require our server to be running in order for them to be run); otherwise return false.
    def command_requires_server(command)
        
        # Pre-create command regexps, once and for all, but only once this
        # command is called, ie, lazy evaluate since we may never need these.
        if @commands_with_help[0][3].nil?
            (0...@commands_with_help.length).each { |i|
                @commands_with_help[i][3] = Regexp.new(@commands_with_help[i][0])
            }
        end
        
        # Now, try to find command in @commands_with_help set.
        cmd = @commands_with_help.detect { |c|
            c[3].match(command) != nil
        }
        
        return cmd.nil? || (cmd[1] == true) 
    end
    
    # Clean dynamic resources as necessary to keep client under control
    def cleanup
        # Remove/dereference resources held by finished jobs so GC can clean them up.
        @jobs_lock.synchronize {
            @jobs.each_with_index { |job,i|
                if job[0] && !job[0].status
                    @jobs[i] = [nil, nil, nil, nil, nil, nil]
                end
            }
        }
        # Force GC now?
    end
    
    # Launch thread to ping server and advise user if server can't be connected to.
    def launch_server_pong
        @server_ping_thread = Thread.new do
            loop do
                sleep @server_ping_frequency
                servers = []
                @servers_lock.synchronize {
                    @ucli_servers.each { |svr| servers << svr if svr[3] } # only pong server if its open
                }
                servers.each { |svr|
                    _pong_(svr, 3, 1, 0)
                }
            end
        end
    end

    # ***TODO: this logic does not protect against opening the same server twice!!!
    def connect_to_all_ucli_servers(quiet=false)
        @servers_lock.synchronize do
            unless @ucli_servers.nil? || @ucli_servers.length == 0
                svr_num = 1
                @ucli_servers.each { |uvm|
                    message("Connecting to #{@server_name} ##{svr_num}: #{uvm[0]}:#{uvm[1]}...\n", 2) unless quiet
                    if !ssh_port_forward_tunnel(uvm[0], uvm[1], @user)
                        puts "Error: unable to connect to #{@server_name} at #{uvm[0]}:#{uvm[1]} -- could not establish SSH tunnel."
                        uvm[2] = nil
                        uvm[3] = false   # mark server NOT open
                    else
                        uvm[2] = DRbObject.new(nil, "druby://localhost:#{uvm[1]}")
                        uvm[3] = true   # mark server open
                    end
                    svr_num += 1
                }
                @drb_server = @ucli_servers[0]
                @server_id = 1
            end
        end
    end

    # Cleanly shutdown the CLI
    def shutdown(quiet=false)
        message("Shutting down...\n", 1) unless (quiet || (@commands_to_execute.length > 0))
        
        # wait for any remaining background jobs to complete.
        @jobs.each { |t| t[0].join }
        
        # shut down all sever connections
        @servers_lock.synchronize {
            @ucli_servers.each {|svr| svr[2].shutdown() if svr[2] }
        }

    end
    
    # Display message to console IFF message level is <= verbosity level
    def message(msg, level=1)
        puts! msg unless level > @verbose
        return level <= @verbose
    end

    # Pong (ie, "ping") server and issue messages based on given message levels for each type of server response.
    # Returns 0 on OK, 1 on bad response, 2 on failure to contact.
    def _pong_(svr, success_msg_lvl=2, error_msg_lvl=0, failure_msg_lvl=0)
        begin
            expected_response = "pong"
            response = svr[2].pong(expected_response);
            if response != expected_response
                message "\n#{@server_name} at #{svr[0]}:#{svr[1]} responded incorrectly to pong: #{response}.", error_msg_lvl
                return 1
            else
                message "#{@server_name} at #{svr[0]}:#{svr[1]} appears to be responsive.", success_msg_lvl
                return 0
            end
        rescue Exception => ex
            message "\nUnable to contact #{@server_name} at #{svr[0]}:#{svr[1]}: " + ex + "\n", failure_msg_lvl
            return 2
        end
    end
   
    # Returns server descriptor [] given either a host-name or a server ID #.
    def get_server(server_id)
        server = nil
        @servers_lock.synchronize {
            if /^#\d+$/ =~ server_id
                svr_id = $&[1..-1].to_i
                server = @ucli_servers[svr_id-1] if svr_id >= 1 && svr_id <= @ucli_servers.length
            else
                server = @ucli_servers.detect { |svr|
                    (svr[0] == server_id) || ("#{svr[0]}:#{svr[1]}" == server_id)
                }
            end
        }        
        server
    end
    
    def get_server_index(server_id)
        server_index = nil
        @servers_lock.synchronize {
            if /^#\d+$/ =~ server_id
                svr_id = $&[1..-1].to_i
                server_index = (svr_id-1) if svr_id >= 1 && svr_id <= @ucli_servers.length
            else
                found_at = 0
                server = @ucli_servers.detect { |server|
                    found = (server[0] == server_id) || ("#{server[0]}:#{server[1]}" == server_id)
                    found_at += 1 unless found
                    found
                }
                server_index = found_at if server
            end
        }        
        server_index
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
                    @diag.if_level(4) { puts! "Executing '#{cmd}'" }
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
            elsif /^#\d+/ =~ cmd            # request to change effective server by server #
                svr_id = $&[1..-1].to_i                
                @servers_lock.synchronize do
                    if svr_id < 1 || svr_id > @ucli_servers.length
                        puts! "Error: invalid server ID - use the 'servers' command for a list of valid server IDs"
                        return nil
                    elsif @ucli_servers[svr_id-1][3] == false
                        puts! "Error: server ##{svr_id} is closed.  Use open to reopen it."
                        return nil
                    else
                        @drb_server = @ucli_servers[svr_id-1]
                        @server_id = svr_id
                        # cmd_a is passed back as initialized above
                    end
                end
            elsif (svr_idx = get_server_index(cmd)) != nil            # request to change effective server by name
                @servers_lock.synchronize do
                    if @ucli_servers[svr_idx][3] == false
                        puts! "Error: server #{cmd} is closed.  Use open to reopen it."
                        return nil
                    else
                        @drb_server = @ucli_servers[svr_idx]
                        @server_id = svr_idx+1
                        # cmd_a is passed back as initialized above
                    end
                end
            elsif (/^%\d+$/ =~ cmd)     # request to display output of job %X
                output = get_job_output($&[1..-1].to_i)
                output.each { |line| puts! line } if output
            else    # send unknown method request to server for processing
                res = send_to_server(cmd, args)
                res.each { |r| puts! r } if res && !Thread.current[:background]
                return res
            end
        rescue Interrupt
            message "Command interrupted.", 2
        rescue Exception => ex
            puts! "Error: invalid, malformed or unknown command '#{cmd}' - " + ex
            @diag.if_level(2) { p ex }
        end
    end

    def send_to_server(cmd, args)
        server = Thread.current[:drb_server] || @servers_lock.synchronize { server = @drb_server[2] }
        res = server.__send__(cmd, args);
        return res
    end
        
    # Display NUCLI help info
    def help(*args)

        # Rebuild supported commands on each call to help in the event new commands
        # have been dynamically loaded since the last call to help.
        supported_commands = []
        @commands_with_help.each { |cmd|
            supported_commands << cmd[0] unless cmd[2].nil?
        }
        print "\nSupported commands: #{supported_commands.sort{|x,y| x <=> y}.join(',')}\n"
            
        @commands_with_help.sort{|x,y| x[0] <=> y[0]}.each { |c|
            print "> #{c[0]} - #{c[2]}\n" unless c[2].nil?
        }
        
        print! <<-HERE
> module-name help - get help on commands supported by a module: webfilter help
> !! - execute last/most recent command
> !{number} - execute historical command 'number'
> !{prefix} - execute most recent historical command beginning with 'prefix'
> command - execute non-NUCLI command on NUCLI server (remote) host.
> :command - execute non-NUCLI command on NUCLI client (local) host.
> Append '&' to any command to run it as a "background" job.
> %N - display output associated with command run as background job 'N'
> When entering a command, press [Tab] for command/word auto-completion.
    
        HERE
    end
    
    # Quit: exit w/confirmation
    def quit(*args)
        print! "Are you sure [y/n]? "
        exit(args) if STDIN.gets.chomp.downcase == "y"
    end

    # Exit w/out confirmation
    def exit(*args)
        raise Terminate, "exiting..."
    end

    # Display command history in console    
    def history(*args)
        @history_lock.synchronize {
            if args.nil? || args.length == 0
                @history.each_with_index { |h,i|
                    puts! "[*#{h[2]}:#{h[0]}] #{h[1]}" if i >= @history.length-@history_num_to_display
                }
            elsif /^\d+/ =~ args[0]
                n = args[0].to_i
                if n < 1 || n > @history_size
                    puts! "Error: invalid history display length."
                    return
                end
                @history_num_to_display = n
                message "History display count set to #{@history_num_to_display}", 2
            elsif /^#\d+/ =~ args[0]
                begin
                    svr_id = $&[1..-1].to_i
                    raise Exception if svr_id < 1 || svr_id > @ucli_servers.length
                    @history.each { |h| puts! "[#{h[0]}] #{h[1]}" if h[2] == svr_id }
                rescue Exception => ex
                    puts! "Error: invalid server number -- " + ex
                    @diag.if_level(3) { p ex }
                end
            end
        }
    end
    
    # Pass the given Ruby code to the NUCLI server for execution.
    # Argument can either be a text String or file containing Ruby code.  NUCLI Server
    # taint level may restrict certain code from being executed for security reasons.
    def ruby(*args)
        output = nil
        begin
            server = Thread.current[:drb_server]
            @servers_lock.synchronize do
                server = @drb_server[2]
            end unless server
            if File.exist?(args[0])
                code = IO.read(args[0])
                output = server.ruby(code)
            else
                output = server.ruby(args.join(' '))
            end
            unless output.nil?
                output = [output] unless output.kind_of? Array
                output.each { |out| puts! out }
            end
        rescue DRb::DRbConnError
            puts! "Unable to connect to #{@server_name} at #{@server_host}:#{@server_port} - is the #{@server_name} running (try the 'pong' command to check)?"
        rescue Exception => ex
            puts! "Unable to run the given code."
            @diag.if_level(3) { p ex }
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
        if args.length == 0
            @servers_lock.synchronize { server = @drb_server }
        else
            server = get_server(args[0])
            if !server then puts! "Error: invalid server ID '#{args[0]}'"; return; end
        end

        _pong_(server, -1, -1, -1) if server
    end

    # List open/connected-to NUCLI servers and display in console.
    def servers(*args)
        servers = nil
        @servers_lock.synchronize do
            servers = @ucli_servers;
        end
        unless servers.length == 0
            servers.each_with_index { |svr,i|
                status = "unknown"
                case _pong_(svr, 444, 444, 444)   # pong to get status but do it quietly
                when 0; status = "responding"
                when 1; status = "not responding"
                when 2; status = "can't contact"
                end
                puts! "##{i+1}: #{svr[0]}:#{svr[1]} (#{status})" if svr[2] && svr[3]
            }
        else
            message "There are no servers currently open.", 1
        end
    end

    # Open a connection to a NUCLI sever and add to open servers list.
    def open(*args)
        # Process arguments: validate host address format, extract ssh user name and sleep time for tunnel.
        server_to_open = args[0].split(':')
        if (server_to_open.length != 2) || !(server_to_open[1] =~ /\d+/)
            puts! "Error: invalid server address - valid addresses are of the form (host-name|ip):port"
            return
        end
        server_to_open[1] = server_to_open[1].to_i
        user = 'root'
        if args[1] == '-l'
            if args[2].nil?
                puts! "Error: -l (login user) option requires a user name."
                return
            end
            user = args[2]
        end
        
        # Ensure server is not already opened
        opened = false
        @servers_lock.synchronize do
            svr_index = 0
            found = @ucli_servers.detect { |svr|
                # found if host name and port match  ***TODO: what if IP of an open host is used or visa versa?
               found = (svr[0] == server_to_open[0]) && (svr[1] == server_to_open[1])
               svr_index += 1 unless found
               found
            }
            if found && found[3] == true
                puts! "Server #{args[0]} is aleady open (type 'servers' to review open servers.)"
                return
            end
            
            # At this point, a server entry was not found OR one was found but it was marked as closed, so we can open it.
            # Estabish ssh tunnel to server_to_open
            ssh_port_forward_tunnel(server_to_open[0], server_to_open[1], @user)
            
            # Open DRb connection to server_to_open
            drb = DRbObject.new(nil, "druby://localhost:#{server_to_open[1]}")
            
            # Create new server entry and if it was not found append it to the servers list;
            # if it was found but it was closed, store the new entry in the same server location
            # it was originally in. A server entry is an array as follows: [host,port,drb object, open/closed]
            new_server = [server_to_open[0], server_to_open[1], drb, true]
            if !found
                @ucli_servers << new_server
                @drb_server = new_server
                @server_id = @ucli_servers.length
            else
                @ucli_servers[svr_index] = new_server
                @drb_server = new_server
                @server_id = svr_index+1
            end
           
            puts! "#{args[0]} opened as server ##{@server_id}"
            opened = true
        end
        pong if opened # pong the server after opening it to inform the user of its status.
    end
    
    # Open a connection to a NUCLI sever and add to open servers list.
    def close(*args)
        invalid_server_id_msg = "Error: invalid server ID"

        # Can't lock whole method because util methods need access to the locks to do their thing. Only lock where needed.
        svr_index = nil
        svr_indices = nil
        if args.length == 0
            # close the currently selected server
            @servers_lock.synchronize { svr_index  = @server_id - 1 }
            svr_indices = [ svr_index ]
        elsif (args[0] == "##") || (args[0] == "all")
            # close all open servers
            svr_indices = Array.new(@ucli_servers.length)
            svr_indices.fill { |i| i }
        else
            # close just the named server IFF the name refers to a valid and open server
            svr_index = get_server_index(args[0])
            if svr_index.nil?
                puts! invalid_server_id_msg + " '#{args[0]}'"; return
            else
                closed = nil
                @servers_lock.synchronize { closed = !@ucli_servers[svr_index][3] }
                if closed then message "Server #{args[0]} is already closed.", 2; return; end
            end
            svr_indices = [ svr_index ]
        end
        
        # All is well: close the server
        @servers_lock.synchronize {
            svr_indices.each { |i|
                # Leave host and port fields in tact so this sever entry can
                # be found and reused should the same server be opened again.
                @ucli_servers[i][2].shutdown()
                @ucli_servers[i][2] = nil     # deref server DRbObject
                @ucli_servers[i][3] = false   # mark server closed
                message "#{@ucli_servers[i][0]}:#{@ucli_servers[i][1]} closed.", 2
            }
            # deselect any server - force use to select the one to use going forward.
            @server_id = 0
            @drb_server = nil
            message "Select an open server or open a new one to continue.", 2
        }
    end

    # Open an ssh tunnel to host:port via port @ localhost
    def ssh_port_forward_tunnel(host, port, user, sleep=5, quiet=false)
        return true if !@use_ssh_tunnels
        tunnel = "ssh -f #{user}@#{host} -L #{port}:localhost:#{port} sleep #{sleep}"
        if !system(tunnel)
            puts! "Error: unable to create ssh tunnel to #{user}@#{host}:#{port}" unless quiet
            return false
        end
        true
    end

    # Dymamically collect NUCLI client commands and apply them to list of servers, e.g.,
    #   with #2 #3
    #   [1] pong
    #   [2] webfilter list
    #   [3] end
    # Note: all commands are sent to one server before going on to the next server. "-i" as the final
    # argument does so in interactive mode, ie, user is prompted before sending commands to each server.
    def with(*args)
        invalid_server_id_msg = "Error: invalid server ID"

        # Fetch state we'll need to restore when we're done
        ucli_servers = nil
        server_id = nil
        drb_server = nil
        jobs = nil
        @servers_lock.synchronize {
            ucli_servers = @ucli_servers
            server_id = @server_id
            drb_server = @drb_server
        }
        @jobs_lock.synchronize {
            jobs = @jobs
            @jobs = []
        }
        
        if args.length >= 1
            if (interactive = args.include?("-i")) then args.delete("-i") end
            if (echo = args.include?("-e")) then args.delete("-e") end
        end

        source_file = nil
        if args.length >= 1
            source_file = args.pop if File.exist?(args[-1])
        end

        # Get list of server ids to which the 'with' commands shall be applied
        svr_index = svr_indices = nil
        if args.length == 0
            # close the currently selected server
            @servers_lock.synchronize { svr_index  = @server_id - 1 }
            svr_indices = [ svr_index ]
        elsif (args[0] == "##") || (args[0] == "all")
            # close all open servers
            svr_indices = Array.new(@ucli_servers.length)
            svr_indices.fill { |i| i }
        else
            svr_indices = []
            args.each { |arg|
                svr_index = get_server_index(arg)
                if svr_index.nil?
                    puts! invalid_server_id_msg + " '#{args[0]}'"; return
                else
                    closed = nil
                    @servers_lock.synchronize { closed = !@ucli_servers[svr_index][3] }
                    if closed then message "Error: server #{arg} is closed - 'with' scripts cannot be sent to a closed server.", 1; return; end
                end
                svr_indices << svr_index
            }
        end
        
        # Confirm its OK if list of servers contains duplicates
        if svr_indices.length != svr_indices.uniq.length
            print! "'with' server list contains duplicate entries; continue (y/n)? "
            return unless getyn("y")
        end
            
        commands = []
        if source_file
            # Read commands to run from given source file
            begin
                commands = File.readlines(source_file)
            rescue Exception => ex
                puts! "Error: can't read 'with' script '#{source_file}'"
                @diag.if_level(3) { p ex }
            end
        else
            # Read commands in local console loop to apply to server list
            cmd_num = 1
            loop do
                begin
                    cmd_s = readline("[#{cmd_num}] ", true)
                    next if cmd_s.nil? || cmd_s.length == 0
                    break if cmd_s == "end"
                    if FORBIDDEN_WITH_COMMANDS.include?(cmd_s) || (cmd_s =~ /^[!#].*/)
                        puts! "Error: '#{cmd_s}' is not allowed within a 'with' script."
                        next
                    end
                    commands << cmd_s
                    cmd_num += 1
                rescue Interrupt
                    message "'with' script terminated by user interrupt.", 3
                end
            end
        end
        
        return if commands.length < 1   # nothing to do

        # Disallow with scripts with background jobs contained in them.        
        commands.each_with_index { |cmd,i|
            if /.*&$/ =~ cmd
                puts "Error: 'with' scripts may not run jobs in the background (see line #{i+1})"
                return
            end
        }

        # Send commands to each server...
        begin            
            svr_indices.each { |svr_idx|
                svr_name = nil
                @servers_lock.synchronize {
                    @drb_server = ucli_servers[svr_idx]
                    @server_id = svr_idx+1
                    svr_name = "#{@drb_server[0]}:#{@drb_server[1]}"
                }
                
                if interactive
                    print! "Send 'with' commands to server '#{svr_name}' (y/n)? "
                    raise UserCancel, "user cancel" unless getyn("y")
                end
                
                # Must not hold client lock while running commands, as certain commands need the lock.
                commands.each { |cmd|
                    puts! "> #{cmd} @ #{@drb_server[0]}:#{@drb_server[1]}" if echo
                    cmd_a = run_command(cmd)
                    raise CommandFailed if cmd_a.nil?
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
            @jobs_lock.synchronize {
                message "Waiting for background jobs to complete...", 2 if @jobs.length > 0
                @jobs.each { |t| t[0].join }   # wait for any jobs spawned by this 'with script' to finish
                @jobs = jobs                  # BEFORE restoring state of @jobs and @drb_server
            }
            @servers_lock.synchronize {
                @drb_server = drb_server
            }
        end
            
    end

    # List all active jobs
    def jobs(*args)
        @jobs_lock.synchronize {
            @jobs.each { |job|
                if job[0]
                    t = "%#{job[2]}: #{job[1]}"
                    t << (job[0].status ? " (in progress)" : " (done)")
                    t << " '#{job[4][0].slice(0,20)}...'" unless
                    puts! t
                end
            }
        }
    end

    def get_job_output(job_num)
        @jobs_lock.synchronize {
            if job_num < 1 || job_num > @jobs.length
                puts! "Error: invalid job number."
                return []
            elsif @jobs[job_num-1][4].nil?
                puts! "Error: job #{job_num} had no output or has already been cleaned up - output not available."
                return []
            else
                return @jobs[job_num-1][4]
            end
        }
    end
    
    def get_job(job_index)
        @jobs_lock.synchronize {
            return @jobs[job_index]
        }
    end

    def save(*args)
        invalid_args_msg = "Error: missing argument(s) - save requires a valid job ID and a legal filename."
        
        if args.length < 2
            puts! invalid_args_msg
            return
        end
        
        begin
            if /^%\d+$/ =~ args[0]
                
                output = get_job_output($&[1..-1].to_i)
                if output.nil? || output.length < 1
                    message "Task #{args[0]} has no output to save.", 2
                    return
                end
            
                return unless confirm_overwrite args[1]
                
                File.open(args[1], "w") { |f|
                    output.each { |l| f.write l }
                }
            elsif /^%%/ =~ args[0]
                
                return unless confirm_overwrite args[1]
    
                File.open(args[1], "w") { |f| 
                    @jobs_lock.synchronize {
                        @jobs.each { |job|
                            f.write(job[1] + "\n")
                            if job[4].nil? || job[4].length == 0
                                f.write("[no output]\n")
                            else
                                job[4].each { |line| f.write line }
                            end
                        }
                    }
                }
            else
                puts! invalid_args_msg
            end
        rescue NoMethodError => ex
            puts! "Error: invalid job ID '#{args[0]}'}"
            @diag.if_level(3) { p ex }
        rescue IOError => ex
            puts! "Error: unable to write to file '#{args[1]}'."
            @diag.if_level(3) { p ex }
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

    def loadrules(*args)
        if args.length < 2
            puts! ERROR_INCOMPLETE_COMMAND
        elsif !File.exist?(args[1])
            puts! "Error: rules file '#{args[1]}' not found."
        else
            File.open(args[1]) { |rules|
                until rules.eof? do
                    run_command("#{args[0]} #{rules.gets.chomp.strip}")
                end
            }
        end
    end

    def backup(*args)
        if (args.length < 1)
            puts! ERROR_INCOMPLETE_COMMAND
            return
        end
        
        if (to_file = (args[0] == "to_file"))
            if args.length < 2
                puts! ERROR_INCOMPLETE_COMMAND
                return
            elsif File.exist?(args[1])
                print! "File '#{args[1]}' exists  - overwrite it (y/n)? "
                return unless getyn('y')
            end
        end

        if to_file
            message("Retrieving #{BRAND} server settings: this many take as much as a few minutes to complete - please wait...", 2)
            settings = send_to_server("backup", args)
            if !settings
                puts! "Error: unable to retrieve #{BRAND} server settings - backup failed.";
            else
                filename = args[1]
                filename << ".backup"
                File.open(filename, File::CREAT | File::TRUNC | File::RDWR) { |f|
                    f.syswrite(settings)
                }
                message("Server settings successfully backed up to '#{filename}'.'", 1)
            end
        else
            res = send_to_server("backup", args)
            puts! res if res
        end
    end
    
end # NUCLIClient

#
#   Main loop: continue to recreate and run CLI until a valid quit is encountered.
#
if __FILE__ == $0
    loop do
        nucli_client = nil
        begin
            nucli_client = NUCLIClient.new(ARGV)    # run only returns if commands were given on the command
            nucli_client.run                        # line that launched this process, otherwise run loops 
            break                                   # until a terminate, interrupt or unhandled exception is raised.
        rescue Terminate, Interrupt
            break
        rescue Exception => ex
            puts! "NUCLI client has encountered an unhandled exception: " + ex + "\nRestarting...\n"
            p ex.backtrace
        ensure
            nucli_client.shutdown if nucli_client
        end
    end

    exit(0)

end # if __FILE__

