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
require 'filternode'

class Attack < UVMFilterNode
    
    UVM_NODE_NAME = "untangle-node-shield"
    NODE_NAME = "Attack Blocker"
    MIB_ROOT = UVM_FILTERNODE_MIB_ROOT + ".3"

    def initialize
        @diag = Diag.new(DEFAULT_DIAG_LEVEL)
	@diag.if_level(3) { puts! "Initializing #{get_node_name()}..." }
        super
	@diag.if_level(3) { puts! "Done initializing #{get_node_name()}..." }
    end

    #
    # Required UVMFilterNode methods.
    #
    def get_uvm_node_name()
        UVM_NODE_NAME
    end

    def get_node_name()
        NODE_NAME
    end

    def get_mib_root()
        MIB_ROOT
    end
    
    def get_help_text()
        return <<-HELP
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
    HELP
    end

    #
    # Command handlers.
    #
    def cmd_list(tid, *args)
        return list_rules(tid)
    end
    
    def cmd_add(tid, *args)
        return add_rule(tid, -1, *args.slice(1,args.length-1))
    end
    
    def cmd_update(tid, *args)
        return add_rule(tid, args[1], *args.slice(2,args.length-2))
    end
    
    def cmd_remove(tid, *args)
        return remove_rule(tid, args[1])
    end
    
    def list_rules(tid)
        begin
            node_ctx = @@uvmRemoteContext.nodeManager.nodeContext(tid)
            node = node_ctx.node()
            settings =  node.getSettings()
            attackBlockerRuleList = settings.getAttackblockerRuleList()
            rules = "#,enabled,action,log,traffic-type,direction,src-addr,dest-addr,src-port,dst-port,category,description\n"
            rule_num = 1
            attackBlockerRuleList.each { |rule|
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
   
    def cmd_settings(tid, *args)
        return ERROR_INCOMPLETE_COMMAND
    end

    def cmd_settings_defaultaction(tid, *args)
        if args[0].nil?
            return list_settings_default_action(tid)
        else
            return settings_default_action(tid, args[1])
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
