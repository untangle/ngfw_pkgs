class Alpaca::Components::AlpacaComponent < Alpaca::Component
  def register_menu_items( menu_organizer, config_level )
    ## REVIEW : This should be declared in the status controller.
    menu_organizer.register_item( "/main/status", Alpaca::Menu::Item.new( 50, "Status", "/alpaca/status" ))
    menu_organizer.register_item( "/main/advanced", Alpaca::Menu::Item.new( 900, "Advanced", "/alpaca/manage" ))
  end

  def wizard_insert_closers( builder )
    ## Validate the settings
    builder.insert_piece( Alpaca::Wizard::Closer.new( 1000 ) { set_level } )
  end

  private
  def set_level
    settings = AlpacaSettings.find( :first )
    if settings.nil?
      settings = AlpacaSettings.new
    end

    ## Set the level to basic.
    settings.config_level = AlpacaSettings::Level::Basic.level
    settings.save
  end  
end
