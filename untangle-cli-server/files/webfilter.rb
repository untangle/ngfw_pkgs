#!/usr/local/bin/ruby
#
# webfilter.rb - WebFilter interfaces with the UVM and its Web Filter Nodes.
#
# Copyright (c) 2007 Untangle Inc., all rights reserved.
#
# @author <a href="mailto:ken@untangle.com">Ken Hilton</a>
# @version 0.1
#
# Open Issues
#   - Should mime types entered via the CLI be validated against a list of known legal values?
#

require 'java'
require 'proxy'
require 'debug'

require 'ucli_common'
include UCLICommon
require 'ucli_util'
include UCLIUtil

require 'filternode'

class Webfilter < UVMFilterNode
    
    ERROR_NO_WEBFILTER_NODES = "No web filter modules are installed on the effective server."
    WEBFILTER_NODE_NAME = "untangle-node-webfilter"

    def initialize
        @diag = Diag.new(DEFAULT_DIAG_LEVEL)
	@diag.if_level(3) { puts! "Initializing WebFilter..." }

        super
        connect

	@diag.if_level(3) { puts! "Done initializing WebFilter..." }
    end

    #
    # Server service methods
    #
    def execute(args)

        @diag.if_level(3) { puts! "Webfilter::execute(#{args.join(' ')})" }
        
        begin
            # Get tids of all web filters.
            tids = @uvmRemoteContext.nodeManager.nodeInstances(WEBFILTER_NODE_NAME)
            return ERROR_NO_WEBFILTER_NODES if tids.nil? || tids.length < 1
    
            if /^#/ =~ args[0]
                # ***TODO: need to handle case where node # fails on to_i
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
            when "help"
                help_text = <<-WEBFILTER_HELP

