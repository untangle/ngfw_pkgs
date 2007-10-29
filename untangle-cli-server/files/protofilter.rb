#
# protofilter.rb - Protocol Control interfaces with the UVM and its Protocol Filter Nodes.
#
# Copyright (c) 2007 Untangle Inc., all rights reserved.
#
# @author <a href="mailto:cmatei@untangle.com">Catalin Matei</a>
# @version 0.1
#
require 'java'
require 'proxy'
require 'debug'

require 'filternode'

# TODO: the following modules should de used by all the nodes, but i'm not sure where to put them
# ***Ken says: we can locate these in common, until we think of a better way to package this.

module CmdDispatcher
  protected

  # Calls a method for processing the specified command.
  #
  # The name of the method should be the command name prefixed with _prefix_.
  # The command name is defined to be the first element of the _args_ array.
  # The remaining elements will be used as paramaters to the method call
  #
  # ***Ken says: I like this approach however it may not scale well to more complex filters,
  # for example the webfilter, which manages set of related items and has a command line like this:
  # webfilter block-list add url www.foobarbaz.com true false.  And since we don't know how many
  # values of args[] comprise the actual command, in the case 3: block-list, add, url, I'm not
  # sure this solution is general enough. But, then again, it does get rid of one level of
  # parsing, or the next level of command processing could simply append the next arg
  # and call dispatch again with a prefix of ""?  Thoughts?
  #

  def dispatch_cmd(prefix, args)
    if respond_to?(prefix + args[0]) then
      begin
        new_args = args[1..-1]
        return send(prefix + args[0], *new_args)
      rescue ArgumentError => ex
        @diag.if_level(3) {
          puts! "Dispatching failure: " + prefix+args[0] + "(" + new_args.inspect  + ")"
          puts! ex
          puts! ex.backtrace
        }
        return ERROR_INCOMPLETE_COMMAND
      end
    else
      return ERROR_UNKNOWN_COMMAND + " -- '#{args.join(' ')}'"
    end
  end
end

module RetryLogin

  # ***Ken says... Aaron Read (another of our engineers) thinks this belongs at a lower level of the UVM API.  I'll
  # review this with him and get back to you :)
  # 
  # Runs the asociated block. If the block throws an LoginExpiredException, it logs in
  # and runs the block again.
  def retryLogin
    retried = false
    begin
      yield
    rescue com.untangle.uvm.client.LoginExpiredException => ex
      if !retried
        retried = true
        @diag.if_level(2) { puts! "Login expired - logging back on and trying one more time" ; p ex }
        @@filter_node_lock.synchronize { login }
        retry
      else
        raise
      end
    end
  end
end

# TODO: we can't use camel case for the class name (ProtoFilter won't work)
# ***Ken says: if we want to rip some code off of Rails, perhaps we can use their camel case converter.
class Protofilter < UVMFilterNode
  include CmdDispatcher
  include RetryLogin

  ERROR_NO_PROTOFILTER_NODES = "No Protocol Filter modules are installed on the effective server."
  NODE_NAME = "untangle-node-protofilter"
  PROTOFILTER_MIB_ROOT = UVM_FILTERNODE_MIB_ROOT + ".4"

  def initialize
    @diag = Diag.new(DEFAULT_DIAG_LEVEL)
    @diag.if_level(3) { puts! "Initializing Protocol Filter..." }
    super
    @diag.if_level(3) { puts! "Done initializing Protocol Filter..." }
  end
  
  def get_node_name()
    NODE_NAME
  end
  
  def get_mib_root()
    PROTOFILTER_MIB_ROOT
  end  
  
  def execute(args)
    # TODO: BUG: if we don't return something the client reports an exception
    @diag.if_level(3) { puts! "Protofilter::execute(#{args.join(', ')})" }

    begin
      retryLogin {
        # Get tids of all protocol filters once and for all commands we might execute below.
        tids = get_filternode_tids(get_node_name())
        if empty?(tids) then return (args[0] == "snmp") ? nil : ERROR_NO_PROTOFILTER_NODES ; end

        begin
          tid, cmd = *extract_tid_and_command(tids, args, ["snmp"])
        rescue Exception => ex
          return "Error: invalid #{NODE_NAME} node number or ID '#{ex}'"
        end
        @diag.if_level(3) { puts! "TID = #{tid}, command = #{cmd}" }

        # TODO: integrate in dispatcer?
        if cmd.nil? then
          # List/enumerate protofilter nodes
          @diag.if_level(2) { puts! "protofilter: listing nodes..." }

          ret = "#,TID,Description\n";
          tids.each_with_index { |tid, i|
            ret << "##{i+1},#{tid}," + @@uvmRemoteContext.nodeManager.nodeContext(tid).getNodeDesc().to_s + "\n"
          }
          @diag.if_level(2) { puts! "protofilter: #{ret}" }
          return ret
        else
          return dispatch_cmd("cmd_", args.empty? ? [cmd, tid] : [cmd, tid, *args])
        end
      }
    rescue Exception => ex
      @diag.if_level(3) { puts! ex; puts! ex.backtrace }
      return "Uncaught exception #{ex}"
    end    
  end

  # Add a protocol to the list
  def add_protocol(tid, category, protocol, block, log, description, signature)
    update_protocol_helper(tid, -1, category, protocol, block, log, description, signature)
  end

  # Update the protocol at position pos
  def update_protocol(tid, pos, category, protocol, block, log, description, signature)
    update_protocol_helper(tid, pos, category, protocol, block, log, description, signature)
  end

  # Remove a protocol from the list
  def remove_protocol(tid, pos)
    patterns = get_patterns(tid)
    begin
      validate_range(pos, 1..patterns.length, "protocol number")
      patterns.remove(patterns[pos - 1])
      update_patterns(tid, patterns)
      msg = "Protocol #{pos} was removed from the list."
      @diag.if_level(2) { puts! msg }
      return msg
    rescue => ex
      return ex.to_s
    end
  end

  protected
  def cmd_help(tid, *args)
    return <<HELP
