class Alpaca::Components::WizardComponent < Alpaca::Component
  def register_menu_items( menu_organizer, config_level )
    menu_organizer.register_item( "/main/status/wizard", Alpaca::Menu::Item.new( 100, "Wizard", "/wizard" ))
    menu_organizer.register_item( "/main/advanced", Alpaca::Menu::Item.new( 900, "Advanced", "#blank" ))
  end

  def wizard_insert_stages( builder )
    ## Register the detection stage
    builder.insert_piece( Alpaca::Wizard::Stage.new( "welcome", "Welcome".t, 0 ))
    builder.insert_piece( Alpaca::Wizard::RjsStage.new( "review", "Review".t, 999, "generate_review" ))
    builder.insert_piece( Alpaca::Wizard::Stage.new( "finish", "Finished".t, 1000 ))
  end
end
