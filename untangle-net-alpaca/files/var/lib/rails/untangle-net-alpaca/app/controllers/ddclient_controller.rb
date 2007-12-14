## REVIEW Should create a consistent way to build these tables.
class DdclientController < ApplicationController
  def index
    manage
    render :action => 'manage'
  end

  def manage
    @ddclient_settings = DdclientSettings.find( :first )
    @ddclient_settings = DdclientSettings.new if @ddclient_settings.nil?
  end

  def save
    ## Review : Internationalization
    return redirect_to( :action => "manage" ) if ( params[:commit] != "Save".t )

    ddclient_settings = DdclientSettings.find( :first )
    ddclient_settings = DdclientSettings.new if ddclient_settings.nil?
    ddclient_settings.update_attributes( params[:ddclient_settings] )
    ddclient_settings.save
    
    os["ddclient_manager"].commit

    ## Review : should have some indication that is saved.
    return redirect_to( :action => "manage" )
  end

  def stylesheets
    [ "borax/list-table" ]
  end

  def scripts
    [ ] 
  end
end
