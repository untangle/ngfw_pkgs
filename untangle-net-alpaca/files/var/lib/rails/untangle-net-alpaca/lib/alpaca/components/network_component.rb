class Alpaca::Components::NetworkComponent < Alpaca::Component
  def register_menu_items( menu_organizer, config_level )
    return unless ( config_level == AlpacaSettings::Level::Basic )
    
    menu_organizer.register_item( "/main/network", Alpaca::Menu::Item.new( 200, "Network", "/network" ))
  end

  def wizard_insert_stages( builder )
  end
end
