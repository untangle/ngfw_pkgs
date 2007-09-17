#!/usr/local/bin/ruby
#
# webfilter.rb - WebFilter interfaces with the UVM and its Web Filter Nodes.
#
# Copyright (c) 2007 Untangle Inc., all rights reserved.
#
# @author <a href="mailto:ken@untangle.com">Ken Hilton</a>
# @version 0.1
#

require 'ucli_common'
include UCLICommon
require 'ucli_util'
include UCLIUtil

require 'filternode'

class WebFilter < UVMFilterNode
    
    ERROR_NO_WEBFILTER_NODES = "No web filter modules are installed on the effective server."
    WEBFILTER_NODE_NAME = "untangle-node-webfilter"

    def initialize
        @diag = Diag.new
	@diag.if_level(2) { puts! "Initializing WebFilter..." }

        super
        connect

	@diag.if_level(2) { puts! "Done initializing WebFilter..." }
    end

    #
    # Server service methods
    #
    #def getPolicies()`
        #@diag.if_level(2) { puts! "getPolicies" }
        #puts! "getPolicies"
      #policies = @uvmRemoteContext.policyManager.getPolicies
      #policies.each { |p|
          #p policies
      #} if policies
    #end

    def execute(args)
        
        begin
            # Get tids of all web filters.
            tids = @uvmRemoteContext.nodeManager.nodeInstances(WEBFILTER_NODE_NAME)
            return ERROR_NO_WEBFILTER_NODES if tids.nil? || tids.length < 1
    
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
            msg = "webfilter has raised an unhandled exception -- " + ex
            @diag.if_level(1) { puts! msg }
            p ex
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

end # WebFilter
