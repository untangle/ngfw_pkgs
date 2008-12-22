## Default way of rendering a menu item.
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
class Alpaca::Menu::Item
  ## Default to the global partial
  DefaultPartial = "layouts/menu_item"

  def initialize( index, name, action, partial = DefaultPartial, children_hash = {} )
    @index = index
    @name = name
    @action = action
    @partial = partial
    @children_hash = children_hash
    @children_array = @children_hash.values.sort
  end

  ## should always use add_child, otherwise rendering may return
  ## a list that is not sorted properly.
  def add_child( key, menu_item )
    current_child = @children_hash[key]
    
    ## Create a new menu item with the children if the item is being replaced.
    menu_item = self.class.copy_children( menu_item, current_child ) unless current_child.nil?

    @children_hash[key] = menu_item
    @children_array = @children_hash.values.sort
  end

  ## True iff this item has any children
  def children?
    !@children_hash.empty?
  end

  ## Get the children, in an ordered array
  def children
    @children_array
  end

  def []( key )
    @children_hash[key]
  end

  def to_json( *args )
    { "children" => @children_array, 
      "name" => @name, 
      "page" => @action }.to_json
  end

  def <=>( other )
    order = self.index <=> other.index
    return order unless order == 0
    return self.name <=> other.name
  end

  attr_reader :index, :name, :action, :partial, :children_hash

  private
  
  ## Copy the children from c_item and the parameters from n_item into a new menu item.
  def self.copy_children( n_item, c_item )
    ## Create a new menu item
    new( n_item.index, n_item.name, n_item.action, n_item.partial, c_item.children_hash )
  end
    
end
