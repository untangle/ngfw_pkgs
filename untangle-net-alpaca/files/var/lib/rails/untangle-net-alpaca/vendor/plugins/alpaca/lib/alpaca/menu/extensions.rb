module Alpaca::Menu::Extensions
  def menu_organizer
    Alpaca::Menu::Organizer.instance
  end
end

ActionController::Base.send :include, Alpaca::Menu::Extensions

ActionView::Base.send :include, Alpaca::Menu::Extensions
