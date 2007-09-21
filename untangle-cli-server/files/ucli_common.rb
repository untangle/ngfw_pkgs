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

DEFAULT_DIAG_LEVEL = 2

# Shared error messages & strings - Perhaps we'll package these another way.
ERROR_INCOMPLETE_COMMAND = "Error: incomplete command - arguments required."
ERROR_UNKNOWN_COMMAND = "Error: unknown command"
ERROR_COMMAND_FAILED = "Error: unable to execute command"

end # UCLICommon
