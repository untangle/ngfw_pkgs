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
class AlpacaController < ApplicationController
  def index
    manage
    render :action => 'manage'
  end

  def manage
    ## AlpacaSettings are loaded by the application manager.
  end
  
  def to_advanced
    ## Change the level to advanced
    @alpaca_settings.config_level = AlpacaSettings::Level::Advanced.level
    @alpaca_settings.save
    
    ## Redirect the user.
    return redirect_to( :action => 'manage' )
  end

  def status
    @interfaces = Interface.find( :all )
  end
end
