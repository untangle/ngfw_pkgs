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
class Alpaca::Wizard::Builder
  def initialize( type )
    @type = type
    @pieces = {}
  end

  ## append a piece
  def insert_piece( piece )
    ## Skip all of the items that are not the correct type
    next unless piece.is_a? @type 

    if @pieces[piece.priority].nil?
      @pieces[piece.priority] = [piece]
    else
      @pieces[piece.priority] << piece
    end
  end

  ## Iterate the pieces in order.
  def iterate_pieces
    keys = @pieces.keys.sort

    ## Iterate through each of the pieces at each of the priorties
    keys.each { |key| @pieces[key].each { |piece| yield piece }}
  end
end
