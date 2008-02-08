## Use to commmit / close the wizard session.  All of the settings
## should be committed to the database.
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

## Save priorities are as follows:
## 0    - 1000 validation : database should never be modified.
## 1000 - 2000 save       : database values are saved.
## 2000 - 3000 commit     : database values are commited to filesystem and services are restarteed.
class Alpaca::Wizard::Closer < Alpaca::Wizard::Piece
  def initialize( priority, &close )
    super( priority )
    raise "Must provide a block to save when creating a closer" if close.nil?
    @close = close
  end
  
  def save
    @close.call
  end
end
