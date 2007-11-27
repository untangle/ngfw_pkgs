class Alpaca::Components::LocaleComponent < Alpaca::Component
  def register_menu_items( menu_organizer )
    menu_organizer.register_item( "/main/advanced/locale", Alpaca::Menu::Item.new( 100, "Locale", "/locale" ))
  end
  
  class LocaleStage < Alpaca::Wizard::Stage
    def initialize( locale_array, settings )
      super( "locale", "Language".t, 100 )
      @locale_array = locale_array
      @settings = settings
    end

    attr_reader :locale_array, :settings
  end

  def wizard_insert_stages( builder )
    ## Register the detection stage
    settings = LocaleSetting.find( :first )
    ## Review : using en-US here is flimsy
    settings = LocaleSetting.new( :key => "en-US" ) if settings.nil?
    builder.insert_piece( LocaleStage.new( LOCALES.collect { |key,name| [ name.t, key ] }, settings ))
  end

  def wizard_insert_closers( builder )
    ## Doesn't really matter when this happens
    builder.insert_piece( Alpaca::Wizard::Closer.new( 50 ) { validate } )
    builder.insert_piece( Alpaca::Wizard::Closer.new( 1999 ) { save } )
  end

  private

  def validate
    locale = params[:locale]
    raise "Invalid locale: #{locale}" if LOCALES[locale].nil?
  end

  def save
    LocaleSetting.destroy_all
    ## Save the new locale
    LocaleSetting.new( :key => params[:locale] ).save
  end
end