- protofilter -- enumerate all protocol filter nodes running on effective #{BRAND} server.
- protofilter <#X|TID> list
    -- Display protocol list list for protofilter node #X|TID
- protofilter <#X|TID> add category protocol block log description signature
    -- Add a protocol to the protocol list with specified settings.
- protofilter <#X|TID> update [proto-number] category protocol block log description signature
    -- Update item '[proto-number]' with specified settings.
- protofilter <#X|TID> remove [proto-number]
    -- Remove item '[proto-number]' from protocol list.
- protofilter <#X|TID> <snmp|stats>
    -- Display protocol filter #X|TID statistics (TODO document this)
HELP
  end

  def cmd_list(tid)
    ret = "#,category,protocol,block,log,description,signature\n"
    get_patterns(tid).each_with_index { |pattern, index|
      ret << [(index+1).to_s,
              pattern.getCategory,
              pattern.getProtocol,
              pattern.isBlocked.to_s,
              pattern.getLog.to_s,
              pattern.getDescription,
              pattern.getDefinition,
             ].join(",")
      ret << "\n"
    }
    return ret
  end

  def cmd_add(tid, *args)
    add_protocol(tid, *args)
  end

  def cmd_update(tid, pos, *args)
    update_protocol(tid, pos.to_i, *args)
  end

  def cmd_remove(tid, pos)
    remove_protocol(tid, pos.to_i)
  end

  def cmd_snmp(tid, *args)
    get_statistics(tid, args)
  end

  def cmd_stats(tid, *args)
    get_statistics(tid, args)
  end

  #-- Helper methods
  def get_patterns(tid)
    @@uvmRemoteContext.nodeManager.nodeContext(tid).node.getSettings.getPatterns
  end

  def update_patterns(tid, patterns)
    node = @@uvmRemoteContext.nodeManager.nodeContext(tid).node
    settings = node.getSettings
    settings.setPatterns(patterns)
    node.setSettings(settings)
  end

  def validate_bool(var, varname)
    unless ["true", "false"].include?(var)
      raise "Error: invalid value for '#{varname}' - valid values are 'true' and 'false'."
    end
  end

  def validate_range(var, range, varname)
    unless range === var
      raise "Error: invalid value for '#{varname}' - valid values are #{range.min}..#{range.max}"
    end
  end

  def update_protocol_helper(tid, pos, category, protocol, block, log, description, signature)
    patterns = get_patterns(tid)
    begin
      validate_range(pos, 1..patterns.length, "protocol number") unless pos == -1
      validate_bool(block, "block")
      validate_bool(log, "log")
      pattern = com.untangle.node.protofilter.ProtoFilterPattern.new
      pattern.setCategory(category)
      pattern.setProtocol(protocol)
      pattern.setBlocked(block == "true")
      pattern.setLog(log == "true")
      pattern.setDescription(description)
      pattern.setDefinition(signature)
    rescue => ex
      return ex.to_s
    end

    if pos == -1
      patterns.add(pattern)
      msg = "Protocol added to the list."
    else
      patterns[pos - 1] = pattern
      msg = "Protocol #{pos} updated."
    end

    update_patterns(tid, patterns)

    @diag.if_level(2) { puts! msg }
    return msg
  end
end
