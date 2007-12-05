## REVIEW Should create a consistent way to build these tables.
class ArpController < ApplicationController
  def index
    manage
    render :action => 'manage'
  end

  def manage
    @current_arps = `arp`
    @static_arps = StaticArp.find( :all )
    @static_arps = [] if @static_arp.nil?
    @static_arps << StaticArp.new
  end

  def save
    ## Review : Internationalization
    return redirect_to( :action => "manage" ) if ( params[:commit] != "Save Changes".t )

    StaticArp.destroy_all

    params[:static_arp].each do |static_arp_row| 
      static_arp_obj = StaticArp.new
      static_arp_obj.update_attributes( static_arp_row )
      static_arp_obj.save
    end
    
    os["arps_manager"].commit

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