- webfilter list -- enumerate all web filters running on effective #{@brand} server.            
- webfilter <#X> block-list [item-type:urls|mime|file] -- display block-list URLs for web filter #X
- webfilter <#X> pass-list [item-type:urls|clients] -- display pass-list URLs
- webfilter <#X> block-list block [item-type:url|mime|file] [item] <log:true|false> -- add item to block-list by type (or update) with specified block and log settings.
- webfilter <#X> pass-list URL [pass:true|false] -- add URL to pass-list with specified pass setting.
- webfilter <#X> eventlog <tail <#>>|<after-time> <before-time> -- display event log entries, either the # tail entries or those between after-time and before-time.
                WEBFILTER_HELP
                return help_text
            when "block-list"
                return manage_block_list(tid, args)
            when "pass-list"
                return manage_pass_list(tid, args)
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
            blocked_urls = "URL,block,log\n"
            blocked_urls_list.each { |url|
                blocked = ""
                blocked << (url.getString() + "," + url.isLive().to_s + "," + url.getLog().to_s + "\n")
                blocked_urls << blocked
                @diag.if_level(3) { puts! blocked }
            } if blocked_urls_list
            return blocked_urls
        when "categories", "cats"
            # List blocked categories
            node_ctx = @uvmRemoteContext.nodeManager.nodeContext(tid)
            node = node_ctx.node()
            settings =  node.getSettings()
            blocked_cats_list = settings.getBlacklistCategories()
            blocked_cats = "Category, description, block domains, block URLs, block expressions, log only\n"
            blocked_cats_list.each { |cat|
                blocked = ""
                blocked << (cat.getDisplayName() + "," + cat.getDescription() + ",")
                blocked << (cat.getBlockDomains().to_s + "," + cat.getBlockUrls().to_s + "," + cat.getBlockExpressions().to_s + "," + cat.getLogOnly().to_s + "\n")
                blocked_cats << blocked
                @diag.if_level(3) { puts! blocked }
            } if blocked_cats_list
            return blocked_cats
        when "mime"
            # List blocked mime types
            node_ctx = @uvmRemoteContext.nodeManager.nodeContext(tid)
            node = node_ctx.node()
            settings =  node.getSettings()
            blocked_mime_types_list = settings.getBlockedMimeTypes()
            @diag.if_level(3) { puts "# blocked mime types = #{blocked_mime_types_list.length}" if blocked_mime_types_list }
            blocked_mime_types = "MIME type,block,name,category,description,log\n"
            blocked_mime_types_list.each { |mime_type_rule|
                mime_type = mime_type_rule.getMimeType                
                blocked = mime_type.getType
                blocked << ("," + mime_type_rule.isLive.to_s)
                blocked << ("," + mime_type_rule.getName)
                blocked << ("," + mime_type_rule.getCategory)
                blocked << ("," + mime_type_rule.getDescription)
                blocked << ("," + (mime_type_rule.getLog ? "logged" : "not logged"))
                blocked << "\n"
                blocked_mime_types << blocked
                @diag.if_level(3) { puts! blocked }
            } if blocked_mime_types_list
            return blocked_mime_types
        when "file", "files"
            # List blocked file types
            node_ctx = @uvmRemoteContext.nodeManager.nodeContext(tid)
            node = node_ctx.node()
            settings =  node.getSettings()
            blocked_files_list = settings.getBlockedExtensions()
            blocked_files = "File ext., block, description"
            blocked_files_list.each { |extension|
                blocked_file = ""
                blocked_file << extension.getString() + ","
                blocked_file << extension.isLive().to_s + ","
                blocked_file << extension.getDescription + "\n"
                blocked_files << blocked_file
            } if blocked_files_list
            @diag.if_level(3) { puts! blocked_files }
            return blocked_files
        when "block"
            case args[1]
            when nil, ""
                return ERROR_INCOMPLETE_COMMAND
            when "url"
                # Block given URL ***TODO: verify format of url?
                begin
                    return ERROR_INCOMPLETE_COMMAND if args.length < 3
                    node_ctx = @uvmRemoteContext.nodeManager.nodeContext(tid)
                    node = node_ctx.node()
                    settings =  node.getSettings()
                    blockedUrlsList = settings.getBlockedUrls()   
                    url = args[2].gsub(/^www./, '')
                    @diag.if_level(2) { puts! "Attempting to add #{url} to blocked list." }
                    stringRule = com.untangle.uvm.node.StringRule.new(url)
                    stringRule.setLog(true) if args[3].nil? || (args[3] == "true")
                    stringRule.setLive(true)
                    blockedUrlsList.add(stringRule)
                    settings.setBlockedUrls(blockedUrlsList)
                    node.setSettings(settings)
                    msg = "URL '#{args[2]}' added to Block list."
                    @diag.if_level(3) { puts! msg }
                    return msg
                rescue Exception => ex
                    @diag.if_level(3) { p ex }
                    return "Adding URL to block list failed:\n" + ex
                end
            when "mime"
                # Block given Mime Type ***TODO: how to verify we have a valid mime type?
                begin
                    return ERROR_INCOMPLETE_COMMAND if args.length < 3
                    node_ctx = @uvmRemoteContext.nodeManager.nodeContext(tid)
                    node = node_ctx.node()
                    settings =  node.getSettings()
                    blockedMimesList = settings.getBlockedMimeTypes()
                    return "There are no blocked mime types defined." if blockedMimesList.nil? || blockedMimesList.length == 0
                    @diag.if_level(3) { puts! "Attempting to add #{args[2]} to Block list." }
                    mimeType = com.untangle.uvm.node.MimeType.new(args[2])
                    block = (args[3].nil? || (args[3] != "true")) ? false : true
                    name = args[4] ? args[4] : "[no name]"
                    mimeTypeRule = com.untangle.uvm.node.MimeTypeRule.new(mimeType, name, "[no category]", "[no description]", block)
                    blockedMimesList.add(mimeTypeRule)
                    settings.setBlockedMimeTypes(blockedMimesList)
                    node.setSettings(settings)
                    msg = "Mime type '#{args[2]}' added to Block list."
                    @diag.if_level(2) { puts! msg }
                    return msg
                rescue Exception => ex
                    @diag.if_level(3) { p ex }
                    return "Adding URL to block list failed:\n" + ex
                end
            when "file"
                # Block given file extension
                begin
                    return ERROR_INCOMPLETE_COMMAND if args.length < 3
                    node_ctx = @uvmRemoteContext.nodeManager.nodeContext(tid)
                    node = node_ctx.node()
                    settings =  node.getSettings()
                    blockedExtensionsList = settings.getBlockedExtensions()   
                    @diag.if_level(2) { puts! "Attempting to add #{args[2]} to Block list." }
                    file = args[2]
                    block = (args[3].nil? || (args[3] != "true")) ? false : true
                    cat = args[4] ? args[4] : ""
                    stringRule = com.untangle.uvm.node.StringRule.new(file, "[no name]", cat, "[no description]", block)
                    blockedExtensionsList.add(stringRule)
                    settings.setBlockedMimeTypes(blockedMimesList)
                    node.setSettings(settings)
                    msg = "File extension '#{args[2]}' added to Block list."
                    @diag.if_level(3) { puts! msg }
                    return msg
                rescue Exception => ex
                    @diag.if_level(3) { p ex }
                    return "Adding extension '#{args[2]}' to block list failed:\n" + ex
                end
            when "category"
                return "Not yet supported."
            else
                return ERROR_UNKNOWN_COMMAND + " -- " + args.join(' ')
            end
        when "unblock"
        else
            return ERROR_UNKNOWN_COMMAND + " -- " + args.join(' ')
        end
    end

    def manage_pass_list(tid, args)
        case args[0]
        when nil, ""
            return ERROR_INCOMPLETE_COMMAND
        when "urls"
            # List blocked URLs
            node_ctx = @uvmRemoteContext.nodeManager.nodeContext(tid)
            node = node_ctx.node()
            settings =  node.getSettings()
            blocked_urls_list = settings.getBlockedUrls()
            blocked_urls = "URL,block,log\n"
            blocked_urls_list.each { |url|
                blocked = ""
                blocked << (url.getString() + "," + url.isLive().to_s + "," + url.getLog().to_s + "\n")
                blocked_urls << blocked
                @diag.if_level(3) { puts! blocked }
            } if blocked_urls_list
            return blocked_urls
        when "clients"
            # List blocked categories
            node_ctx = @uvmRemoteContext.nodeManager.nodeContext(tid)
            node = node_ctx.node()
            settings =  node.getSettings()
            blocked_cats_list = settings.getBlacklistCategories()
            blocked_cats = "Category, description, block domains, block URLs, block expressions, log only\n"
            blocked_cats_list.each { |cat|
                blocked = ""
                blocked << (cat.getDisplayName() + cat.getDescription())
                blocked << (cat.isLive() + "," + cat.getBlockDomains().to_s + "," + cat.getBlockUrls().to_s + "," + cat.getBlockExpressions().to_s + "," + cat.getLogOnly().to_s + "\n")
                blocked_cats << blocked
                @diag.if_level(3) { puts! blocked }
            } if blocked_cats_list
            return blocked_cats
        when "pass"
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
                        stringRule.setLive(true)
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
            when "client"
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


#def getPolicies()`
    #@diag.if_level(2) { puts! "getPolicies" }
    #puts! "getPolicies"
  #policies = @uvmRemoteContext.policyManager.getPolicies
  #policies.each { |p|
      #p policies
  #} if policies
#end
