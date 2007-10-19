class DhcpController < ApplicationController
  def index
    manage
    render :action => 'manage'
  end

  def register_menu_items
    menu_organizer.register_item( "/main/dhcp_server", Alpaca::Menu::Item.new( 300, "DHCP Server", "/dhcp" ))
  end

  def manage
    @static_entries = [ 1, 2, 3]
  end

  def stylesheets
    [ "dhcp/static-entry", "dhcp/dynamic-entry" ]
  end
end
