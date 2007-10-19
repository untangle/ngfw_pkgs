class DnsController < ApplicationController
  def index
    manage
    render :action => 'manage'
  end
  
  def register_menu_items
    menu_organizer.register_item( "/main/dns_server", Alpaca::Menu::Item.new( 400, "DNS Server", "/dns" ))
  end

  def manage
    @static_entries = [ 1, 2, 3]
  end

  def stylesheets
    [ "dns/static-entry", "dns/dynamic-entry" ]
  end
end
