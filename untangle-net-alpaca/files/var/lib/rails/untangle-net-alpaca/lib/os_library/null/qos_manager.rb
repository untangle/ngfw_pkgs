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

  def status_v2
    results = []
    lines = `#{Service} status`
    pieces = lines.split( Regexp.new( 'qdisc|class', Regexp::MULTILINE ) )
    pieces.each do |piece|
      next unless piece.include?( "htb" ) and piece.include?( "leaf" )
      stats = piece.split( Regexp.new( ' ', Regexp::MULTILINE ) )
      
      next unless PriorityQueueToName.has_key?( stats[6] )
      token_stats = piece.split( Regexp.new( 'c?tokens: ', Regexp::MULTILINE ) )
      results << QosStatus.new( PriorityQueueToName[stats[6]],
                                stats[10],
                                stats[14],
                                stats[19] + stats[20],
                                token_stats[1],
                                token_stats[2].strip )
    end

    return results
  end
end
