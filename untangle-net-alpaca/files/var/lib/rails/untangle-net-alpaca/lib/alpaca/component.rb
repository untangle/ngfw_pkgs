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
class Alpaca::Component
  include Alpaca::OS::OSExtensions  
  include ActionView::Helpers::UrlHelper
  include ERB::Util

  def initialize( controller, params, session, request, name = nil )
    @controller = controller
    @params = params
    @session = session
    @request = request

    if name.nil?
      name = self.class.name.sub( /^.*::(.*)Component/, '\1' ).underscore
      ## This means that the substitution didn't work.
      name = nil unless name.index( "::" ).nil?
    end

    @name = name
  end

  alias :url_helper_url_for :url_for
  
  def url_for( options )
    case options
    when Hash
      ## Automatically append the name of the controller when asked.
      options[:controller] = @name unless options.include?( :controller )
    end

    url_helper_url_for( options )
  end

  def menu_item( priority, name, options )
    Alpaca::Menu::Item.new( priority, name, url_for( options ))
  end

  attr_reader :params, :session, :request, :name
end
