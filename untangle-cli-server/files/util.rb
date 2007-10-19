#!/usr/local/bin/ruby
#
# ucli_util.rb - UCLI Utility methods
#
# Copyright (c) 2007 Untangle Inc., all rights reserved.
#
# @author <a href="mailto:ken@untangle.com">Ken Hilton</a>
# @version 0.1
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

end # UCLIUtil

if $0 == __FILE__
    include UCLIUtil
    diagnostic = Diag.new(2)
    diagnostic.if_level(3, 1, 2, 3, String.new("foo bar")) { |args|
        p args
    }
end
