class Alpaca::Components::NetworkComponent < Alpaca::Component
  def register_menu_items( menu_organizer, config_level )
    if ( config_level == AlpacaSettings::Level::Basic )    
      menu_organizer.register_item( "/main/network", Alpaca::Menu::Item.new( 200, "Network", "/network" ))
      menu_organizer.register_item( "/main/network/aliases", Alpaca::Menu::Item.new( 100, "Aliases", "/network/aliases" ))
      menu_organizer.register_item( "/main/network/refresh", Alpaca::Menu::Item.new( 900, "Refresh", "/network/refresh_interfaces" ))
    else
      menu_organizer.register_item( "/main/interfaces/refresh", Alpaca::Menu::Item.new( 900, "Refresh", "/network/refresh_interfaces" ))
    end
  end

  def wizard_insert_stages( builder )
  end
end
