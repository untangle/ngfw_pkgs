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
class Alpaca::Components::AuthComponent < Alpaca::Component
  def register_menu_items( menu_organizer, config_level )
    ## REVIEW : should be a more elegant way of specifying the URL.
    ## Review : Shouldn't show this page if they are not logged in.
    unless session[:username].nil?
      menu_organizer.register_item( "/main/logout", menu_item( 1000, "Logout", :action => "logout" ))
    end
  end    
end
