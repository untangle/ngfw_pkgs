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
class Alpaca::Wizard::Stage < Alpaca::Wizard::Piece
  def initialize( id, name, priority )
    super( priority )
    @id, @name = id, name 
  end
  
  ## ID that is to be used when this is referenced in list.
  def list_id
    "sl-#{@id}"
  end
  
  ## Name of the partial used to render this stage
  def partial
    @id.sub( /-[0-9]+$/, "" ).gsub( "-", "_" )
  end
  
  attr_reader :id, :name
end
