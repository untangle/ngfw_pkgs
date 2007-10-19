
## Load the infrastructure for loading managers.
require "alpaca.rb"

## Overload the ipaddr class to have a parse method.
require "alpaca/ipaddr"

## Insert the support for the os base
require "alpaca/os"

## Insert the specific os that is presently loaded.
require "alpaca/os/current_os"

## Manager base
require "alpaca/os/manager_base"

## OS extensions for alpaca.
require "alpaca/os/os_extensions"

## Menu System
require "alpaca/menu"
require "alpaca/menu/item"
require "alpaca/menu/organizer"
require "alpaca/menu/extensions"


