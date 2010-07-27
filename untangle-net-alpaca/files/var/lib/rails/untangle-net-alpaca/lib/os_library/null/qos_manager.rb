# $HeadURL$
# Copyright (c) 2007-2008 Untangle, Inc.
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
class OSLibrary::Null::QosManager < OSLibrary::QosManager
  include Singleton
  Service = "/etc/untangle-net-alpaca/wshaper.htb"

  def estimate_bandwidth_v2
     download = "Unknown"
     upload = "Unknown"
     begin
       download = `rrdtool fetch #{QoSRRDLog} MAX | cut -d " " -f 2 | sort -n | tail -1`.to_f.round
       f = File.new( AptLog, "r" )
       f.each_line do |line|
         downloadMatchData = line.match( /Fetched.*\(([0-9]+)kB\/s\)/ )
         if ! downloadMatchData.nil? and downloadMatchData.length >= 2
            download = downloadMatchData[1] 
         end
       end
       upload = `rrdtool fetch #{QoSRRDLog} MAX | cut -d " " -f 3 | sort -n | tail -1`.to_f.round
     rescue
       # default to unkown
     end
     return BandwithEstimate.new( download, upload )
  end

  def status
     results = []
     lines = `#{Service} status`
     pieces = lines.split( Regexp.new( 'qdisc|class', Regexp::MULTILINE ) )
     pieces.each do |piece|
       if piece.include?( "htb" ) and piece.include?( "leaf" )
         stats = piece.split( Regexp.new( ' ', Regexp::MULTILINE ) )
         
         if PriorityQueueToName.has_key?( stats[6] )
           token_stats = piece.split( Regexp.new( 'c?tokens: ', Regexp::MULTILINE ) )
           results << [ PriorityQueueToName[stats[6]],
                        stats[10],
                        stats[14],
                        stats[19] + stats[20],
                        token_stats[1],
                        token_stats[2]
                      ]
         end
       end
     end
     return results
  end

  def status_v2( wan_interfaces = nil )
    results = []

    ## Just a bunch of random data
    Interface.wan_interfaces.map do |i|
      interface_name = i.name
      results << QosStatus.new( interface_name, "very high", rand( 0xFFFF ), rand( 0xFFFF ), rand( 0xFFFF ), rand( 0xFFFF ), rand( 0xFFFF ))
      results << QosStatus.new( interface_name, "high", rand( 0xFFFF ), rand( 0xFFFF ), rand( 0xFFFF ), rand( 0xFFFF ), rand( 0xFFFF ))
      results << QosStatus.new( interface_name, "medium", rand( 0xFFFF ), rand( 0xFFFF ), rand( 0xFFFF ), rand( 0xFFFF ), rand( 0xFFFF ))
      results << QosStatus.new( interface_name, "low", rand( 0xFFFF ), rand( 0xFFFF ), rand( 0xFFFF ), rand( 0xFFFF ), rand( 0xFFFF ))
      results << QosStatus.new( interface_name, "very low", rand( 0xFFFF ), rand( 0xFFFF ), rand( 0xFFFF ), rand( 0xFFFF ), rand( 0xFFFF ))
      results << QosStatus.new( interface_name, "limited", rand( 0xFFFF ), rand( 0xFFFF ), rand( 0xFFFF ), rand( 0xFFFF ), rand( 0xFFFF ))
      results << QosStatus.new( interface_name, "limited more", rand( 0xFFFF ), rand( 0xFFFF ), rand( 0xFFFF ), rand( 0xFFFF ), rand( 0xFFFF ))
      results << QosStatus.new( interface_name, "limited severely", rand( 0xFFFF ), rand( 0xFFFF ), rand( 0xFFFF ), rand( 0xFFFF ), rand( 0xFFFF ))
    end

    results
  end
end
