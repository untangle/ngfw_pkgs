class Alpaca::Components::FirewallComponent < Alpaca::Component
  def register_menu_items( menu_organizer, config_level )
    
    if ( config_level >= AlpacaSettings::Level::Advanced ) 
      menu_organizer.register_item( "/main/advanced/firewalls",
                                    menu_item( 200, "Packet Filter", :action => "manage" ))
    end
  end
  
  def wizard_insert_closers( builder )
    ## Doesn't really matter when this happens
    builder.insert_piece( Alpaca::Wizard::Closer.new( 50 ) { validate } )
    builder.insert_piece( Alpaca::Wizard::Closer.new( 1100 ) { save } )
  end

  private

  def validate
  end

  def save
    ## Leaving the firewalls alone for now.
  end
end
