#
# $HeadURL$
# Copyright (c) 2007-2008 Untangle, Inc.
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

## Load the infrastructure for loading managers.
require "alpaca.rb"

## Overload the ipaddr class to have a parse method.
require "alpaca/ipaddr"

## Overload the helper class to do more automagic stuff.
require "alpaca/helpers"


## Insert the support for the os base
require "alpaca/os"

## Insert the specific os that is presently loaded.
require "alpaca/os/os_utils"
cur_os_file = "os_library/" + Alpaca::OS::OSUtils.distribution() + "/os"
require cur_os_file

## Temporary extensions to replace globalize.
require "alpaca/localization_extensions"

## Manager base
require "alpaca/os/manager_base"

## OS extensions for alpaca.
require "alpaca/os/os_extensions"

## Menu System
require "alpaca/menu"
require "alpaca/menu/item"
require "alpaca/menu/organizer"
require "alpaca/menu/extensions"

require "alpaca/system_rules"
