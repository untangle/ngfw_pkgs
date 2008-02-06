## REVIEW Should create a consistent way to build these tables.
class ArpController < ApplicationController
  def index
    manage
    render :action => 'manage'
  end

  def manage
    @active_arps = StaticArp.get_active( os )
    @active_arps = @active_arps.sort_by { |a| IPAddr.new(a.ip_address).to_i }
    @active_arps = @active_arps.sort_by { |a| a.interface }
    #@current_arps = `arp -n`
    @static_arps = StaticArp.find( :all )
    @static_arps = [StaticArp.new] if @static_arps.nil?
  end

  def save
    ## Review : Internationalization
    return redirect_to( :action => "manage" ) if ( params[:commit] != "Save".t )

    StaticArp.destroy_all
    
    if ! params[:static_arp].nil?
      params[:static_arp].each do |static_arp_row| 
        if (!(params[:hw_addr][static_arp_row].nil?) \
            && params[:hw_addr][static_arp_row].length > 0\
            && !(params[:hostname][static_arp_row].nil?)\
            && params[:hostname][static_arp_row].length > 0)
          
          static_arp_obj = StaticArp.new
          static_arp_obj.update_attributes( :hw_addr => params[:hw_addr][static_arp_row], :hostname => params[:hostname][static_arp_row] )
          static_arp_obj.save
        end
      end
    end
    
    os["arps_manager"].commit

    ## Review : should have some indication that is saved.
    return redirect_to( :action => "manage" )
  end
  def create_arp
    @static_arp = StaticArp.new
  end
end
