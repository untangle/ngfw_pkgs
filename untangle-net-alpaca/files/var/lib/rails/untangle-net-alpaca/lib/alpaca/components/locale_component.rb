class Alpaca::Components::LocaleComponent < Alpaca::Component
  def register_menu_items( menu_organizer )
    menu_organizer.register_item( "/main/locale", Alpaca::Menu::Item.new( 500, "Locale", "/locale" ))
  end
end
