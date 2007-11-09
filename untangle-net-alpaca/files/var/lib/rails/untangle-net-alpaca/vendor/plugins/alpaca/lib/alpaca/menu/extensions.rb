module Alpaca::Menu::Extensions
  def menu_organizer
    Alpaca::Menu::Organizer.instance
  end
end

ActionView::Base.send :include, Alpaca::Menu::Extensions
