class Alpaca::Components::AuthComponent < Alpaca::Component
  def register_menu_items( menu_organizer, config_level )
    ## REVIEW : should be a more elegant way of specifying the URL.
    ## Review : Shouldn't show this page if they are not logged in.
    unless session[:username].nil?
      menu_organizer.register_item( "/main/logout", menu_item( 1000, "Logout", :action => "logout" ))
    end
  end    
end
