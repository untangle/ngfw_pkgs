#
# UCLI Utility methods
#

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
    
    def initialize(diagnostic_level)
        @diagnostic_level = diagnostic_level
    end
        
    def if_level(diagnostic_level, *args)
        yield args if block_given? && diagnostic_level <= @diagnostic_level
    end
end

# Exceptions
class UserCancel < Interrupt
end

if $0 == __FILE__
    diagnostic = Diag.new(2)
    diagnostic.if_level(3, 1, 2, 3, String.new("foo bar")) { |args|
        p args
    }
end
