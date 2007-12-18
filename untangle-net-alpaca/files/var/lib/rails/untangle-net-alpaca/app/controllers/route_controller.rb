## REVIEW Should create a consistent way to build these tables.
class RouteController < ApplicationController
  def index
    manage
    render :action => 'manage'
  end

  def manage
    #@current_routes = `/bin/netstat -rn | grep -v dummy0`
    @current_routes = NetworkRoute.get_active( os )
    @network_routes = NetworkRoute.find( :all )
    @network_routes = [] if @network_routes.nil?
    @network_routes << NetworkRoute.new
  end

  def save
    ## Review : Internationalization
    return redirect_to( :action => "manage" ) if ( params[:commit] != "Save".t )

    NetworkRoute.destroy_all

    params[:network_route].each do |network_route_row|
      if (!(params[:target][network_route_row].nil?) \
          && params[:target][network_route_row].length > 0\
          && !(params[:netmask][network_route_row].nil?) \
          && params[:netmask][network_route_row].length > 0\
          && !(params[:gateway][network_route_row].nil?) \
          && params[:gateway][network_route_row].length > 0)

        if (params[:name][network_route_row].nil?)
          params[:name][network_route_row] = ""
        end
          
        network_route_obj = NetworkRoute.new
        network_route_obj.update_attributes( :target => params[:target][network_route_row], :netmask => params[:netmask][network_route_row], :gateway => params[:gateway][network_route_row], :name => params[:name][network_route_row] )
        network_route_obj.save
      end
    end
    
    os["routes_manager"].commit

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
