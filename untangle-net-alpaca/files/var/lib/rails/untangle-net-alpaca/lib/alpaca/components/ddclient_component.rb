class Alpaca::Components::DdclientComponent < Alpaca::Component
  def register_menu_items( menu_organizer )
    menu_organizer.register_item( "/main/ddclient", 
                                  Alpaca::Menu::Item.new( 400, "Dynamic DNS", "/ddclient/manage" ))
  end

  def wizard_insert_closers( builder )
    builder.insert_piece( Alpaca::Wizard::Closer.new( 1200 ) { save } )
  end

  #private
  #def save
    ### Iterate all of the interfaces
    ### At this port the interfaces exist in the database.
    ### Review : internationalization, flimsy key.
    #interface = Interface.find( :first, :conditions => [ "name = ?", "Internal" ] )
#
    ### Create a new set of settings
    #ddclient_settings = DdclientSettings.new
   # 
    #internal_network = nil
    #config = interface.current_config unless interface.nil?
#
    #case config 
    #when IntfStatic then internal_network = config.ip_networks[0]
    #when IntfDynamic then internal_network = nil
    #when IntfBridge
      ### Get the configuration of the interface it is bridged with.
      #config = config.interface.current_config
      #internal_network = config.ip_networks[0] if config.is_a? IntfStatic
    #end
#
    #unless internal_network.nil?
      #ip = IPAddr.parse( internal_network.ip )
      #netmask = IPAddr.parse( "255.255.255.255/#{internal_network.netmask}" )
    #end
   # 
    #ddclient_settings.enabled = false
    #ddclient_settings.lease_duration = 0
    #ddclient_settings.gateway = nil
    #ddclient_settings.netmask = nil
   # 
    ### This will only configure /24 or larger network, the logic for
    ### smaller networks is complicated and isn't really worth it.
    #unless ( ip.nil? || netmask.nil? )
      #start_address, end_address = nil, nil
      #if (( netmask & IPAddr.parse( "0.0.0.255" )) == IPAddr.parse( "0.0.0.0" ))
        ### /24 or larger network
        #mask = ip & netmask
        #if (( mask | IPAddr.parse( "0.0.0.100" )).to_i > ip.to_i )
          #start_address = mask | IPAddr.parse( "0.0.0.100" )
          #end_address = mask | IPAddr.parse( "0.0.0.200" )
        #else
          #start_address = mask | IPAddr.parse( "0.0.0.16" )
          #end_address = mask | IPAddr.parse( "0.0.0.99" )
        #end
      #end
           # 
      #unless ( start_address.nil? || end_address.nil? )
        #ddclient_settings.enabled = true
        #ddclient_settings.start_address = start_address.to_s
        #ddclient_settings.end_address = end_address.to_s
      #end
    #end
#
    #DdclientSettings.destroy_all
    #ddclient_settings.save
  #end
end
  
