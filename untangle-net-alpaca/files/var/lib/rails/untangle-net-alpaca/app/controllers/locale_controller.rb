class LocaleController < ApplicationController
  def index
    manage
    render :action => 'manage'
  end
  
  def manage
    @title = "Select your current Locale"
    
    @localeArray = LOCALES.collect { |key,name| [ name.t, key ] }
    @settings = LocaleSetting.find( :first )
    @settings = LocaleSetting.new( :key => "en-US" ) if @settings.nil?
  end
  
  def save
    ## Review : Internationalization
    return redirect_to( :action => "manage" ) if ( params[:commit] != "Save Changes".t )
    
    newLocale = params[:locale]
    
    logger.debug( "new locale: '#{newLocale}'" )

    ## Review : validation
    return redirect_to( :action => "manage" ) if newLocale.nil? || LOCALES[newLocale].nil?

    LocaleSetting.destroy_all

    ## Save the new locale
    LocaleSetting.new( :key => newLocale ).save
    
    return redirect_to( :action => "manage" )
  end
end
