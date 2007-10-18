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

require 'filternode'

require 'common'
include NUCLICommon

class Webfilter < UVMFilterNode
    
    ERROR_NO_WEBFILTER_NODES = "No web filter modules are installed on the effective server."
    NODE_NAME = "untangle-node-webfilter"
    WEBFILTER_MIB_ROOT = UVM_FILTERNODE_MIB_ROOT + ".1"
    NUM_STAT_COUNTERS = 16

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
        retried = false
        
        begin
            # Get tids of all web filters once and for all commands we might execute below.
            tids = get_webfilter_tids()
            return ERROR_NO_WEBFILTER_NODES if tids.nil? || tids.length < 1
    
            begin
                tid_and_cmd = extract_tid_and_command(tids, args)
                raise FilterNodeException unless tid_and_cmd
                tid = tid_and_cmd[0]
                cmd = tid_and_cmd[1]
            rescue Exception => ex
                msg = "Error: invalid #{NODE_NAME} node number or ID '#{ex}'"
                @diag.if_level(3) { puts! msg ; p ex}
                return msg
            end
            
            @diag.if_level(3) { puts! "TID = #{tid}, command = #{cmd}" }
            
            case cmd
            when nil, "", "list"
                # List/enumerate web filter nodes
                @diag.if_level(2) { puts! "webfilter: listing nodes..." }
                webfilter_list = "#,TID,Description\n"
                webfilter_num = 1
                tids.each { |tid|
                    node_ctx = @@uvmRemoteContext.nodeManager.nodeContext(tid)
                    desc = node_ctx.getNodeDesc()
                    webfilter_list << "##{webfilter_num},#{tid},#{desc}\n"
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
- webfilter <#X> stats <snmp>
    -- Display webfilter #X statistics in human readable format (use snmp option for snmp formatted statistics)
- webfilter <#X> eventlog <tail <#>>|<after-time> <before-time> (***NOT YET IMPLEMENTED***)
    -- Display event log entries, either the # tail entries or those between after-time and before-time.
                WEBFILTER_HELP
                return help_text
            when "block-list"
                return manage_block_list(tid, args)
            when "pass-list"
                return manage_pass_list(tid, args)
            when "statistics", "stats"
                return get_statistics(tid, args)
            when "eventlog"
                return "Event Log not yet supported."
            else
                return ERROR_UNKNOWN_COMMAND + " -- '#{args.join(' ')}'"
            end
        rescue com.untangle.uvm.client.LoginExpiredException => ex
            if !retried
                @diag.if_level(2) { puts! "Login expired - logging back on and trying one more time" ; p ex }
                @@filter_node_lock.synchronize { login }
                retry
            else
                raise Exception
            end
        rescue Exception => ex
            msg = "webfilter has raised an unhandled exception -- " + ex
            @diag.if_level(1) { puts! msg }
            p ex
            return msg
        end
        
    end

    def get_webfilter_tids
        return @@uvmRemoteContext.nodeManager.nodeInstances(NODE_NAME)
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
            return block_list_get_categories(tid)
        when "mime", "mimes"
            return block_list_get_mime_types(tid)
        when "file", "files"
            return block_list_get_file_types(tid)
        when "add"
            case args[1]
            when nil, ""
                return ERROR_INCOMPLETE_COMMAND
            when "url"
                return block_list_add_url(tid, args[2], args[3], args[4], args[5])
            when "mime"
                return block_list_add_mime_type(tid, args[2], args[3], args[4])
            when "file"
                return block_list_add_file_type(tid, args[2], args[3], args[4])
            else
                return ERROR_UNKNOWN_COMMAND + " -- " + args.join(' ')
            end
        when "update"
            case args[1]
            when nil, ""
                return ERROR_INCOMPLETE_COMMAND
            when "category", "cat"
                return block_list_update_category(tid, args[2], args[3], args[4])
            else
                return ERROR_UNKNOWN_COMMAND + " -- " + args.join(' ')
            end
        when "remove"
            case args[1]
            when nil, ""
                return ERROR_INCOMPLETE_COMMAND
            when "url"
                return block_list_remove_url(tid, args[2])
            when "mime"
                return block_list_remove_mime_type(tid, args[2])
            when "file"
                return block_list_remove_file_type(tid, args[2])
            when "category", "cat"
                return "Error: block list categories cannot be removed."
            else
                return ERROR_UNKNOWN_COMMAND + " -- " + args.join(' ')
            end
        else
            return ERROR_UNKNOWN_COMMAND + " -- " + args.join(' ')
        end
    end

    def get_blocked_urls(tid)
        node_ctx = @@uvmRemoteContext.nodeManager.nodeContext(tid)
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

    def block_list_get_categories(tid)
        node_ctx = @@uvmRemoteContext.nodeManager.nodeContext(tid)
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
    
    def block_list_get_mime_types(tid)
        node_ctx = @@uvmRemoteContext.nodeManager.nodeContext(tid)
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

    def block_list_get_file_types(tid)
        node_ctx = @@uvmRemoteContext.nodeManager.nodeContext(tid)
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

    def block_list_add_url(tid, url, block, log, desc)
        begin
            return ERROR_INCOMPLETE_COMMAND if url.nil?
            node_ctx = @@uvmRemoteContext.nodeManager.nodeContext(tid)
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
    
    def block_list_remove_url(tid, url)
        begin
            return ERROR_INCOMPLETE_COMMAND if url.nil?
            node_ctx = @@uvmRemoteContext.nodeManager.nodeContext(tid)
            node = node_ctx.node()
            settings =  node.getSettings()
            blockedUrlsList = settings.getBlockedUrls()   
            url = url.gsub(/^www./, '')
            @diag.if_level(2) { puts! "Attempting to remove #{url} from blocked list." }

            rule_to_remove = blockedUrlsList.detect { |blocked_url|
                blocked_url.getString() == url
            }
            if rule_to_remove
                blockedUrlsList.remove(rule_to_remove)
                settings.setBlockedUrls(blockedUrlsList)
                node.setSettings(settings)
                msg = "URL '#{url}' removed from block list."
            else
                msg = "Error: can't remove - URL not found."
            end

            @diag.if_level(3) { puts! msg }
            return msg
        rescue Exception => ex
            @diag.if_level(3) { p ex }
            return "Adding URL to block list failed:\n" + ex
        end
    end
    
    def block_list_add_mime_type(tid, mime_type, block=nil, name=nil)
        begin
            return ERROR_INCOMPLETE_COMMAND if mime_type.nil? || mime_type == ""
            node_ctx = @@uvmRemoteContext.nodeManager.nodeContext(tid)
            node = node_ctx.node()
            settings =  node.getSettings()
            blockedMimesList = settings.getBlockedMimeTypes()
            @diag.if_level(3) { puts! "Attempting to add #{mime_type} to Block list." }
            mimeType = com.untangle.uvm.node.MimeType.new(mime_type)
            block = (block.nil? || (block != "true")) ? false : true
            name ||= "[no name]" 
            mimeTypeRule = com.untangle.uvm.node.MimeTypeRule.new(mimeType, name, "[no category]", "[no description]", block)
            rule_to_update = -1
            blockedMimesList.each_with_index { |blocked_mime,i|
                rule_to_update = i if blocked_mime.getMimeType().getType() == mime_type
            }
            if rule_to_update == -1
                blockedMimesList.add(mimeTypeRule)
            else
                blockedMimesList[rule_to_update] = mimeTypeRule
            end
            settings.setBlockedMimeTypes(blockedMimesList)
            node.setSettings(settings)
            msg = "Mime type '#{mime_type}' added to Block list."
            @diag.if_level(2) { puts! msg }
            return msg
        rescue Exception => ex
            @diag.if_level(3) { p ex }
            return "Adding mime type to block list failed:\n" + ex
        end
    end

    def block_list_remove_mime_type(tid, mime_type)
        begin
            return ERROR_INCOMPLETE_COMMAND if mime_type.nil? || mime_type == ""
            node_ctx = @@uvmRemoteContext.nodeManager.nodeContext(tid)
            node = node_ctx.node()
            settings =  node.getSettings()
            blockedMimesList = settings.getBlockedMimeTypes()
            return "Error: there are no blocked mime types defined." if blockedMimesList.nil? || blockedMimesList.length == 0
            
            @diag.if_level(3) { puts! "Attempting to remove #{mime_type} from block list." }
            rule_to_remove = blockedMimesList.detect{ |blocked_mime|
                blocked_mime.getMimeType().getType() == mime_type
            }
            if rule_to_remove
                blockedMimesList.remove(rule_to_remove)
                settings.setBlockedMimeTypes(blockedMimesList)
                node.setSettings(settings)
                msg = "MIME type '#{mime_type}' removed from block list."
            else
                msg = "Error: can't remove - MIME type not found."
            end
            
            @diag.if_level(2) { puts! msg }
            return msg
        rescue Exception => ex
            msg = "Remove of MIME type from block list failed:\n" + ex
            @diag.if_level(3) { puts! msg ; p ex }
            return msg
        end
    end

    def block_list_add_file_type(tid, file_ext, block="true", category=nil)
        begin
            return ERROR_INCOMPLETE_COMMAND if file_ext.nil? || file_ext==""
            node_ctx = @@uvmRemoteContext.nodeManager.nodeContext(tid)
            node = node_ctx.node()
            settings =  node.getSettings()
            blockedExtensionsList = settings.getBlockedExtensions()   
            @diag.if_level(2) { puts! "Attempting to add #{file_ext} to Block list." }
            block = (block.nil? || (block != "true")) ? false : true
            category = "" unless category
            stringRule = com.untangle.uvm.node.StringRule.new(file_ext, "[no name]", category, "[no description]", block)
            rule_to_update = -1
            blockedExtensionsList.each_with_index { |blocked_ext,i|
                blocked_ext.getString() == stringRule.getString()
            }
            if rule_to_update == -1
                blockedExtensionsList.add(stringRule)
            else
                blockedExtensionsList[rule_to_update] = stringRule
            end
            settings.setBlockedExtensions(blockedExtensionsList)
            node.setSettings(settings)
            msg = "File extension '#{file_ext}' added to Block list."
            @diag.if_level(3) { puts! msg }
            return msg
        rescue Exception => ex
            @diag.if_level(3) { p ex }
            return "Adding extension '#{file_ext}' to block list failed:\n" + ex
        end
    end

    def block_list_remove_file_type(tid, file_ext)
        begin
            return ERROR_INCOMPLETE_COMMAND if file_ext.nil? || file_ext==""
            node_ctx = @@uvmRemoteContext.nodeManager.nodeContext(tid)
            node = node_ctx.node()
            settings = node.getSettings()
            blockedExtensionsList = settings.getBlockedExtensions()   
            @diag.if_level(2) { puts! "Attempting to remove #{file_ext} from block list." }

            rule_to_remove = blockedExtensionsList.detect{ |blocked_file|
                blocked_file.getString() == file_ext
            }
            if rule_to_remove
                blockedExtensionsList.remove(rule_to_remove)
                settings.setBlockedExtensions(blockedExtensionsList)
                node.setSettings(settings)
                msg = "File type '#{file_ext}' removed from block list."
            else
                msg = "Error: can't remove - File type not found."
            end
            
            @diag.if_level(2) { puts! msg }
            return msg

        rescue Exception => ex
            @diag.if_level(3) { p ex }
            return "Remove file type '#{file_ext}' from block list failed:\n" + ex
        end
    end

    def block_list_update_category(tid, cat_to_block, block="true", log="true")
        return ERROR_INCOMPLETE_COMMAND if cat_to_block.nil? || cat_to_block==""
        node_ctx = @@uvmRemoteContext.nodeManager.nodeContext(tid)
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
            return pass_list_get_urls(tid)
        when "clients"
            return pass_list_get_clients(tid)
        when "add"
            case args[1]
            when nil, ""
                return ERROR_INCOMPLETE_COMMAND
            when "url"
                return pass_list_add_url(tid, args[2], args[3], args[4])
            when "client"
                return pass_list_add_client(tid, args[2], args[3], args[4])
            else
                return ERROR_UNKNOWN_COMMAND + " -- " + args.join(' ')
            end
        when "remove"
            case args[1]
            when nil, ""
                return ERROR_INCOMPLETE_COMMAND
            when "url"
                return pass_list_remove_url(tid, args[2])
            when "client"
                return pass_list_remove_client(tid, args[2])
            else
                return ERROR_UNKNOWN_COMMAND + " -- " + args.join(' ')
            end
        else
            return ERROR_UNKNOWN_COMMAND + " -- " + args.join(' ')
        end
    end

    def pass_list_get_urls(tid)
        node_ctx = @@uvmRemoteContext.nodeManager.nodeContext(tid)
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

    def pass_list_get_clients(tid)
        node_ctx = @@uvmRemoteContext.nodeManager.nodeContext(tid)
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
    
    def pass_list_add_url(tid, url, block="true", desc=nil)
        begin
            return ERROR_INCOMPLETE_COMMAND if url.nil? || url==""
            node_ctx = @@uvmRemoteContext.nodeManager.nodeContext(tid)
            node = node_ctx.node()
            settings =  node.getSettings()
            passedUrlsList = settings.getPassedUrls()   
            url = url.gsub(/^www./, '')
            @diag.if_level(2) { puts! "Attempting to add #{url} to passed list." }
            newUrlToPass = com.untangle.uvm.node.StringRule.new(url)
            newUrlToPass.setLive(block == "true")
            newUrlToPass.setDescription(desc) if desc
            rule_to_update = -1
            passedUrlsList.each_with_index { |passed_url,i|
                rule_to_update = i if passed_url.getString() == newUrlToPass.getString()
            }
            if rule_to_update == -1
                passedUrlsList.add(newUrlToPass)
            else
                passedUrlsList[rule_to_update] = newUrlToPass
            end
            settings.setPassedUrls(passedUrlsList)
            node.setSettings(settings)
            msg = (rule_to_update == -1) ? "URL '#{url}' added to Pass List." : "Pass list URL '#{url}' updated.'"
            @diag.if_level(3) { puts! msg }
            return msg
        rescue Exception => ex
            msg = "Adding URL to block list failed: " + ex
            @diag.if_level(3) { puts! msg ; p ex }
            return msg
        end
    end

    def pass_list_remove_url(tid, url)
        begin
            return ERROR_INCOMPLETE_COMMAND if url.nil? || url==""
            node_ctx = @@uvmRemoteContext.nodeManager.nodeContext(tid)
            node = node_ctx.node()
            settings =  node.getSettings()
            passedUrlsList = settings.getPassedUrls()   
            url = url.gsub(/^www./, '')
            @diag.if_level(2) { puts! "Attempting to add #{url} to passed list." }

            rule_to_remove = passedUrlsList.detect { |passed_url|
                passed_url.getString() == url
            }
            if rule_to_remove
                passedUrlsList.remove(rule_to_remove)
                settings.setPassedUrls(passedUrlsList)
                node.setSettings(settings)
                msg = "URL '#{url}' removed from pass List."
            else
                msg = "Error: can't remove - URL not found."
            end
            @diag.if_level(3) { puts! msg }
            return msg
        rescue Exception => ex
            @diag.if_level(3) { p ex }
            return "Adding URL to block list failed:\n" + ex
        end
    end

    def pass_list_add_client(tid, client, block="true", desc=nil)
        begin
            return ERROR_INCOMPLETE_COMMAND if client.nil? || client==""
            node_ctx = @@uvmRemoteContext.nodeManager.nodeContext(tid)
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
            passedClientsList.each_with_index { |passed_client,i|
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
            return "Adding client to pass list failed:\n" + ex
        end
    end

    def pass_list_remove_client(tid, client, block="true", desc=nil)
        begin
            return ERROR_INCOMPLETE_COMMAND if client.nil? || client==""
            node_ctx = @@uvmRemoteContext.nodeManager.nodeContext(tid)
            node = node_ctx.node()
            settings =  node.getSettings()
            passedClientsList = settings.getPassedClients()   
            @diag.if_level(2) { puts! "Attempting to remove #{client} from pass list." }
            
            rule_to_remove = passedClientsList.detect { |passed_client|
                passed_client.getIpMaddr().getAddr() == client
            }
            if rule_to_remove
                passedClientsList.remove(rule_to_remove)
                settings.setPassedClients(passedClientsList)
                node.setSettings(settings)
                msg = "Client '#{client}' removed from pass List."
            else
                msg = "Error: can't remove - client address not found."
            end
            @diag.if_level(3) { puts! msg }
            return msg
        rescue Exception => ex
            @diag.if_level(3) { p ex }
            return "Adding URL to block list failed:\n" + ex
        end
    end

    def get_statistics(tid, args)
        @diag.if_level(3) { puts! "Attempting to get stats for TID #{tid}" }
        
        # Validate arguments.
        if args[0]
            if (args[0] =~ /^-[ng]$/) == nil
                @diag.if_level(1) { puts "Error: invalid get statistics argument '#{args[0]}"}
                return nil
            elsif !args[1] || !(args[1] =~ /(\.\d+)+/)
                @diag.if_level(1) { puts "Error: invalid get statistics OID: #{args[0] ? args[0] : 'missing value'}" }
                return nil
            elsif (args[1] =~ /^#{WEBFILTER_MIB_ROOT}/) == nil 
                @diag.if_level(1) { puts "Error: invalid get statistics OID: #{args[0]} is not a webfilter OID." }
            end
        end
        
        begin
            node_ctx = @@uvmRemoteContext.nodeManager.nodeContext(tid)
            nodeStats = node_ctx.getStats()
            # TODO: add [nodeStats,timeNow] to hash keyed on tid so we can cache
            @diag.if_level(3) { puts! "Got node stats for #{tid}" ; p nodeStats }
            stats = ""
            if args[0]
                oid = (args[0] == '-g') ? args[1] : oid_next(args[1], tid)
                return nil unless oid
                webfilter_mib_pieces = WEBFILTER_MIB_ROOT.split('.')
                oid_pieces = oid.split('.')
                stat_id = oid_pieces[webfilter_mib_pieces.length-oid_pieces.length+1,2].join('.')
                puts! stat_id
                case stat_id
                    when "1";  stat, type = nodeStats.tcpSessionCount(), "integer"
                    when "2";  stat, type = nodeStats.tcpSessionTotal(), "integer"
                    when "3";  stat, type = nodeStats.tcpSessionRequestTotal(), "integer"
                    when "4";  stat, type = nodeStats.udpSessionCount(), "integer"
                    when "5";  stat, type = nodeStats.udpSessionTotal(), "integer"
                    when "6";  stat, type = nodeStats.udpSessionRequestTotal(), "integer"
                    when "7";  stat, type = nodeStats.c2tBytes(), "integer"
                    when "8";  stat, type = nodeStats.c2tChunks(), "integer"
                    when "9";  stat, type = nodeStats.t2sBytes(), "integer"
                    when "10"; stat, type = nodeStats.t2sChunks(), "integer"
                    when "11"; stat, type = nodeStats.s2tBytes(), "integer"
                    when "12"; stat, type = nodeStats.s2tChunks(), "integer"
                    when "13"; stat, type = nodeStats.t2cBytes(), "integer"
                    when "14"; stat, type = nodeStats.t2cChunks(), "integer"
                    when "15"; stat, type = nodeStats.startDate(), "string"
                    when "16"; stat, type = nodeStats.lastConfigureDate(), "string"
                    when "17"; stat, type = nodeStats.lastActivityDate(), "string"
                    when /18\.\d+/
                        counter = oid_pieces[-1].to_i()-1
                        return nil unless counter < NUM_STAT_COUNTERS
                        stat, type = nodeStats.getCount(counter), "counter32"
                else
                    return nil
                end
                stats = "#{oid}\n#{type}\n#{stat}"
            else
                tcpsc  = nodeStats.tcpSessionCount()
                tcpst  = nodeStats.tcpSessionTotal()
                tcpsrt = nodeStats.tcpSessionRequestTotal()
                udpsc  = nodeStats.udpSessionCount()
                udpst  = nodeStats.udpSessionTotal()
                udpsrt = nodeStats.udpSessionRequestTotal()
                c2tb   = nodeStats.c2tBytes()
                c2tc   = nodeStats.c2tChunks()
                t2sb   = nodeStats.t2sBytes()
                t2sc   = nodeStats.t2sChunks()
                s2tb   = nodeStats.s2tBytes()
                s2tc   = nodeStats.s2tChunks()
                t2cb   = nodeStats.t2cBytes()
                t2cc   = nodeStats.t2cChunks()
                sdate  = nodeStats.startDate()
                lcdate = nodeStats.lastConfigureDate()
                ladate = nodeStats.lastActivityDate()
                counters = []
                (0...NUM_STAT_COUNTERS).each { |i| counters[i] = nodeStats.getCount(i) }
                # formant stats for human readability
                stats << "TCP Sessions (count, total, requests): #{tcpsc}, #{tcpst}, #{tcpsrt}\n"
                stats << "UDP Sessions (count, total, requests): #{udpsc}, #{udpst}, #{udpsrt}\n"
                stats << "Client to Node (bytes, chunks): #{c2tb}, #{c2tc}\n"
                stats << "Node to Client (bytes, chunks): #{t2cb}, #{t2cc}\n"
                stats << "Server to Node (bytes, chunks): #{s2tb}, #{s2tc}\n"
                stats << "Node to Server (bytes, chunks): #{t2sb}, #{t2sc}\n"
                stats << "Counters: #{counters.join(',')}\n"
                stats << "Dates (start, last config, last activity): #{sdate}, #{lcdate}, #{ladate}\n"
            end
            @diag.if_level(3) { puts! stats }
            return stats
        rescue Exception => ex
            msg = "Get webfilter node statistics failed:\n" + ex
            @diag.if_level(3) { puts! msg ; p ex }
            return msg
        end
    end

    def oid_next(oid, tid)
        root = WEBFILTER_MIB_ROOT
        case oid
        when "#{root}.#{tid}"; next_oid = "#{root}.#{tid}.1"
        when "#{root}.#{tid}.9"; next_oid = "#{root}.#{tid}.10"
        when "#{root}.#{tid}.17"; next_oid = "#{root}.#{tid}.18.1"
        when "#{root}.#{tid}.18.9"; next_oid = "#{root}.#{tid}.18.10"
        when "#{root}.#{tid}.18.15"; next_oid = "#{root}.#{tid}.19"
        when /#{root}\.#{tid}(\.\d+)+/; next_oid = oid.succ
        else
            next_oid = nil
        end
        @diag.if_level(3) { puts! "Next oid: #{next_oid}" }
        return next_oid
    end
    
end # WebFilter
