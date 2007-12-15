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
    @interface_list = Interface.find( :all )
    @interfaces = []
    @interface_list.each do |interface|
      carrier = "Unknown".t
      address = "Unknown".t
      begin
        f = "/sys/class/net/" + interface.os_name + "/carrier"
        sysfs = File.new( f, "r" )
        c = sysfs.readchar
        if c == 49 #ascii for 1
          carrier = "Connected".t
        else
          carrier = "Disconnected".t
        end
      rescue Exception => exception
        logger.error "Error reading carrier status: " + exception.to_s
        carrier = "Unknown".t
      end
      begin
        sysfs = File.new( "/sys/class/net/" + interface.os_name + "/address", "r" )
        address = sysfs.readline
      rescue Exception => exception
        address = "Unknown".t
      end
      

      @interfaces << { :columns => [ { :value => interface.name },
                                     { :value => interface.os_name },
                                     { :value => carrier },
                                     { :value => address } ] }
    end
  end

  def stylesheets
    [ "alpaca-settings", "borax/list-table" ]
  end

end
