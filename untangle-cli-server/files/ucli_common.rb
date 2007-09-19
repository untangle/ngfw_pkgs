#!/usr/local/bin/ruby
#
# ucli_server.rb - Untangle Command Line Interface Server
#
# Copyright (c) 2007 Untangle Inc., all rights reserved.
#
# @author <a href="mailto:ken@untangle.com">Ken Hilton</a>
# @version 0.1
#

module UCLICommon

# Use full UVM server functionality (requires jruby, etc.)?
UVM = true

if UVM
require 'java'
require 'proxy'
require 'debug'
end

DEFAULT_DIAG_LEVEL = 3

# Shared error messages & strings - Perhaps we'll package these another way.
ERROR_INCOMPLETE_COMMAND = "Error: incomplete command - arguments required."
ERROR_UNKNOWN_COMMAND = "Error: unknown command"

end # UCLICommon
