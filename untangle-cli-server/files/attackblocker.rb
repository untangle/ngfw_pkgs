#
# attackblocker.rb - Attack Blocker interfaces with the UVM and its Attack Blocker Filter Nodes.
#
# Copyright (c) 2007 Untangle Inc., all rights reserved.
#
# @author <a href="mailto:ken@untangle.com">Ken Hilton</a>
# @version 0.1
#

require 'java'
require 'proxy'
require 'debug'

require 'filternode'

class Attackblocker < UVMFilterNode
    
    ERROR_NO_ATTACKBLOCKER_NODES = "No attackblocker modules are installed on the effective server."
    NODE_NAME = "untangle-node-shield"
    ATTACKBLOCKER_MIB_ROOT = UVM_FILTERNODE_MIB_ROOT + ".4"

    def initialize
        @diag = Diag.new(DEFAULT_DIAG_LEVEL)
	@diag.if_level(3) { puts! "Initializing Attack Blocker..." }
        super
	@diag.if_level(3) { puts! "Done initializing Attack Blocker..." }
    end

    #
    # Required UVMFilterNode methods.
    #
    def get_node_name()
        NODE_NAME
    end

    def get_mib_root()
        ATTACKBLOCKER_MIB_ROOT
    end
    
    #
    # Server service methods
    #
    def execute(args)

        @diag.if_level(3) { puts! "Attackblocker::execute(#{args.join(' ')})" }
        
        retried = false
        
        begin
            # Get tids of all web filters once and for all commands we might execute below.
            tids = get_filternode_tids(get_node_name())
            @diag.if_level(3) { puts! "No attack blockers found." if empty?(tids) }
            if empty?(tids) then return (args[0] == "snmp") ? nil : ERROR_NO_ATTACKBLOCKER_NODES ; end
    
            begin
                tid, cmd = *extract_tid_and_command(tids, args, ["snmp"])
                raise FilterNodeException unless cmd
            rescue Exception => ex
                msg = "Error: attachblocker encountered an unhandled exception: " + p
                @diag.if_level(3) { puts! msg ; p ex}
                return msg
            end
            
            @diag.if_level(3) { puts! "TID = #{tid}, command = #{cmd}" }
            
            case cmd
            when nil, "", "list"
                # List/enumerate web filter nodes
                @diag.if_level(2) { puts! "attackblocker: listing nodes..." }
                attackblocker_list = "#,TID,Description\n"
                attackblocker_num = 1
                tids.each { |tid|
                    node_ctx = @@uvmRemoteContext.nodeManager.nodeContext(tid)
                    desc = node_ctx.getNodeDesc()
                    attackblocker_list << "##{attackblocker_num},#{tid},#{desc}\n"
                    attackblocker_num += 1
                }
                @diag.if_level(2) { puts! "attackblocker: #{attackblocker_list}" }
                return attackblocker_list
            when "help"
                help_text = <<-ATTACKBLOCKER_HELP

- attackblocker -- enumerate all web filters running on effective #{BRAND} server.
- attackblocker <#X> rules
    -- Display rule list for attackblocker #X
- attackblocker <#X> rules add enable action log traffic_type direction src-addr dst-addr src-port dst-port category description
    -- Add item to rule-list by type (or update) with specified block and log settings.
- attackblocker <#X> rules remove [rule-number]
    -- Remove item '[rule-number]' from rule list.
- attackblocker <#X> settings ...
    -- Display settings for attackblocker #X
