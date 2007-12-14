class Alpaca::Components::NetworkComponent < Alpaca::Component
  def register_menu_items( menu_organizer, config_level )
    if ( config_level == AlpacaSettings::Level::Basic )    
      menu_organizer.register_item( "/main/network", menu_item( 200, "Network", {} ))
      menu_organizer.register_item( "/main/network/aliases", 
                                    menu_item( 100, "Aliases", :action => "aliases" ))
      menu_organizer.register_item( "/main/network/refresh", 
                                    menu_item( 900, "Refresh", :action => "refresh_interfaces" ))
    else
      menu_organizer.register_item( "/main/interfaces/refresh", 
                                    menu_item( 900, "Refresh", :action => "refresh_interfaces" ))
    end
  end

  def wizard_insert_stages( builder )
  end
end
