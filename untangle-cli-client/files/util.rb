#!/usr/local/bin/ruby
#
# ucli_util.rb - UCLI Utility methods
#
# Copyright (c) 2007 Untangle Inc., all rights reserved.
#
# @author <a href="mailto:ken@untangle.com">Ken Hilton</a>
# @version 0.1
#

module UCLIUtil
    
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
        end
            
        def if_level(diagnostic_level, *args)
            yield args if block_given? && diagnostic_level <= @diagnostic_level
        end
    end
    
    def confirm_overwrite(file)
        if File.exists? file
            print! "File '#{file}' already exists - overwrite (y/n)? "
            return false unless getyn("y")
            File.delete args[1]
        end
        return true
    end
    
    # Exceptions
    class UserCancel < Interrupt
    end

end # UCLIUtil

if $0 == __FILE__
    include UCLIUtil
    diagnostic = Diag.new(2)
    diagnostic.if_level(3, 1, 2, 3, String.new("foo bar")) { |args|
        p args
    }
end
