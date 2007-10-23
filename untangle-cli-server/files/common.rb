#!/usr/local/bin/ruby
#
# ucli_common.rb - Untangle Command Line Interface Server Common Code
#
# Copyright (c) 2007 Untangle Inc., all rights reserved.
#
# @author <a href="mailto:ken@untangle.com">Ken Hilton</a>
# @version 0.1
#

module NUCLICommon

DEFAULT_DIAG_LEVEL = 3
BRAND = "Untangle"

# Shared error messages & strings - Perhaps we'll package these another way.
ERROR_INCOMPLETE_COMMAND = "Error: incomplete command -- missing required arguments (see help.)"
ERROR_UNKNOWN_COMMAND = "Error: unknown command"
ERROR_COMMAND_FAILED = "Error: unable to execute command"

# Exceptions
class UserCancel < Interrupt
end

# Ruby "extensions"
module Kernel
    private
        # returns the name of the method that calls 'this_method'
        def this_method
            caller[0] =~ /`([^']*)'/ and $1
        end
end
    
end # UCLICommon
