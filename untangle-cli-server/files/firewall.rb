#
# firewall.rb - Fire Wall interfaces with the UVM and its Fire Wall Filter Nodes.
#
# Copyright (c) 2007 Untangle Inc., all rights reserved.
#
# @author <a href="mailto:ken@untangle.com">Ken Hilton</a>
# @version 0.1
#

require 'java'
require 'proxy'
require 'debug'

require 'ucli_common'
include UCLICommon
require 'ucli_util'
include UCLIUtil

require 'filternode'

class Firewall < UVMFilterNode
    
    ERROR_NO_FIREWALL_NODES = "No firewall modules are installed on the effective server."
    FIREWALL_NODE_NAME = "untangle-node-firewall"

    def initialize
        @diag = Diag.new(DEFAULT_DIAG_LEVEL)
	@diag.if_level(3) { puts! "Initializing Fire Wall..." }

        super
        connect

	@diag.if_level(3) { puts! "Done initializing Fire Wall..." }
    end

    #
    # Server service methods
    #
    def execute(args)

        @diag.if_level(3) { puts! "Firewall::execute(#{args.join(' ')})" }
        
        begin
            # Get tids of all web filters once and for all commands we might execute below.
            tids = @uvmRemoteContext.nodeManager.nodeInstances(FIREWALL_NODE_NAME)
            return ERROR_NO_FIREWALL_NODES if tids.nil? || tids.length < 1
    
            if /^#/ =~ args[0]
                begin
                    node_num = (args[0].slice(1,-1).to_i) - 1
                rescue Exception => ex
                    err = "Error: invalid firewall node number '#{args[0].slice(1,-1)}'"
                    @diag.if_level(2) { puts! err + " " + ex ; p ex }
                    return err
                end
                    
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
    
            @diag.if_level(3) { puts! "firewall: node # = #{node_num}, command = #{cmd}" }
            
            case cmd
            when nil, "", "list"
                # List/enumerate web filter nodes
                @diag.if_level(2) { puts! "firewall: listing nodes..." }
                firewall_list = ""
                firewall_num = 1
                tids.each { |tid|
                    node_ctx = @uvmRemoteContext.nodeManager.nodeContext(tid)
                    desc = node_ctx.getNodeDesc()
                    firewall_list << "##{firewall_num} #{desc}\n"
                    firewall_num += 1
                }
                @diag.if_level(2) { puts! "firewall: #{firewall_list}" }
                return firewall_list
            when "help"
                help_text = <<-FIREWALL_HELP

- firewall -- enumerate all web filters running on effective #{BRAND} server.
- firewall <#X> rule-list
    -- Display rule list for firewall #X
- firewall <#X> rule-list add ...
    -- Add item to rule-list by type (or update) with specified block and log settings.
- firewall <#X> settings ...
    -- Display settings for firewall #X
- firewall <#X> settings action [pass|block]
    -- Change settings for firewall #X
                FIREWALL_HELP
                return help_text
            when "rule-list"
                return manage_rule_list(tid, args)
            when "settings"
                return manage_settings(tid, args)
            when "eventlog"
                return "Event Log not yet supported."
            else
                return ERROR_UNKNOWN_COMMAND + " -- '#{args.join(' ')}'"
            end
        rescue Exception => ex
            msg = "Firewall has raised an unhandled exception -- " + ex
            @diag.if_level(1) { puts! msg }
            p ex
            return msg
        end
        
    end

    #
    # Rule List related methods
    #
    def manage_rule_list(tid, args)
        case args[0]
        when nil, ""
            return ERROR_INCOMPLETE_COMMAND
        when "add"
            return "not yet implemented"
        when "update"
            return "not yet implemented"
        else
            return ERROR_UNKNOWN_COMMAND + " -- " + args.join(' ')
        end
    end

    #
    #   Pass list related methods
    #
    def manage_settings(tid, args)
        case args[0]
        when nil, ""
            return ERROR_INCOMPLETE_COMMAND
        when "action"
	    case args[1]
	    when "default"
		if args[2].nil?
		    return list_settings_default_action(tid, args)
		else
		    return "not yet implemented"
		end
	    else
		return ERROR_INCOMPLETE_COMMAND
	    end
	        
        else
            return ERROR_UNKNOWN_COMMAND + " -- " + args.join(' ')
        end
    end

    def list_settings_default_action(tid, args)
	node_ctx = @uvmRemoteContext.nodeManager.nodeContext(tid)
	node = node_ctx.node()
	settings =  node.getSettings()
	default_action = "Default action: #{settings.isDefaultAccpt() ? "pass" : "block"}"
    end
    
end # Firewall

