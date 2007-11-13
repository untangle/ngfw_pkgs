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
require 'remoteapp'

class UVMFilterNode < UVMRemoteApp

    include CmdDispatcher
    include RetryLogin

    protected

        UVM_FILTERNODE_MIB_ROOT = ".1.3.6.1.4.1.2021.6971"
        
    public
        def initialize
            @diag = Diag.new(2) #DEFAULT_DIAG_LEVEL)
            @diag.if_level(2) { puts! "Initializing UVMFilterNode..." }
            
            super
    
            @stats_cache = {}
            @stats_cache_lock = Mutex.new

            @diag.if_level(2) { puts! "Done initializing UVMFilterNode..." }
        end

    public
        def execute(args)
          # TODO: BUG: if we don't return something the client reports an exception
          @diag.if_level(3) { puts! "execute(#{args.join(', ')})" }
      
          begin
            orig_args = args.dup
            retryLogin {
              # Get tids of all protocol filters once and for all commands we might execute below.
      
              begin
                tids = get_filternode_tids(get_uvm_node_name())
                if empty?(tids) then return (args[0] == "snmp") ? nil : ERROR_NO_fILTER_NODES ; end
                tid, cmd = *extract_tid_and_command(tids, args, ["snmp"])
              rescue InvalidNodeNumber, InvalidNodeId => ex
                  msg = ERROR_INVALID_NODE_ID + ": " + ex
                  @diag.if_level(3) { puts! msg ; p ex}
                  return msg
              rescue Exception => ex
                msg = "Error: #{get_node_name} filter node has encountered an unhandled exception: " + ex
                @diag.if_level(3) { puts! msg; puts! ex ; ex.backtrace }
                return msg
              end
              @diag.if_level(3) { puts! "Executing command = #{cmd} on filter node TID = #{tid}" }
              return dispatch_cmd(args.empty? ? [cmd, tid] : [cmd, tid, *args])
            }
          rescue NoMethodError => ex
              msg = ERROR_UNKNOWN_COMMAND + ": '#{orig_args.join(' ')}'"
              @diag.if_level(3) { puts! msg; puts! ex ; ex.backtrace }
              return msg
          rescue Exception => ex
            msg = "Error: '#{get_node_name}' filter node has encountered an unhandled exception: " + ex
            @diag.if_level(3) { puts! msg; puts! ex ; ex.backtrace }
            return msg
          end    
        end

    protected
        def get_uvm_node_name()
            raise NoMethodError, "Derived class of UVMFilterNode does not implement required method 'get_uvm_node_name()'"
        end
        
    protected
        def get_node_name()
            raise NoMethodError, "Derived class of UVMFilterNode does not implement required method 'get_node_name()'"
        end
        
    protected
        def get_mib_root()
            raise NoMethodError, "Derived class of UVMFilterNode does not implement required method 'get_mib_root()'"
        end

    protected
        def get_help_text()
            raise NoMethodError, "Derived class of UVMFilterNode does not implement required method 'get_help_text()'"
        end

    protected
        def get_filternode_tids(node_name)
            return @@uvmRemoteContext.nodeManager.nodeInstances(node_name)
        end
    
    protected
        # Given a filter node command request in the standard format, e.g., filternode [#X|Y] command
        # return a 2 element array composed of the effective tid and command, and strip these items
        # from the provided args array, ie, this method alters the args parameter passed into it.
        def extract_tid_and_command(tids, args, no_default_tid_for_cmds=[])
            if /^#\d+$/ =~ args[0]
                begin
                    node_num = $&[1..-1].to_i()
                    raise FilterNodeException if (node_num < 1) || (node_num > tids.length)
                    tid = tids[node_num-1]
                    cmd = args[1]
                    args.shift
                    args.shift
                rescue Exception => ex
                    raise InvalidNodeNumber, "#{args[0]}"
                end
            elsif /^\d+$/ =~ args[0]
                begin
                    rtid = $&.to_i
                    rtid_s = rtid.to_s
                    tid = tids.detect { |jtid|
                        rtid_s == jtid.to_s  # rtid_s is a ruby string but jtid is Java OBJECT: can't compare them directly so use .to_s
                    }
                    raise ArgumentError unless tid
                    cmd = args[1]
                    args.shift
                    args.shift
                rescue Exception => ex
                    raise InvalidNodeId, "#{args[0]}"
                end
            else
                cmd = args[0]
                tid = no_default_tid_for_cmds.include?(cmd) ? nil : tids[0]
                @diag.if_level(3) { puts! "extract_tid_and_command: cmd=#{cmd}, tid=#{tid ? tid : '<no tid>'}" }
                args.shift
            end
            
            return [tid, cmd]
        end

    protected
        def get_statistics(tid, args)
            return get_standard_statistics(get_mib_root(), tid, args)
        end

    protected
        NUM_STAT_COUNTERS = 16
        STATS_CACHE_EXPIRY = 60 # time (in seconds) to expiry of node stats in get_std_statistics stats cache.
    
        # A variety of filter nodes have the same, standard set of statistics.  If
        # your node exposes stats in the standard format then simply call this method
        # from your get_statistics() method.  Otherwise, you can use this method as a
        # guide for implementing your own get_statistics method.
        def get_standard_statistics(mib_root, tid, args)
            
            @diag.if_level(2) { puts! "Attempting to get stats for TID #{tid ? tid : '<no tid>'}" ; p args}
            
            # Validate arguments.
            if args[0]
                if (args[0] =~ /^-[ng]$/) == nil
                    @diag.if_level(1) { puts "Error: invalid get statistics argument '#{args[0]}"}
                    return nil
                elsif !args[1] || !(args[1] =~ /(\.\d+)+/)
                    @diag.if_level(1) { puts "Error: invalid get statistics OID: #{args[1] ? args[1] : 'missing value'}" }
                    return nil
                elsif !(args[1] =~ /^#{mib_root}/)
                    @diag.if_level(1) { puts "Error: invalid get statistics OID: #{args[1]} is not a filter node OID." ; mib_root.inspect }
                    return nil
                end
            end
            
            begin
                stats = ""
                if args[0]
                    # Get the effective OID to respond to
                    oid = nil
                    if (args[0] == '-g') # snmp get
                        oid, tid = args[1], get_true_tid_wrt_oid(mib_root,args[1])
                    elsif (args[0] == '-n') # snmp get Next
                        oid, tid = *oid_next(mib_root, args[1], tid)
                    else
                        @diag.if_level(2) { puts! "Error: invalid SNMP option encountered: '#{args[1]}'" }
                    end
                    return nil unless oid
                    
                    # Get the effective node stats, either from the cache or from the UVM.
                    # (Must be after we have the OID because the TID may be nil and we'll need something to cache on.)
                    node_stats = nil
                    @stats_cache_lock.synchronize {
                        cached_stats = @stats_cache[tid]
                        if !cached_stats || ((Time.now.to_i - cached_stats[1]) > STATS_CACHE_EXPIRY)
                            begin
                                @diag.if_level(2) { puts! "Stat cache miss / expiry." }
                                @diag.if_level(2) { p tid }
                                if (tid != "0")
                                    # We're reporting stats of a specific FN element
                                    node_ctx = @@uvmRemoteContext.nodeManager.nodeContext(tid)
                                    node_stats = hash_node_stats(node_ctx.getStats())
                                else
                                    # We're reporting stats of the aggregation of all FN's of the effective type.
                                    node_stats = aggregate_node_stats()
                                end
                                raise Exception, "Unable to fetch node stats for TID #{tid}" unless node_stats
                                @diag.if_level(2) { puts! "Updating stats cache for tid #{tid}" ; p node_stats }
                                @stats_cache[tid] = [node_stats, Time.now.to_i]
                            rescue Exception => ex
                                @diag.if_level(2) { puts! "Error: unable to get statistics for node: " ; p node_ctx ; p ex ; p ex.backtrace }
                                return nil
                            end
                        else
                            @diag.if_level(2) { puts! "Stat cache hit." }
                            node_stats = cached_stats[0]
                        end
                    }

                    @diag.if_level(2) { puts! "Got node stats for #{tid}" ; p node_stats }
                    
                    # Construct OID fragment to match on from >up to< the last two
                    # pieces of the effective OID, eg, xxx.1 => 1, xxx.18.2 ==> 18.2
                    int = "integer"; str = "string", c32 = "counter32"
                    mib_pieces = mib_root.split('.')
                    oid_pieces = oid.split('.')
                    stat_id = oid_pieces[(mib_pieces.length-oid_pieces.length)+1 ,2].join('.')
                    @diag.if_level(2) { puts! "stat_id = #{stat_id}"}
                    case stat_id
                        when "1";  stat, type = get_uvm_node_name, str
                        when "2";  stat, type = node_stats[:tcp_session_count], int
                        when "3";  stat, type = node_stats[:tcp_session_total], int
                        when "4";  stat, type = node_stats[:tcp_session_request_total], int
                        when "5";  stat, type = node_stats[:udp_session_count], int
                        when "6";  stat, type = node_stats[:udp_session_total], int
                        when "7";  stat, type = node_stats[:udp_session_request_total], int
                        when "8";  stat, type = node_stats[:c2t_bytes], int
                        when "9";  stat, type = node_stats[:c2t_chunks], int
                        when "10"; stat, type = node_stats[:t2s_bytes], int
                        when "11"; stat, type = node_stats[:t2s_chunks], int
                        when "12"; stat, type = node_stats[:s2t_bytes], int
                        when "13"; stat, type = node_stats[:s2t_chunks], int
                        when "14"; stat, type = node_stats[:t2c_bytes], int
                        when "15"; stat, type = node_stats[:t2c_chunks], int
                        when "16"; stat, type = node_stats[:start_date], str
                        when "17"; stat, type = node_stats[:last_configure_date], str
                        when "18"; stat, type = node_stats[:last_activity_date], str
                        when /19\.\d+/
                            counter = oid_pieces[-1].to_i()-1
                            return "" unless counter < NUM_STAT_COUNTERS
                            stat, type = node_stats["counter#{counter}".to_sym], c32
                        when "20"
                            @diag.if_level(2) { puts! "mib tree end - halting walk #1"}
                            return ""
                    else
                        @diag.if_level(2) { puts! "mib tree end - halting walk #2"}
                        return ""
                    end
                    stats = "#{oid}\n#{type}\n#{stat}"
                else
                    return "Error: a node ID [#X|TID] must be specified in order to retrieve " unless tid
                    node_ctx = @@uvmRemoteContext.nodeManager.nodeContext(tid)
                    node_stats = hash_node_stats(node_ctx.getStats())
                    tcpsc  = node_stats[:tcp_session_count]
                    tcpst  = node_stats[:tcp_session_total]
                    tcpsrt = node_stats[:tcp_session_request_total]
                    udpsc  = node_stats[:udp_session_count]
                    udpst  = node_stats[:udp_session_total]
                    udpsrt = node_stats[:udp_session_request_total]
                    c2tb   = node_stats[:c2t_bytes]
                    c2tc   = node_stats[:c2t_chunks]
                    t2sb   = node_stats[:t2s_bytes]
                    t2sc   = node_stats[:t2s_chunks]
                    s2tb   = node_stats[:s2t_bytes]
                    s2tc   = node_stats[:s2t_chunks]
                    t2cb   = node_stats[:t2c_bytes]
                    t2cc   = node_stats[:t2c_chunks]
                    sdate  = node_stats[:start_date]
                    lcdate = node_stats[:last_configure_date]
                    ladate = node_stats[:last_activity_date]
                    counters = []
                    (0...NUM_STAT_COUNTERS).each { |i| counters[i] = node_stats["counter#{i}".to_sym] }
                    # formant stats for human readability
                    stats << "TCP Sessions (count, total, requests): #{tcpsc}, #{tcpst}, #{tcpsrt}\n"
                    stats << "UDP Sessions (count, total, requests): #{udpsc}, #{udpst}, #{udpsrt}\n"
                    stats << "Client to Node (bytes, chunks): #{c2tb}, #{c2tc}\n"
                    stats << "Node to Client (bytes, chunks): #{t2cb}, #{t2cc}\n"
                    stats << "Server to Node (bytes, chunks): #{s2tb}, #{s2tc}\n"
                    stats << "Node to Server (bytes, chunks): #{t2sb}, #{t2sc}\n"
                    stats << "Client to Server (bytes, chunks): #{c2tb + t2sb}, #{c2tc + t2sc}\n"                    
                    stats << "Server to Client (bytes, chunks): #{s2tb + t2cb}, #{s2tc + t2cc}\n"                    
                    stats << "Counters: #{counters.join(',')}\n"
                    stats << "Dates (start, last config, last activity): #{sdate}, #{lcdate}, #{ladate}\n"
                end
                @diag.if_level(2) { puts! stats }
                return stats
            rescue Exception => ex
                msg = "Error: get filter node statistics failed: " + ex
                @diag.if_level(2) { puts! msg ; p ex ; p ex.backtrace }
                return msg
            end
        end
    
        # Derive a true TID from a given OID by converting
        # it from a ruby string fragment into true JRuby object,
        # except in the specicial case of the zero TID, in which
        # case return "0".
        def get_true_tid_wrt_oid(mib_root, oid)
            mib_pieces = mib_root.split('.')
            oid_pieces = oid.split('.')
            cur_tid = oid_pieces[mib_pieces.length]
            return "0" if cur_tid == "0"
            tids = get_filternode_tids(get_uvm_node_name())
            tid = nil
            tid = tids.detect { |t|
                t.to_s == cur_tid
            }
            return tid
        end

        def oid_next(mib_root, oid, tid)
            @diag.if_level(2) { puts! "oid_next: #{mib_root}, #{oid}, #{tid ? tid : '<no tid>'}" }
            orig_tid = tid    

            if !tid
                if (oid == mib_root)
                    # Caller wants to walk the entire mib tree of the associated filter node type.
                    # So, walk through tid list from the beginning, which in our case starts with
                    # the mythical tid zero, which represents the sum total of the stats for all
                    # filterer node instances of the effective type.  Then we move on the the stats
                    # for the individual filter node instances from the tids list.
                    @diag.if_level(2) { puts! "oid == mibroot" }
                    tid = "0"
                else
                    # If oid != mib_root and !tid, then we're in the middle of walking the
                    # entire mib subtree.  Since we the only state we can count on is the
                    # incoming OID, pick up curent TID from incoming OID.
                    @diag.if_level(2) { puts! "oid != mibroot" }
                    tid = get_true_tid_wrt_oid(mib_root, oid)
                end
                @diag.if_level(2) { puts! "oid_next: full subtree walk - effective tid=#{tid}" }                    
            end

            # Map the current OID to next OID.  This contraption of code is necessary because
            # Ruby's successor method does not simply increment its argument: it advances
            # its operand to the next logical value, e.g., "32.9".succ => "33.0", not "32.10"
            # as we want.  If no match for the OID is found then either halt the walk or advance
            # to the next TID in the tid list.
            @diag.if_level(2) { puts! "oid = #{oid}, tid = #{tid}" }
            case oid
                when "#{mib_root}"; next_oid = "#{mib_root}.#{tid}.1"
                when "#{mib_root}.#{tid}"; next_oid = "#{mib_root}.#{tid}.1"
                when "#{mib_root}.#{tid}.9"; next_oid = "#{mib_root}.#{tid}.10"
                when "#{mib_root}.#{tid}.18"; next_oid = "#{mib_root}.#{tid}.19.1"
                when "#{mib_root}.#{tid}.19.9"; next_oid = "#{mib_root}.#{tid}.19.10"
                when "#{mib_root}.#{tid}.19.16"; next_oid = nil;
                when /#{mib_root}\.#{tid}(\.\d+)+/; next_oid = oid.succ
            end
            if next_oid.nil?
                if orig_tid
                    # we started w/a given tid so terminate the oid walk if no oid is matched above.
                    @diag.if_level(2) { puts! "mib tree end - halting walk #3"}
                    next_oid = nil
                else
                    # the orig_tid is nil so we're walking the whole sub-tree: advance to the next
                    # tid in the tid list; if none, terminate the walk.
                    mib_pieces = mib_root.split('.')
                    oid_pieces = oid.split('.')
                    cur_tid = oid_pieces[mib_pieces.length]
                    next_tid = nil
                    tids = get_filternode_tids(get_uvm_node_name())
                    if cur_tid == "0"
                        next_tid = tids[0]
                    else
                        tids.each_with_index { |tid,i| next_tid = tids[i+1] if ((i < tids.length) && (tid.to_s == cur_tid)) }
                    end
                    if next_tid
                        @diag.if_level(2) { puts! "Advancing to next tid: #{next_tid}"}
                        tid = next_tid
                        next_oid = "#{mib_root}.#{tid}.1"
                    else
                        @diag.if_level(2) { puts! "mib tree end - halting walk #4"}
                        next_oid = tid = nil
                    end
                end
            end
            @diag.if_level(2) { puts! "Next oid: #{next_oid}" }
            return [next_oid, tid]
        end

    protected
        # Create a Ruby hash representation of a JRuby NodeStats object.
        def hash_node_stats(nodeStats)
            stats_hash = {}
            stats_hash[:tcp_session_count] = nodeStats.tcpSessionCount()
            stats_hash[:tcp_session_total] = nodeStats.tcpSessionTotal()
            stats_hash[:tcp_session_request_total] = nodeStats.tcpSessionRequestTotal()
            stats_hash[:udp_session_count] = nodeStats.udpSessionCount()
            stats_hash[:udp_session_total] = nodeStats.udpSessionTotal()
            stats_hash[:udp_session_request_total] = nodeStats.udpSessionRequestTotal()
            stats_hash[:c2t_bytes] = nodeStats.c2tBytes()
            stats_hash[:c2t_chunks] = nodeStats.c2tChunks()
            stats_hash[:t2s_bytes] = nodeStats.t2sBytes()
            stats_hash[:t2s_chunks] = nodeStats.t2sChunks()
            stats_hash[:s2t_bytes] = nodeStats.s2tBytes()
            stats_hash[:s2t_chunks] = nodeStats.s2tChunks()
            stats_hash[:t2c_bytes] = nodeStats.t2cBytes()
            stats_hash[:t2c_chunks] = nodeStats.t2cChunks()
            stats_hash[:start_date] = nodeStats.startDate()
            stats_hash[:last_configure_date] = nodeStats.lastConfigureDate()
            stats_hash[:last_activity_date] = nodeStats.lastActivityDate()
            (0..15).each { |i|
                stats_hash["counter#{i}".to_sym] = nodeStats.getCount(i)
            }
            return stats_hash
        end
        
    protected
        def aggregate_node_stats()
            @diag.if_level(2) { puts! "aggregate_node_stats" }
            tids = get_filternode_tids(get_uvm_node_name())
            node_stats = nil        
            tids.each { |tid|
                node_ctx = @@uvmRemoteContext.nodeManager.nodeContext(tid)
                nodeStats = node_ctx.getStats()
                if !node_stats
                    node_stats = hash_node_stats(nodeStats)
                    next
                end
                node_stats[:tcp_session_count] += nodeStats.tcpSessionCount()
                node_stats[:tcp_session_total] += nodeStats.tcpSessionTotal()
                node_stats[:tcp_session_request_total] += nodeStats.tcpSessionRequestTotal()
                node_stats[:udp_session_count] += nodeStats.udpSessionCount()
                node_stats[:udp_session_total] += nodeStats.udpSessionTotal()
                node_stats[:udp_session_request_total] += nodeStats.udpSessionRequestTotal()
                node_stats[:c2t_bytes] += nodeStats.c2tBytes()
                node_stats[:c2t_chunks] += nodeStats.c2tChunks()
                node_stats[:t2s_bytes] += nodeStats.t2sBytes()
                node_stats[:t2s_chunks] += nodeStats.t2sChunks()
                node_stats[:s2t_bytes] += nodeStats.s2tBytes()
                node_stats[:s2t_chunks] += nodeStats.s2tChunks()
                node_stats[:t2c_bytes] += nodeStats.t2cBytes()
                node_stats[:t2c_chunks] += nodeStats.t2cChunks()
                node_stats[:start_date] = nodeStats.getStartDate()
                node_stats[:last_config_date] = nodeStats.getLastConfigurationDate()
                node_stats[:last_activity_date] = nodeStats.getLastActivityDate()
                (0..15).each { |i|
                    node_stats["counter#{i}".to_sym] += nodeStats.getCount(i)
                }
            }
            return node_stats
        end
            
    protected
        def list_filternodes(tids = get_filternode_tids(get_uvm_node_name()))
          # List/enumerate protofilter nodes
          @diag.if_level(2) { puts! "#{get_uvm_node_name()}: listing nodes..." }

          ret = "#,TID,Description\n";
          tids.each_with_index { |tid, i|
            ret << "##{i+1},#{tid}," + @@uvmRemoteContext.nodeManager.nodeContext(tid).getNodeDesc().to_s + "\n"
          }
          @diag.if_level(2) { puts! "#{ret}" }
          return ret
        end

    protected
        ERROR_NO_fILTER_NODES = "No filter nodes of the requested type are installed on the effective UVM."

    protected
        def cmd_(tid, *args)
            return list_filternodes()
        end

    protected
        def cmd_help(tid, *args)
            return get_help_text()
        end

    protected
        def cmd_stats(tid, *args)
            get_statistics(tid, args)
        end
        
    protected
        def cmd_snmp(tid, *args)
            get_statistics(tid, args)
        end
        
end # UVMFilterNode

# Local exception definitions
class FilterNodeException < Exception
end
class FilterNodeAPIVioltion < FilterNodeException
end
class InvalidNodeNumber < FilterNodeException
end
class InvalidNodeId < FilterNodeException
end

