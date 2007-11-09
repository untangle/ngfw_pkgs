class Alpaca::Components::DhcpComponent < Alpaca::Component
  def register_menu_items( menu_organizer )
    menu_organizer.register_item( "/main/dhcp_server", 
                                  Alpaca::Menu::Item.new( 300, "DHCP Server", "/dhcp/manage" ))
    menu_organizer.register_item( "/main/dhcp_server/entries", 
                                  Alpaca::Menu::Item.new( 1, "Static Entries", "/dhcp/manage_entries" ))
  end
end
  
