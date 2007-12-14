class Alpaca::Components::RedirectComponent < Alpaca::Component
  def register_menu_items( menu_organizer, config_level )
    menu_organizer.register_item( "/main/redirects", menu_item( 200, "Port Forwards", {} ))
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
    ## Leaving the redirects alone for now.
  end
end
