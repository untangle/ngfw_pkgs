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
	@diag.if_level(3) { puts! "Done initializing WebFilter..." }
    end

    #
    # Server service methods
    #
    def execute(args)

        @diag.if_level(3) { puts! "Webfilter::execute(#{args.join(' ')})" }
        
        begin
            # Get tids of all web filters once and for all commands we might execute below.
            tids = @uvmRemoteContext.nodeManager.nodeInstances(WEBFILTER_NODE_NAME)
            return ERROR_NO_WEBFILTER_NODES if tids.nil? || tids.length < 1
    
            if /^#/ =~ args[0]
                begin
                    node_num = (args[0].slice(1,-1).to_i) - 1
                rescue Exception => ex
                    err = "Error: invalid webfilter node number '#{args[0].slice(1,-1)}'"
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

- webfilter -- enumerate all web filters running on effective #{BRAND} server.
- webfilter <#X> block-list [item-type:cats|urls|mime|files]
    -- Display block-list of item-type for webfilter #X
- webfilter <#X> block-list block [item-type:cat|url|mime|file] [item] <block:true|false> <log:true|false> <description>
    -- Add item to block-list by type (or update) with specified block and log settings.
- webfilter <#X> pass-list [item-type:urls|clients]
    -- Display pass-list items
- webfilter <#X> pass-list [item-type:url|client] [pass:true|false] <description>
    -- Add item to pass-list with specified settings.
