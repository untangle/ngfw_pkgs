class AlpacaController < ApplicationController
  def index
    manage
    render :action => 'manage'
  end

  def manage
    ## AlpacaSettings are loaded by the application manager.
  end
  
  def to_advanced
    ## Change the level to advanced
    @alpaca_settings.config_level = AlpacaSettings::Level::Advanced.level
    @alpaca_settings.save
    
    ## Redirect the user.
    return redirect_to( :action => 'manage' )
  end

  def status
    @interfaces = Interface.find( :all )
  end
end
