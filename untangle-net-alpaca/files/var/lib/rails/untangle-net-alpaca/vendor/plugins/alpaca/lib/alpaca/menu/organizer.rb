## This handles organizing all of the menu items and rendering the menu.
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
class Alpaca::Menu::Organizer
  include Singleton

  Separator = "/"
  
  def initialize
    flush
  end
  
  def register_item( path, menu_item )
    ## Strip the first separator, it is not needed.
    path.sub!( /^#{Separator}/, "" )
    
    ## Get the parent node
    parent_node, key = get_parent_node( path, true )

    ## Add the item to the parent node
    parent_node.add_child( key, menu_item )
  end

  def get_node( path )
    ## Strip the first separator, it is not needed.
    path.sub!( /^#{Separator}/, "" )
    
    ## Get the parent node
    parent_node, key = get_parent_node( path, false )

    return nil if parent_node.nil?

    return parent_node[key]
  end

  def flush
    ## Register the root item, this is never really used
    @menu_root = empty_menu_node( "root" )
  end

  private
  
  ## Retrieve the menu item that is at path, if create is false
  ## this returns nil if it can't find the item
  def get_parent_node( path, create )
    nodes = path.split( Separator )
    ## Delete the last item, that is the key for this menu item.
    key = nodes.delete_at( nodes.length - 1 )

    parent_node = @menu_root
    
    nodes.each do |node_name|
      child_node = parent_node[node_name]

      ## If the node is empty, then create a new empty node
      if child_node.nil?
        ## Do not create a new node if create is false.
        return [ nil, nil ] unless create

        child_node = empty_menu_node( node_name )
        parent_node.add_child( node_name, child_node )
      end
      
      ## Iterate down to the next node
      parent_node = child_node
    end

    [ parent_node, key ]
  end

  def empty_menu_node( node_name )
    ## Put these items towards the end
    Alpaca::Menu::Item.new( 99999, node_name, "#blank", "layouts/menu_item_blank" )
  end
end
