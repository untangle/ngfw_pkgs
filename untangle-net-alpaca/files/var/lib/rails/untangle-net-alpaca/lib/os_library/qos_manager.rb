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
class OSLibrary::QosManager < Alpaca::OS::ManagerBase
  class BandwithEstimate
    def initialize( download, upload )
      @download, @upload = download, upload
    end

    attr_reader :download, :upload
  end

  class QosStatus
    def initialize( priority, rate, burst, sent, tokens, ctokens )
      @priority, @rate, @burst, @sent, @tokens, @ctokens = priority, rate, burst, sent, tokens, ctokens
    end
    
    attr_reader :priority, :rate, :burst, :sent, :tokens, :ctokens
  end

  NETMASK32 = { 
      "0" => "0x00000000",
      "1" => "0x80000000",
      "2" => "0xC0000000",
      "3" => "0xE0000000",
      "4" => "0xF0000000",
      "5" => "0xF8000000",
      "6" => "0xFC000000",
      "7" => "0xFE000000",
      "8" => "0xFF000000",
      "9" => "0xFF800000",
     "10" => "0xFFC00000",
     "11" => "0xFFE00000",
     "12" => "0xFFF00000",
     "13" => "0xFFF80000",
     "14" => "0xFFFC0000",
     "15" => "0xFFFE0000",
     "16" => "0xFFFF0000",
     "17" => "0xFFFF8000",
     "18" => "0xFFFFC000",
     "19" => "0xFFFFE000",
     "20" => "0xFFFFF000",
     "21" => "0xFFFFF800",
     "22" => "0xFFFFFC00",
     "23" => "0xFFFFFE00",
     "24" => "0xFFFFFF00",
     "25" => "0xFFFFFF80",
     "26" => "0xFFFFFFC0",
     "27" => "0xFFFFFFE0",
     "28" => "0xFFFFFFF0",
     "29" => "0xFFFFFFF8",
     "30" => "0xFFFFFFFC",
     "31" => "0xFFFFFFFE",
     "32" => "0xFFFFFFFF",
     "0.0.0.0" => "0x00000000",
     "128.0.0.0" => "0x80000000",
     "192.0.0.0" => "0xC0000000",
     "224.0.0.0" => "0xE0000000",
     "240.0.0.0" => "0xF0000000",
     "248.0.0.0" => "0xF8000000",
     "252.0.0.0" => "0xFC000000",
     "254.0.0.0" => "0xFE000000",
     "255.0.0.0" => "0xFF000000",
     "255.128.0.0" => "0xFF800000",
     "255.192.0.0" => "0xFFC00000",
     "255.224.0.0" => "0xFFE00000",
     "255.240.0.0" => "0xFFF00000",
     "255.248.0.0" => "0xFFF80000",
     "255.252.0.0" => "0xFFFC0000",
     "255.254.0.0" => "0xFFFE0000",
     "255.255.0.0" => "0xFFFF0000",
     "255.255.128.0" => "0xFFFF8000",
     "255.255.192.0" => "0xFFFFC000",
     "255.255.224.0" => "0xFFFFE000",
     "255.255.240.0" => "0xFFFFF000",
     "255.255.248.0" => "0xFFFFF800",
     "255.255.252.0" => "0xFFFFFC00",
     "255.255.254.0" => "0xFFFFFE00",
     "255.255.255.0" => "0xFFFFFF00",
     "255.255.255.128" => "0xFFFFFF80",
     "255.255.255.192" => "0xFFFFFFC0",
     "255.255.255.224" => "0xFFFFFFE0",
     "255.255.255.240" => "0xFFFFFFF0",
     "255.255.255.248" => "0xFFFFFFF8",
     "255.255.255.252" => "0xFFFFFFFC",
     "255.255.255.254" => "0xFFFFFFFE",
     "255.255.255.255" => "0xFFFFFFFF"
   }
   #hmm no one ever uses a port netmask, so this probably doesn't help
   NETMASK16 = {
      "0" => "0x0000",
      "1" => "0x8000",
      "2" => "0xC000",
      "3" => "0xE000",
      "4" => "0xF000",
      "5" => "0xF800",
      "6" => "0xFC00",
      "7" => "0xFE00",
      "8" => "0xFF00",
      "9" => "0xFF80",
     "10" => "0xFFC0",
     "11" => "0xFFE0",
     "12" => "0xFFF0",
     "13" => "0xFFF8",
     "14" => "0xFFFC",
     "15" => "0xFFFE",
     "16" => "0xFFFF"
   }

  #override this
  def estimate_bandwidth
     download = "Unknown"
     upload = "Unknown"
     return [download, upload]
  end

  def estimate_bandwith_v2
    return BandwithStatus.new( "Unknown", "Unknown" )
  end

  def status
    "None"
  end

  def status_v2
    return []
  end

  def start_time
    ""
  end

end
