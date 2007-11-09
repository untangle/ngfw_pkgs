class Alpaca::Components::DnsComponent < Alpaca::Component
  def register_menu_items( menu_organizer )
    menu_organizer.register_item( "/main/dns_server", Alpaca::Menu::Item.new( 400, "DNS Server", "/dns" ))
  end

  def wizard_save( params )
    ## Create a new set of settings
    dns_server_settings = DnsServerSettings.new
    
    dns_server_settings.enabled = true
    dns_server_settings.suffix = nil
    
    DnsServerSettings.destroy_all
    
    ## Review : Perhaps this should do something less harsh
    DnsStaticEntry.destroy_all

    ## Save the settings
    dns_server_settings.save
  end
end
