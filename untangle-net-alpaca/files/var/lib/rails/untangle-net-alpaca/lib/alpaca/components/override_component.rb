class Alpaca::Components::OverrideComponent < Alpaca::Component
  def register_menu_items( menu_organizer, config_level )
    if ( config_level >= AlpacaSettings::Level::Advanced ) 
      menu_organizer.register_item( "/main/advanced/override", menu_item( 900, "Overrides", {} ))
    end
  end

  def wizard_insert_closers( builder )
    builder.insert_piece( Alpaca::Wizard::Closer.new( 1050 ) { save } )
  end

  private
  def save
    ## Review : Should this delete all of the overrides?
    ## Delete all of the file overrides?
    FileOverride.destroy_all
  end
end
