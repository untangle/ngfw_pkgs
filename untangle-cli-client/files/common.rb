#!/usr/local/bin/ruby
#
# ucli_common.rb - UCLI Client Common Code
#
# Copyright (c) 2007 Untangle Inc., all rights reserved.
#
# @author <a href="mailto:ken@untangle.com">Ken Hilton</a>
# @version 0.1
#

module NUCLICommon

# Error Messages

# Exceptions
class CommandFailed < Interrupt
end

class Terminate < Interrupt
end

end
