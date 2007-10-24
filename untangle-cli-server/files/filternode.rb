#!/usr/local/bin/ruby
#
# filternode.rb - Base class from which all specific UVM Filter Nodes are derived, e.g., 
# WebFilter, etc.  Contains functionality shared by all such filters.
#
# Copyright (c) 2007 Untangle Inc., all rights reserved.
#
# @author <a href="mailto:ken@untangle.com">Ken Hilton</a>
# @version 0.1
#
require 'java'
require 'proxy'
require 'debug'

require 'common'
include NUCLICommon
require 'util'
include NUCLIUtil

require 'thread'

class UVMFilterNode

    include Proxy

    protected

        UVM_FILTERNODE_MIB_ROOT = ".1.3.6.1.4.1.2021.6971"
        
        DefaultTimeoutMillis = 600000
        
        # @@filternode_lock guards @@factory AND @@uvmReoteContext
        @@filternode_lock = Mutex.new
        @@factory = nil
        @@uvmRemoteContext = nil

    public
        def initialize
            @diag = Diag.new(DEFAULT_DIAG_LEVEL)
            @diag.if_level(2) { puts! "Initializing UVMFilterNode..." }
            
            begin
                @@filternode_lock.synchronize {
                    if @@factory.nil?
                        @@factory = com.untangle.uvm.client.RemoteUvmContextFactory.factory
                        connect
                    end
                } 
            rescue Exception => ex
                puts! "Error: unable to connect to Remote UVM Context Factory; UVM server may not be running -- " + ex
                raise
            end
            
            @stats_cache = {}
            @stats_cache_lock = Mutex.new

            ## This just guarantees that all of the connections are terminated.
            at_exit { @@filternode_lock.synchronize { disconnect } }
    
            @diag.if_level(2) { puts! "Done initializing UVMFilterNode..." }
        end

    public
        # If derived class does not override this method then its not a valid filter node.
        def execute(args)
            raise FilterNodeAPIVioltion, "Filter nodes does not implement the required 'execute' method"
        end

    protected
        # Caller MUST have obtained @@filternode_lock before calling this method.
        def connect
          ## Just in case
          begin
            @@factory.logout 
          rescue
            ## ignore errors
          end

          # TODO: Add exception handling.
          login

          ## Register the remote context as a proxy.
          register @@uvmRemoteContext
          true
        end

    protected
        def login
            @@uvmRemoteContext = @@factory.systemLogin( DefaultTimeoutMillis )
        end
        
    protected
        # Caller MUST have obtained @@filternode_lock before calling this method.
        def disconnect
          return if @@uvmRemoteContext.nil?
          begin
            @@factory.logout
          rescue
            ## ignore errors
          end
          @@uvmRemoteContext = nil
          true
        end

    protected
        def get_node_name()
            raise NoMethodError, "Derived class of UVMFilterNode does not implement required method 'get_node_name()'"
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
        NUM_STAT_COUNTERS = 16
        STATS_CACHE_EXPIRY = 5
    
        # A variety of filter nodes have the same, standard set of statistics.  If
        # your node exposes stats in the standard format then simply call this method
        # from your get_statistics() method.  Otherwise, you can use this method as a
        # guide for implementing your own get_statistics method.
        def get_standard_statistics(mib_root, tid, args)
            
            @diag.if_level(3) { puts! "Attempting to get stats for TID #{tid ? tid : '<no tid>'}" ; p args}
            
            # Validate arguments.
            if args[0]
                if (args[0] =~ /^-[ng]$/) == nil
                    @diag.if_level(1) { puts "Error: invalid get statistics argument '#{args[0]}"}
                    return nil
                elsif !args[1] || !(args[1] =~ /(\.\d+)+/)
                    @diag.if_level(1) { puts "Error: invalid get statistics OID: #{args[1] ? args[1] : 'missing value'}" }
                    return nil
                elsif (args[1] =~ /^#{mib_root}/) == nil 
                    @diag.if_level(1) { puts "Error: invalid get statistics OID: #{args[1]} is not a filter node OID." }
                end
            end
            
            begin
                stats = ""
                if args[0]
                    # Get the effective OID to respond to
                    oid = (args[0] == '-g') ? args[1] : oid_next(mib_root, args[1], tid)
                    return nil unless oid[0]
                    tid = oid[1]
                    oid = oid[0]
                    
                    # Get the effective node stats, either from the cache or from the UVM.
                    # (Must be after we have the OID because the TID may be nil and we'll need something to cache on.)
                    nodeStats = nil
                    @stats_cache_lock.synchronize {
                        cached_stats = @stats_cache[tid]
                        if !cached_stats || ((Time.now.to_i - cached_stats[1]) > STATS_CACHE_EXPIRY)
                            @diag.if_level(3) { puts! "Stat cache miss / expiry." }
                            node_ctx = @@uvmRemoteContext.nodeManager.nodeContext(tid)
                            nodeStats = node_ctx.getStats()
                            @stats_cache[tid] = [nodeStats, Time.now.to_i]
                        else
                            @diag.if_level(3) { puts! "Stat cache hit." }
                            nodeStats = cached_stats[0]
                        end
                    }

                    @diag.if_level(3) { puts! "Got node stats for #{tid}" ; p nodeStats }
                    
                    # Construct OID fragment to match on from >up to< the last two
                    # pieces of the effective OID, eg, xxx.1 => 1, xxx.18.2 ==> 18.2
                    int = "integer"; str = "string", c32 = "counter32"
                    mib_pieces = mib_root.split('.')
                    oid_pieces = oid.split('.')
                    stat_id = oid_pieces[(mib_pieces.length-oid_pieces.length)+1 ,2].join('.')
                    case stat_id
                        when "1";  stat, type = get_node_name, str
                        when "2";  stat, type = nodeStats.tcpSessionCount(), int
                        when "3";  stat, type = nodeStats.tcpSessionTotal(), int
                        when "4";  stat, type = nodeStats.tcpSessionRequestTotal(), int
                        when "5";  stat, type = nodeStats.udpSessionCount(), int
                        when "6";  stat, type = nodeStats.udpSessionTotal(), int
                        when "7";  stat, type = nodeStats.udpSessionRequestTotal(), int
                        when "8";  stat, type = nodeStats.c2tBytes(), int
                        when "9";  stat, type = nodeStats.c2tChunks(), int
                        when "10";  stat, type = nodeStats.t2sBytes(), int
                        when "11"; stat, type = nodeStats.t2sChunks(), int
                        when "12"; stat, type = nodeStats.s2tBytes(), int
                        when "13"; stat, type = nodeStats.s2tChunks(), int
                        when "14"; stat, type = nodeStats.t2cBytes(), int
                        when "15"; stat, type = nodeStats.t2cChunks(), int
                        when "16"; stat, type = nodeStats.startDate(), str
                        when "17"; stat, type = nodeStats.lastConfigureDate(), str
                        when "18"; stat, type = nodeStats.lastActivityDate(), str
                        when /19\.\d+/
                            counter = oid_pieces[-1].to_i()-1
                            return nil unless counter < NUM_STAT_COUNTERS
                            stat, type = nodeStats.getCount(counter), c32
                    else
                        return nil
                    end
                    stats = "#{oid}\n#{type}\n#{stat}"
                else
                    node_ctx = @@uvmRemoteContext.nodeManager.nodeContext(tid)
                    nodeStats = node_ctx.getStats()
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
                msg = "Error: get filter node statistics failed: " + ex
                @diag.if_level(3) { puts! msg ; p ex }
                return msg
            end
        end
    
        def oid_next(mib_root, oid, tid)
            @diag.if_level(3) { puts! "oid_next: #{mib_root}, #{oid}, #{tid ? tid : '<no tid>'}" }
            orig_tid = tid    

            if !tid
                if (oid == mib_root)
                    # Caller wants to walk the entire mib tree of the associated filter node type.
                    # So, walk through tid list from the beginning.
                    tids = get_filternode_tids(get_node_name())
                    tid = tids[0]
                else
                    # If oid != mib_root and !tid, then we're in the middle of walking the
                    # entire mib subtree.  Since we the only state we can count on is the
                    # incoming OID, pick up curent TID from incoming OID and then convert
                    # it from a ruby string fragment into true TID (JRuby) object.
                    mib_pieces = mib_root.split('.')
                    oid_pieces = oid.split('.')
                    cur_tid = oid_pieces[mib_pieces.length]
                    tids = get_filternode_tids(get_node_name())
                    tid = nil
                    tid = tids.detect { |t|
                        t.to_s == cur_tid
                    }
                end
                @diag.if_level(3) { puts! "oid_next: full subtree walk - effective tid=#{tid}" }                    
            end

            # Map the current OID to next OID.  This contraption of code is necessary because
            # Ruby's successor method does not simply increment its argument: it advances
            # its operand to the next logical value, e.g., "32.9".succ => "33.0", not "32.10"
            # as we want.  If no match for the OID is found the either halt the walk or advance
            # to the next TID in the tid list.
            case oid
                when "#{mib_root}"; next_oid = "#{mib_root}.#{tid}.1"
                when "#{mib_root}.#{tid}"; next_oid = "#{mib_root}.#{tid}.1"
                when "#{mib_root}.#{tid}.9"; next_oid = "#{mib_root}.#{tid}.10"
                when "#{mib_root}.#{tid}.18"; next_oid = "#{mib_root}.#{tid}.19.1"
                when "#{mib_root}.#{tid}.19.9"; next_oid = "#{mib_root}.#{tid}.19.10"
                when "#{mib_root}.#{tid}.19.15"; next_oid = "#{mib_root}.#{tid}.20"
                when /#{mib_root}\.#{tid}(\.\d+)+/; next_oid = oid.succ
            else
                if orig_tid
                    # we started w/a given tid so terminate the oid walk if no oid is matched above.
                    next_oid = nil
                else
                    # the orig_tid is nil so we're walking the whole sub-tree: advance to the next
                    # tid in the tid list; if none, terminate the walk.
                    mib_pieces = mib_root.split('.')
                    oid_pieces = oid.split('.')
                    cur_tid = oid_pieces[mib_pieces.length]
                    tids = get_filternode_tids(get_node_name())
                    next_tid = nil
                    tids.each_with_index { |tid,i| next_tid = tids[i+1] if tid.to_s == cur_tid }
                    if next_tid
                        tid = next_tid
                        next_oid = "#{mib_root}.#{tid}.1"
                    else
                        next_oid = tid = nil
                    end
                end
            end
            @diag.if_level(3) { puts! "Next oid: #{next_oid}" }
            return [next_oid, tid]
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

