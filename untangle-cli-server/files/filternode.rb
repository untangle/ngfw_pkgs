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

# Local exception definitions
class FilterNodeException < Exception
end
class FilterNodeAPIVioltion < FilterNodeException
end
class InvalidNodeNumber < Exception
end
class InvalidNodeId < Exception
end

class UVMFilterNode

    include Proxy

    protected

        UVM_FILTERNODE_MIB_ROOT = ".1.3.6.1.4.1.1234"
        
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
        # Given a filter node command request in the standard format, e.g., filternode [#X|Y] command
        # return a 2 element array conposed of the effective tid and command and strip these items
        # from the provided args array.
        def extract_tid_and_command(tids, args)
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
                    node_num = -1
                    tid = tids.detect { |jtid|
                        node_num += 1
                        rtid.to_s == jtid.to_s  # rtid is a ruby int, jtid is Java OBJECT - can't compare directly so use to_s
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
                tid = tids[0]
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
            
            @diag.if_level(3) { puts! "Attempting to get stats for TID #{tid}" }
            
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
                stats = ""
                if args[0]
                    oid = (args[0] == '-g') ? args[1] : oid_next(mib_root, args[1], tid)
                    return nil unless oid
                    # Construct OID fragment to match on from >up to< the last two
                    # pieces of the effective OID, eg, xxx.1 => 1, xxx.18.2 ==> 18.2
                    int = "integer"; str = "string", c32 = "counter32"
                    mib_pieces = mib_root.split('.')
                    oid_pieces = oid.split('.')
                    stat_id = oid_pieces[(mib_pieces.length-oid_pieces.length)+1 ,2].join('.')
                    case stat_id
                        when "1";  stat, type = nodeStats.tcpSessionCount(), int
                        when "2";  stat, type = nodeStats.tcpSessionTotal(), int
                        when "3";  stat, type = nodeStats.tcpSessionRequestTotal(), int
                        when "4";  stat, type = nodeStats.udpSessionCount(), int
                        when "5";  stat, type = nodeStats.udpSessionTotal(), int
                        when "6";  stat, type = nodeStats.udpSessionRequestTotal(), int
                        when "7";  stat, type = nodeStats.c2tBytes(), int
                        when "8";  stat, type = nodeStats.c2tChunks(), int
                        when "9";  stat, type = nodeStats.t2sBytes(), int
                        when "10"; stat, type = nodeStats.t2sChunks(), int
                        when "11"; stat, type = nodeStats.s2tBytes(), int
                        when "12"; stat, type = nodeStats.s2tChunks(), int
                        when "13"; stat, type = nodeStats.t2cBytes(), int
                        when "14"; stat, type = nodeStats.t2cChunks(), int
                        when "15"; stat, type = nodeStats.startDate(), str
                        when "16"; stat, type = nodeStats.lastConfigureDate(), str
                        when "17"; stat, type = nodeStats.lastActivityDate(), str
                        when /18\.\d+/
                            counter = oid_pieces[-1].to_i()-1
                            return nil unless counter < NUM_STAT_COUNTERS
                            stat, type = nodeStats.getCount(counter), c32
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
                msg = "Get filter node statistics failed:\n" + ex
                @diag.if_level(3) { puts! msg ; p ex }
                return msg
            end
        end
    
        def oid_next(mib_root, oid, tid)
            case oid
            when "#{mib_root}.#{tid}"; next_oid = "#{mib_root}.#{tid}.1"
            when "#{mib_root}.#{tid}.9"; next_oid = "#{mib_root}.#{tid}.10"
            when "#{mib_root}.#{tid}.17"; next_oid = "#{mib_root}.#{tid}.18.1"
            when "#{mib_root}.#{tid}.18.9"; next_oid = "#{mib_root}.#{tid}.18.10"
            when "#{mib_root}.#{tid}.18.15"; next_oid = "#{mib_root}.#{tid}.19"
            when /#{mib_root}\.#{tid}(\.\d+)+/; next_oid = oid.succ
            else
                next_oid = nil
            end
            @diag.if_level(3) { puts! "Next oid: #{next_oid}" }
            return next_oid
        end

end # UVMFilterNode

