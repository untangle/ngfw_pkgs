class Alpaca::Components::DnsComponent < Alpaca::Component
  def register_menu_items( menu_organizer, config_level )
    menu_organizer.register_item( "/main/dns_server", menu_item( 500, "DNS Server", :action => "manage" ))
  end
  
  def wizard_insert_closers( builder )
    builder.insert_piece( Alpaca::Wizard::Closer.new( 1200 ) { save } )
  end

  private
  def save
    ## Create a new set of settings
    dns_server_settings = DnsServerSettings.new
    
    dns_server_settings.enabled = true    
    dns_server_settings.suffix = nil

    ## Parse out the suffix from the hostname if it is specified.
    hostname = params[:hostname]
    dns_server_settings.suffix = hostname.sub( /^[^\.]*\./, "" ) unless hostname.nil?
    
    DnsServerSettings.destroy_all
    
    ## Review : Perhaps this should do something less harsh
    DnsStaticEntry.destroy_all

    ## Save the settings
    dns_server_settings.save
  end
end
