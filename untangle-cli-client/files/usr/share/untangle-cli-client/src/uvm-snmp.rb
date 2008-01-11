#!/usr/bin/ruby
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
require 'drb'

DEFAULT_PORT = 6971	# standard NUCLI server DRb port

exit(1) unless ARGV.length == 3

begin
	port = ENV["NUCLI_PORT"] ? ENV["NUCLI_PORT"] : DEFAULT_PORT
	DRb.start_service
	drb = DRbObject.new(nil, "druby://localhost:#{port}")
	res = drb.__send__(ARGV[0], ["snmp", ARGV[1], ARGV[2]])
	puts res ? res : ""
rescue Exception => ex
	puts "#{File.basename(__FILE__)} encountered an unhandled exception: #{ex}"
	puts ex.backtrace
	exit(-1)
end

exit(0)

