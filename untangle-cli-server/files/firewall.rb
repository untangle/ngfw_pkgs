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
require 'java'
require 'proxy'
require 'debug'

require 'filternode'

class Firewall < UVMFilterNode
    
    ERROR_NO_FIREWALL_NODES = "No firewall modules are installed on the effective server."
    NODE_NAME = "untangle-node-firewall"
    FIREWALL_MIB_ROOT = UVM_FILTERNODE_MIB_ROOT + ".2"
    
    def initialize
        @diag = Diag.new(DEFAULT_DIAG_LEVEL)
	@diag.if_level(3) { puts! "Initializing Fire Wall..." }
        super
	@diag.if_level(3) { puts! "Done initializing Fire Wall..." }
    end

    #
    # Required UVMFilterNode methods.
    #
    def get_uvm_node_name()
        NODE_NAME
    end

    def get_node_name()
        "Firewall"
    end

    def get_mib_root()
        FIREWALL_MIB_ROOT
    end
    
    #
    # Server service methods
    #
    def execute(args)

        @diag.if_level(3) { puts! "Firewall::execute(#{args.join(' ')})" }
        
        retried = false
        
        begin
            # Get tids of all web filters once and for all commands we might execute below.
            tids = get_filternode_tids(get_uvm_node_name())
            if empty?(tids) then return (args[0] == "snmp") ? nil : ERROR_NO_FIREWALL_NODES ; end
    
            begin
                tid, cmd = *extract_tid_and_command(tids, args, ["snmp"])
            rescue InvalidNodeNumber, InvalidNodeId => ex
                msg = ERROR_INVALID_NODE_ID + ": " + ex
                @diag.if_level(3) { puts! msg ; p ex}
                return msg
            rescue Exception => ex
                msg = "Error: firewall encountered an unhandled exception: " + p
                @diag.if_level(3) { puts! msg ; p ex}
                return msg
            end
            
            @diag.if_level(3) { puts! "TID = #{tid}, command = #{cmd}" }
            
            case cmd
            when nil, "", "list"
                return list_filternodes(tids)
            when "help"
                help_text = <<-FIREWALL_HELP

- firewall -- enumerate all filewall nodes running on effective #{BRAND} server.
- firewall <#X|TID> rules
    -- Display rule list for firewall #X|TID
- firewall <#X|TID> rules add enable action log traffic_type direction src-addr dst-addr src-port dst-port category description
    -- Add item to rule-list by type (or update) with specified block and log settings.
- firewall <#X|TID> rules remove [rule-number]
    -- Remove item '[rule-number]' from rule list.
- firewall <#X|TID> settings default-action <new-default-action>
    -- Display or update default-actions settings for firewall #X|TID
- firewall <#X> stats
    -- Display firewall #X statistics in human readable format
- firewall snmp
    -- Display firewall #X statistics in snmp compliant format (getnext)    
                FIREWALL_HELP
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
        rescue Exception => ex
            if !retried
                @diag.if_level(2) { puts! "Login expired - logging back on and trying one more time" ; p ex }
                @@filter_node_lock.synchronize { login }
                retry
            else
                raise Exception
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
            fireWallRuleList = settings.getFirewallRuleList()
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
            firewallRuleList = settings.getFirewallRuleList()

            rule_num = rule_num.to_i
            if (rule_num < 1 || rule_num > firewallRuleList.length) && (rule_num != -1)
                return "Error: invalid rule number - valid values are 1...#{firewallRuleList.length}"
            end
            
	    rule = com.untangle.node.firewall.FirewallRule.new
	    rule.setLive(enable == "true")
	    rule.setAction(action)
	    rule.setLog(log == "true")
	    begin rule.setProtocol(com.untangle.uvm.node.firewall.protocol.ProtocolMatcherFactory.parse(traffic_type.upcase))
            rescue Exception => ex
                msg = "Error: invalid protocol value."
                @diag.if_level(2) { puts! msg ; p ex }
                return msg
	    end
	    rule.setDirection(direction)
	    begin rule.setSrcAddress(com.untangle.uvm.node.firewall.ip.IPMatcherFactory.parse(src_addr))
            rescue Exception => ex
                msg = "Error: invalid source address value."
                @diag.if_level(2) { puts! msg ; p ex }
                return msg
	    end
	    begin rule.setDstAddress(com.untangle.uvm.node.firewall.ip.IPMatcherFactory.parse(dst_addr))
            rescue Exception => ex
                msg = "Error: invalid destination address value."
                @diag.if_level(2) { puts! msg ; p ex }
                return msg
	    end
	    begin rule.setSrcPort(com.untangle.uvm.node.firewall.port.PortMatcherFactory.parse(src_addr))
            rescue Exception => ex
                msg = "Error: invalid source port value."
                @diag.if_level(2) { puts! msg ; p ex }
                return msg
	    end
	    begin rule.setDstPort(com.untangle.uvm.node.firewall.port.PortMatcherFactory.parse(dst_port))
            rescue Exception => ex
                msg = "Error: invalid destination port value."
                @diag.if_level(2) { puts! msg ; p ex }
                return msg
	    end	    
	    rule.setCategory(category) if category
	    rule.setDescription(desc) if desc
	    
	    if rule_num == -1
                firewallRuleList.add(rule)
	    else
                firewallRuleList[rule_num-1] = rule
	    end
	    
	    settings.setFirewallRuleList(firewallRuleList)
	    node.setSettings(settings)
	    
	    msg = (rule_num != -1) ? "Rule ##{rule_num} updated in firewall rule list." : "Rule added to firewall rule list."
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
            firewallRuleList = settings.getFirewallRuleList()

            rule_num = rule_num.to_i
            if (rule_num < 1 || rule_num > firewallRuleList.length)
                return "Error: invalid rule number - valid values are 1...#{firewallRuleList.length}"
            end

            firewallRuleList.remove(firewallRuleList[rule_num-1])
	    settings.setFirewallRuleList(firewallRuleList)
	    node.setSettings(settings)
	    
	    msg = "Rule #{rule_num} removed from firewall rule list."
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

end # Firewall