- attackblocker <#X> settings action [pass|block]
    -- Change settings for attackblocker #X
                ATTACKBLOCKER_HELP
                return help_text
            when "rules", "rule"
                return manage_rule_list(tid, args)
            when "settings"
                return manage_settings(tid, args)
            when "eventlog"
                return "Event Log not yet supported."
            when "stats", "snmp"
                return get_statistics(tid, args)
            else
                return ERROR_UNKNOWN_COMMAND + " -- '#{args.join(' ')}'"
            end
        rescue LoginExpiredException => ex
            if !retried
                @diag.if_level(2) { puts! "Login expired - logging back on and trying one more time" ; p ex }
                @@filter_node_lock.synchronize { login }
                retry
            else
                raise Exception
            end            
        rescue Exception => ex
            msg = "Attackblocker has raised an unhandled exception -- " + ex
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
            return get_rule_list(tid)
        when "add"
            return add_rule(tid, -1, *args.slice(1,args.length-1))
        when "update"
            return add_rule(tid, args[1], *args.slice(2,args.length-2))
        when "remove"
            return remove_rule(tid, args[1])
        else
            return ERROR_UNKNOWN_COMMAND + " -- " + args.join(' ')
        end
    end

    def get_rule_list(tid)
        begin
            node_ctx = @@uvmRemoteContext.nodeManager.nodeContext(tid)
            node = node_ctx.node()
            settings =  node.getSettings()
            fireWallRuleList = settings.getAttackblockerRuleList()
            rules = "#,enabled,action,log,traffic-type,direction,src-addr,dest-addr,src-port,dst-port,category,description\n"
            rule_num = 1
            fireWallRuleList.each { |rule|
                rules << "#{rule_num},#{rule.isLive().to_s},#{rule.getAction()},#{rule.getLog()}"
                rules << ",#{rule.getProtocol().toDatabaseString()}"
                rules << ",#{rule.getDirection()}"
                rules << ",#{rule.getSrcAddress().toDatabaseString()}"
                rules << ",#{rule.getDstAddress().toDatabaseString()}"
                rules << ",#{rule.getSrcPort().toDatabaseString()}"
                rules << ",#{rule.getDstPort().toDatabaseString()}"
                rules << ",'#{rule.getCategory()}'"
                rules << ",'#{rule.getDescription()}'"
                rules << "\n"
                rule_num += 1                
            }
            return rules
        rescue Exception => ex
            msg = "Error: #{self.class}.get_rule_list caught an unhandled exception -- " + ex
            @diag.if_level(2) { puts! msg ; p ex }
            return msg
        end
    end

    def add_rule(tid, rule_num, enable="true", action="block", log="false", traffic_type=nil, direction=nil, src_addr=nil, dst_addr=nil, src_port=nil, dst_port=nil, category=nil, desc=nil)
	
	# Validate arguments...  ***TODO: validate format of addresses and ports?
	if !(traffic_type && direction && src_addr && dst_addr && src_port && dst_port)
	    return ERROR_INCOMPLETE_COMMAND
	elsif !["true", "false"].include?(enable)
	    return "Error: invalid value for 'enable' - valid values are 'true' and 'false'."
	elsif !["block", "pass"].include?(action)
	    return "Error: invalid value for 'action' - valid values are 'block' and 'pass'."
	elsif !["true", "false"].include?(log)
	    return "Error: invalid value for 'log' - valid values are 'true' and 'false'."
	end
	
	# Add new rule...
        begin
            node_ctx = @@uvmRemoteContext.nodeManager.nodeContext(tid)
            node = node_ctx.node()
            settings =  node.getSettings()
            attackblockerRuleList = settings.getAttackblockerRuleList()

            rule_num = rule_num.to_i
            if (rule_num < 1 || rule_num > attackblockerRuleList.length) && (rule_num != -1)
                return "Error: invalid rule number - valid values are 1...#{attackblockerRuleList.length}"
            end
            
	    rule = com.untangle.node.attackblocker.AttackblockerRule.new
	    rule.setLive(enable == "true")
	    rule.setAction(action)
	    rule.setLog(log == "true")
	    begin rule.setProtocol(com.untangle.uvm.node.attackblocker.protocol.ProtocolMatcherFactory.parse(traffic_type))
            rescue ParseError => ex
                msg = "Error: invalid protocol value."
                @diag.if_level(2) { puts! msg ; p ex }
                return msg
	    end
	    rule.setDirection(direction)
	    begin rule.setSrcAddress(com.untangle.uvm.node.attackblocker.ip.IPMatcherFactory.parse(src_addr))
            rescue ParseError => ex
                msg = "Error: invalid source address value."
                @diag.if_level(2) { puts! msg ; p ex }
                return msg
	    end
	    begin rule.setDstAddress(com.untangle.uvm.node.attackblocker.ip.IPMatcherFactory.parse(dst_addr))
            rescue ParseError => ex
                msg = "Error: invalid destination address value."
                @diag.if_level(2) { puts! msg ; p ex }
                return msg
	    end
	    begin rule.setSrcPort(com.untangle.uvm.node.attackblocker.port.PortMatcherFactory.parse(src_addr))
            rescue ParseError => ex
                msg = "Error: invalid source port value."
                @diag.if_level(2) { puts! msg ; p ex }
                return msg
	    end
	    begin rule.setDstPort(com.untangle.uvm.node.attackblocker.port.PortMatcherFactory.parse(dst_port))
            rescue ParseError => ex
                msg = "Error: invalid destination port value."
                @diag.if_level(2) { puts! msg ; p ex }
                return msg
	    end	    
	    rule.setCategory(category) if category
	    rule.setDescription(desc) if desc
	    
	    if rule_num == -1
                attackblockerRuleList.add(rule)
	    else
                attackblockerRuleList[rule_num-1] = rule
	    end
	    
	    settings.setAttackblockerRuleList(attackblockerRuleList)
	    node.setSettings(settings)
	    
	    msg = (rule_num == -1) ? "Rule #{rule_num} updated in attackblocker rule list." : "Rule added to attackblocker rule list."
	    @diag.if_level(2) { puts! msg }
            return msg
        rescue Exception => ex
            msg = "Error: #{self.class}.add_rule caught an unhandled exception -- " + ex
            @diag.if_level(2) { puts! msg ; p ex }
            return msg
        end
    end

    def remove_rule(tid, rule_num)
	
	# Remove rule...
        begin
            node_ctx = @@uvmRemoteContext.nodeManager.nodeContext(tid)
            node = node_ctx.node()
            settings =  node.getSettings()
            attackblockerRuleList = settings.getAttackblockerRuleList()

            rule_num = rule_num.to_i
            if (rule_num < 1 || rule_num > attackblockerRuleList.length)
                return "Error: invalid rule number - valid values are 1...#{attackblockerRuleList.length}"
            end

            attackblockerRuleList.remove(attackblockerRuleList[rule_num-1])
	    settings.setAttackblockerRuleList(attackblockerRuleList)
	    node.setSettings(settings)
	    
	    msg = "Rule #{rule_num} removed from attackblocker rule list."
	    @diag.if_level(2) { puts! msg }
            return msg
        rescue Exception => ex
            msg = "Error: #{self.class}.remove_rule caught an unhandled exception -- " + ex
            @diag.if_level(2) { puts! msg ; p ex }
            return msg
        end
    end
   
    def manage_settings(tid, args)
        case args[0]
        when nil, ""
            return ERROR_INCOMPLETE_COMMAND
        when "default-action"
            if args[1].nil?
                return list_settings_default_action(tid)
            else
                return settings_default_action(tid, args[1])
            end
        else
            return ERROR_UNKNOWN_COMMAND + " -- " + args.join(' ')
        end
    end

    def list_settings_default_action(tid)
        begin
            node_ctx = @@uvmRemoteContext.nodeManager.nodeContext(tid)
            node = node_ctx.node()
            settings =  node.getSettings()
            default_action = "Default action: #{settings.isDefaultAccept() ? "pass" : "block"}"
        rescue Exception => ex
            msg = "Error: #{self.class}.list_settings_default_action caught an unhandled exception -- " + ex
            @diag.if_level(2) { puts! msg ; p ex }
            return msg
        end
    end
    
    def settings_default_action(tid, action="block")
        begin
            raise ArgumentError unless (action == "block") || (action == "pass")
            node_ctx = @@uvmRemoteContext.nodeManager.nodeContext(tid)
            node = node_ctx.node()
            settings =  node.getSettings()
            settings.setDefaultAccept(action == "pass")
            node.setSettings(settings)
            res = "#{self.class} Settings Default Action set to '#{action}'"
            @diag.if_level(2) { puts! res }
            return res
        rescue ArgumentError
            return "Error: invalid value for Default Action -- valid actions are 'pass' and 'block'."
        rescue Exception => ex
            msg = "Error: #{self.class}.settings_default_actioncaught an unhandled exception -- " + ex
            @diag.if_level(2) { puts! msg ; p ex }
            return msg
        end
    end

end # Attackblocker

