class Alpaca::Components::OverrideComponent < Alpaca::Component
  def register_menu_items( menu_organizer )
    ## REVIEW : This should be declared in the status controller.
    menu_organizer.register_item( "/main/override", Alpaca::Menu::Item.new( 600, "Overrides", "/override" ))
  end
end
