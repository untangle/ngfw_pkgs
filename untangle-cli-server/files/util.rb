#!/usr/local/bin/ruby
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
#
module NUCLIUtil
    
    def print!(msg)
        print msg
        STDOUT.flush
    end
    
    def puts!(msg)
        puts msg
        STDOUT.flush
    end
    
    def getyn(y_or_n="y")
        STDIN.gets.chomp.downcase == y_or_n
    end
    
    class Diag
        
        attr_accessor :level
        
        def initialize(diagnostic_level=0)
            @diagnostic_level = diagnostic_level
            @tracer = 1
        end
            
        def if_level(diagnostic_level, *args)
            yield args if block_given? && diagnostic_level <= @diagnostic_level
        end
        
        def trace(tracer = @tracer)
            @tracer = 1 if tracer == 1
            puts! tracer
            @tracer += 1
        end
    end
    
    def empty?(obj)
        obj.nil? || (obj=="") || ((obj.respond_to? :length) && (obj.length == 0))
    end

    def validate_bool(var, varname)
        unless ["true", "false"].include?(var)
            raise "Error: invalid value for '#{varname}' - valid values are 'true' and 'false'."
        end
        var == "true"
    end
  
    def validate_range(var, range, varname)
        unless range === var
            raise "Error: invalid value for '#{varname}' - valid values are #{range.min}..#{range.max}"
        end
    end
    
    def validate_list(var, list, varname)
      unless list.find {|allowed_val| allowed_val == var}
        raise "Error: invalid value for '#{varname}' - valid values are #{list.join(', ')}"
      end
    end
    

end # UCLIUtil

if $0 == __FILE__
    include UCLIUtil
    diagnostic = Diag.new(2)
    diagnostic.if_level(3, 1, 2, 3, String.new("foo bar")) { |args|
        p args
    }
end