- webfilter <#X> eventlog <tail <#>>|<after-time> <before-time> (***NOT YET IMPLEMENTED***)
    -- Display event log entries, either the # tail entries or those between after-time and before-time.
                WEBFILTER_HELP
                return help_text
            when "block-list"
                return manage_block_list(tid, args)
            when "pass-list"
                return manage_pass_list(tid, args)
            when "eventlog"
                return "Event Log not yet supported."
            else
                return ERROR_UNKNOWN_COMMAND + " -- '#{args.join(' ')}'"
            end
        rescue Exception => ex
            msg = "webfilter has raised an unhandled exception -- " + ex
            @diag.if_level(1) { puts! msg }
            p ex
            return msg
        end
        
    end

    #
    # Block List related methods
    #
    def manage_block_list(tid, args)
        case args[0]
        when nil, ""
            return ERROR_INCOMPLETE_COMMAND
        when "urls"
            return get_blocked_urls(tid)
        when "categories", "cats"
            return get_blocked_categories(tid)
        when "mime", "mimes"
            return get_blocked_mime_types(tid)
        when "file", "files"
            return get_blocked_file_types(tid)
        when "block"
            case args[1]
            when nil, ""
                return ERROR_INCOMPLETE_COMMAND
            when "url"
                return block_url(tid, args[2], args[3], args[4], args[5])
            when "mime"
                return block_mime_type(tid, args[2], args[3], args[4])
            when "file"
                return block_file_type(tid, args[2], args[3], args[4])
            when "category", "cat"
                return block_category(tid, args[2], args[3], args[4])
            else
                return ERROR_UNKNOWN_COMMAND + " -- " + args.join(' ')
            end
        when "unblock"
        else
            return ERROR_UNKNOWN_COMMAND + " -- " + args.join(' ')
        end
    end

    def get_blocked_urls(tid)
        node_ctx = @uvmRemoteContext.nodeManager.nodeContext(tid)
        node = node_ctx.node()
        settings =  node.getSettings()
        blocked_urls_list = settings.getBlockedUrls()
        blocked_urls = "URL,block,log\n"
        blocked_urls_list.each { |url|
            blocked = (url.getString() + "," + url.isLive().to_s + "," + url.getLog().to_s + "," + url.getDescription() + "\n")
            blocked_urls << blocked
            @diag.if_level(3) { puts! blocked }
        } if blocked_urls_list
        return blocked_urls
    end

    def get_blocked_categories(tid)
        node_ctx = @uvmRemoteContext.nodeManager.nodeContext(tid)
        node = node_ctx.node()
        settings =  node.getSettings()
        blocked_cats_list = settings.getBlacklistCategories()
        blocked_cats = "Category, description, block/log\n"
        blocked_cats_list.each { |cat|
            blocked = ""
            blocked << (cat.getDisplayName() + "," + cat.getDescription())
            # ***TODO: get these block combos to match the GUI
            if cat.getBlockDomains() && cat.getBlockUrls() && cat.getBlockExpressions() && !cat.getLogOnly()
                blocked << ",block and log"
            elsif !cat.getBlockDomains() && !cat.getBlockUrls() && !cat.getBlockExpressions() && !cat.getLogOnly()
                blocked << ",pass"
            elsif cat.getBlockDomains() && cat.getBlockUrls() && cat.getBlockExpressions() && cat.getLogOnly()
                blocked << ",pass and log"
            else
                blocked << ",action unknown - correct via #{BRAND} admin. GUI."
            end
            @diag.if_level(3) { blocked << (" (" + cat.getBlockDomains().to_s + "," + cat.getBlockUrls().to_s + "," + cat.getBlockExpressions().to_s + "," + cat.getLogOnly().to_s + ")") }
            blocked << "\n"
            blocked_cats << blocked
            @diag.if_level(3) { puts! blocked }
        } if blocked_cats_list
        return blocked_cats
    end
    
    def get_blocked_mime_types(tid)
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
    end

    def get_blocked_file_types(tid)
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
    end

    def block_url(tid, url=nil, block="true", log="true", desc=nil)
        begin
            return ERROR_INCOMPLETE_COMMAND if url.nil?
            node_ctx = @uvmRemoteContext.nodeManager.nodeContext(tid)
            node = node_ctx.node()
            settings =  node.getSettings()
            blockedUrlsList = settings.getBlockedUrls()   
            url = url.gsub(/^www./, '')
            @diag.if_level(2) { puts! "Attempting to add #{url} to blocked list." }
            newUrlToBlock = com.untangle.uvm.node.StringRule.new(url)
            newUrlToBlock.setLive(block == "false" ? false : true)
            newUrlToBlock.setLog(log == "true")
            newUrlToBlock.setDescription(desc) if desc
            rule_to_update = -1
            blockedUrlsList.each_with_index { |blocked_url, i|
                rule_to_update = i if blocked_url.getString() == newUrlToBlock.getString()
            }
            if rule_to_update == -1
                blockedUrlsList.add(newUrlToBlock)
            else
                blockedUrlsList[rule_to_update] = newUrlToBlock
            end
            settings.setBlockedUrls(blockedUrlsList)
            node.setSettings(settings)
            msg = "URL '#{url}' added to Block list."
            @diag.if_level(3) { puts! msg }
            return msg
        rescue Exception => ex
            @diag.if_level(3) { p ex }
            return "Adding URL to block list failed:\n" + ex
        end
    end
    
    def block_mime_type(tid, mime_type, block=nil, name=nil)
        begin
            return ERROR_INCOMPLETE_COMMAND if mime_type.nil? || mime_type == ""
            node_ctx = @uvmRemoteContext.nodeManager.nodeContext(tid)
            node = node_ctx.node()
            settings =  node.getSettings()
            blockedMimesList = settings.getBlockedMimeTypes()
            return "There are no blocked mime types defined." if blockedMimesList.nil? || blockedMimesList.length == 0
            @diag.if_level(3) { puts! "Attempting to add #{mime_type} to Block list." }
            mimeType = com.untangle.uvm.node.MimeType.new(mime_type)
            block = (block.nil? || (block != "true")) ? false : true
            name ||= "[no name]" 
            mimeTypeRule = com.untangle.uvm.node.MimeTypeRule.new(mimeType, name, "[no category]", "[no description]", block)
            blockedMimesList.add(mimeTypeRule)
            settings.setBlockedMimeTypes(blockedMimesList)
            node.setSettings(settings)
            msg = "Mime type '#{mime_type}' added to Block list."
            @diag.if_level(2) { puts! msg }
            return msg
        rescue Exception => ex
            @diag.if_level(3) { p ex }
            return "Adding URL to block list failed:\n" + ex
        end
    end

    def block_file_type(tid, file_type, block="true", category=nil)
        begin
            return ERROR_INCOMPLETE_COMMAND if file_type.nil? || file_type==""
            node_ctx = @uvmRemoteContext.nodeManager.nodeContext(tid)
            node = node_ctx.node()
            settings =  node.getSettings()
            blockedExtensionsList = settings.getBlockedExtensions()   
            @diag.if_level(2) { puts! "Attempting to add #{file_type} to Block list." }
            block = (block.nil? || (block != "true")) ? false : true
            category = "" unless category
            stringRule = com.untangle.uvm.node.StringRule.new(file_type, "[no name]", category, "[no description]", block)
            blockedExtensionsList.add(stringRule)
            settings.setBlockedExtensions(blockedExtensionsList)
            node.setSettings(settings)
            msg = "File extension '#{file_type}' added to Block list."
            @diag.if_level(3) { puts! msg }
            return msg
        rescue Exception => ex
            @diag.if_level(3) { p ex }
            return "Adding extension '#{file_type}' to block list failed:\n" + ex
        end
    end

    def block_category(tid, cat_to_block, block="true", log="true")
        return ERROR_INCOMPLETE_COMMAND if cat_to_block.nil? || cat_to_block==""
        node_ctx = @uvmRemoteContext.nodeManager.nodeContext(tid)
        node = node_ctx.node()
        settings = node.getSettings()
        blocked_cats_list = settings.getBlacklistCategories()
        cat_to_block = cat_to_block.downcase
        cat_idx = 0
        blocked_cat = blocked_cats_list.find { |cat|
            found = cat.getDisplayName().downcase == cat_to_block
            cat_idx += 1 unless found
            found
        }
        if blocked_cat
            block = (block == "true")
            pass = !block
            log = (log == "true")
            new_cat = blocked_cats_list[cat_idx]
            if block
                new_cat.setBlockDomains(true)
                new_cat.setBlockUrls(true)
                new_cat.setBlockExpressions(true)
                new_cat.setLogOnly(false)
            elsif pass && log
                new_cat.setBlockDomains(false)
                new_cat.setBlockUrls(false)
                new_cat.setBlockExpressions(false)
                new_cat.setLogOnly(true)
            elsif pass
                new_cat.setBlockDomains(false)
                new_cat.setBlockUrls(false)
                new_cat.setBlockExpressions(false)
                new_cat.setLogOnly(false)
            end
            blocked_cats_list[cat_idx] = new_cat
            settings.setBlacklistCategories(blocked_cats_list)
            node.setSettings(settings)
            msg = "Category '#{cat_to_block}' action updated."
            @diag.if_level(2) { puts! msg }
            return msg
        end
    end
    
    #
    #   Pass list related methods
    #
    def manage_pass_list(tid, args)
        case args[0]
        when nil, ""
            return ERROR_INCOMPLETE_COMMAND
        when "urls"
            return get_passed_urls(tid)
        when "clients"
            return get_passed_clients(tid)
        when "pass"
            case args[1]
            when nil, ""
                return ERROR_INCOMPLETE_COMMAND
            when "url"
                return pass_url(tid, args[2], args[3], args[4])
            when "client"
                return pass_client(tid, args[2], args[3], args[4])
            else
                return ERROR_UNKNOWN_COMMAND + " -- " + args.join(' ')
            end
        else
            return ERROR_UNKNOWN_COMMAND + " -- " + args.join(' ')
        end
    end

    def get_passed_urls(tid)
        node_ctx = @uvmRemoteContext.nodeManager.nodeContext(tid)
        node = node_ctx.node()
        settings =  node.getSettings()
        passed_urls_list = settings.getPassedUrls()
        passed_urls = "URL,pass,description\n"
        passed_urls_list.each { |url|
            passed = ""
            passed << (url.getString() + "," + url.isLive().to_s + "," + url.getDescription() + "\n")
            passed_urls << passed
            @diag.if_level(3) { puts! passed }
        } if passed_urls_list
        return passed_urls
    end

    def get_passed_clients(tid)
        node_ctx = @uvmRemoteContext.nodeManager.nodeContext(tid)
        node = node_ctx.node()
        settings =  node.getSettings()
        passed_clients_list = settings.getPassedClients()
        passed_clients = "URL,pass,description\n"
        passed_clients_list.each { |client|
            passed = ""
            passed << (client.getIpMaddr().getAddr() + "," + client.isLive().to_s + "," + client.getDescription() + "\n")
            passed_clients << passed
            @diag.if_level(3) { puts! passed }
        } if passed_clients_list
        return passed_clients
    end
    
    def pass_url(tid, url, block="true", desc=nil)
        begin
            return ERROR_INCOMPLETE_COMMAND if url.nil? || url==""
            node_ctx = @uvmRemoteContext.nodeManager.nodeContext(tid)
            node = node_ctx.node()
            settings =  node.getSettings()
            passedUrlsList = settings.getPassedUrls()   
            url = url.gsub(/^www./, '')
            @diag.if_level(2) { puts! "Attempting to add #{url} to passed list." }
            newUrlToPass = com.untangle.uvm.node.StringRule.new(url)
            newUrlToPass.setLive(block == "true")
            newUrlToPass.setDescription(desc) if desc
            rule_to_update = -1
            passedUrlsList.each_with_index { |passed_url, i|
                rule_to_update = i if passed_url.getString() == newUrlToPass.getString()
            }
            if rule_to_update == -1
                passedUrlsList.add(newUrlToPass)
            else
                passedUrlsList[rule_to_update] = newUrlToPass
            end
            settings.setPassedUrls(passedUrlsList)
            node.setSettings(settings)
            msg = "URL '#{url}' added to Pass List."
            @diag.if_level(3) { puts! msg }
            return msg
        rescue Exception => ex
            @diag.if_level(3) { p ex }
            return "Adding URL to block list failed:\n" + ex
        end
    end

    def pass_client(tid, client, block="true", desc=nil)
        begin
            return ERROR_INCOMPLETE_COMMAND if client.nil? || client==""
            node_ctx = @uvmRemoteContext.nodeManager.nodeContext(tid)
            node = node_ctx.node()
            settings =  node.getSettings()
            passedClientsList = settings.getPassedClients()   
            @diag.if_level(2) { puts! "Attempting to add #{client} to passed list." }
            newClientIpMaddr = com.untangle.uvm.node.IPMaddr.new(client)
            newClientToPass = com.untangle.uvm.node.IPMaddrRule.new()
            newClientToPass.setIpMaddr(newClientIpMaddr)
            newClientToPass.setLive(block == "true") 
            newClientToPass.setDescription(desc) if desc
            rule_to_update = -1
            passedClientsList.each_with_index { |passed_client, i|
                rule_to_update = i if passed_client.getIpMaddr().getAddr() == newClientToPass.getIpMaddr().getAddr()
            }
            if rule_to_update == -1
                passedClientsList.add(newClientToPass)
            else
                passedClientsList[rule_to_update] = newClientToPass
            end
            settings.setPassedClients(passedClientsList)
            node.setSettings(settings)
            msg = "Client '#{client}' added to Pass List."
            @diag.if_level(3) { puts! msg }
            return msg
        rescue Exception => ex
            @diag.if_level(3) { p ex }
            return "Adding URL to block list failed:\n" + ex
        end
    end
    
end # WebFilter
