class Alpaca::Components::OverrideComponent < Alpaca::Component
  def register_menu_items( menu_organizer )
    ## REVIEW : This should be declared in the status controller.
    menu_organizer.register_item( "/main/override", Alpaca::Menu::Item.new( 600, "Overrides", "/override" ))
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
