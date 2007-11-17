
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
module Untangle
  module Debug
    class DebugLevel
      include Comparable
      @@cache =  {}
      
      def initialize(level, name)
        @level = level
        @name  = name
        
        @@cache[name] = self
      end
      
      ## These are messages that are only really interesting while developing a module.
      DEVEL = DebugLevel.new( 15, "devel" )

      DEBUG = DebugLevel.new(10,"debug")
      INFO = DebugLevel.new(5,"info")
      WARN = DebugLevel.new(3,"warn")
      ERROR = DebugLevel.new(0,"error")
      DEFAULT =DEBUG
      
      def <=>(other)
        self.level <=> other.level
      end
      
      def DebugLevel.[](name)
        return DEFAULT if @@cache[name] == nil
        @@cache[name]
      end

      def to_s
        @name
      end
      attr_reader :level, :name
      attr_writer :level, :name
    end
    
    Level=DebugLevel[ENV["DEBUG_LEVEL"]]
    
    def Debug.isDebugEnabled
      isLevelEnabled( DebugLevel::DEBUG )
    end
    
    def Debug.devel(msg)
      printMessage(DebugLevel::DEVEL, msg )
    end

    def Debug.debug(msg)
      printMessage(DebugLevel::DEBUG, msg )
    end
    
    def Debug.isInfoEnabled
      isLevelEnabled( DebugLevel::Info )
    end
    
    def Debug.info(msg)
      printMessage(DebugLevel::INFO, msg )
    end
    
    def Debug.isWarnEnabled
      isLevelEnabled( DebugLevel::WARN )
    end
    
    def Debug.warn(msg)
      printMessage(DebugLevel::WARN, msg )
    end
    
    def Debug.error(msg)
      printMessage(DebugLevel::ERROR, msg )
    end
    
    def Debug.printMessage(level, msg)
      puts "[#{Time.now.strftime( "%y%m%d/%H%M%S")}] #{level}: #{msg}" if isLevelEnabled( level )
    end

    def Debug.isLevelEnabled( level )
      Level >= level
    end
  end
end

include Untangle
