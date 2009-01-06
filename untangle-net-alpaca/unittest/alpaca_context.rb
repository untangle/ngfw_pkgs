#
# $HeadURL: svn://chef/work/pkgs/untangle-net-alpaca/files/var/lib/rails/untangle-net-alpaca/app/controllers/hostname_controller.rb $
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

require "logger"

require "json"
require "net/http"
require "mechanize"
require "singleton"

$logger = Logger.new( STDOUT)
$logger.level = Logger::INFO

class WWW::Mechanize
  def post_raw(url, data, content_type = "application/json" )
    cur_page = Page.new( nil, { 'content-type' => 'text/html' })

    abs_url = to_absolute_uri( url, cur_page )
    request = fetch_request( abs_url, :post )
    request.add_field( 'Content-Type', content_type )
    request.add_field( 'Content-Length', data.size.to_s )
    
    page = fetch_page( abs_url, request, cur_page, [data] )
    add_to_history( page )
    page
  end
end

module Untangle
  class RequestHandler
    def initialize( read_timeout = 30, open_timeout = 10 )
      @opener = WWW::Mechanize.new
      @opener.keep_alive = true
      @opener.redirect_ok = false
      @opener.read_timeout = read_timeout
      @opener.open_timeout = open_timeout
    end
    
    def make_request( url, postdata )
      page = @opener.post_raw( url, postdata )
      page.body
    end

    def to_s
      "RequestHandler"
    end

    alias :inspect :to_s
  end

  class ServiceProxy
    @@request_id = 1

    def initialize( service_url, controller = nil, handler = nil )
      @service_url, @controller,  @handler  = service_url, controller, handler
      @handler = RequestHandler.new if @handler.nil?
    end

    def method_missing( method_id, *args )
      return ServiceProxy.new( @service_url, method_id, @handler ) if ( @controller.nil? )

      r( method_id, *args )
    end

    def to_s
      "#{@service_url} : #{@controller}"
    end

    alias :inspect :to_s

    private
    def r( method_id, *args )
      postdata = args.to_json

      $logger.debug( "#{@service_url}/#{@controller}/#{method_id}" )
      respdata = @handler.make_request( "#{@service_url}/#{@controller}/#{method_id}", postdata )

      $logger.debug( "#{respdata}" )
      response = JSON::parse( respdata )

      error = response["error"]
      raise "Unable to execute method #{@controller}.#{method_id}, #{error}" unless ( error.nil?  )

      return response["result"]
    end
  end

  $alpaca_context = ServiceProxy.new( "http://localhost:3000/alpaca/" )
end

