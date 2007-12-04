class Alpaca::Components::HostnameComponent < Alpaca::Component
  class HostnameStage < Alpaca::Wizard::Stage
    def initialize( hostname )
      super( "hostname", "Hostname".t, 400 )
      @hostname = hostname
    end

    attr_reader :hostname
  end

  ## Register all of the menu items.
  def register_menu_items( menu_organizer )
    ## REVIEW : should be a more elegant way of specifying the URL.
    menu_organizer.register_item( "/main/hostname", Alpaca::Menu::Item.new( 300, "Hostname", "/hostname/" ))
  end

  def wizard_generate_review( review )
    review["hostname"] = params[:hostname]
  end
  
  ## Insert the desired stages for the wizard.
  def wizard_insert_stages( builder )
    hostname = os["hostname_manager"].current
    
    ## Register the hostname configuration stage
    builder.insert_piece( HostnameStage.new( hostname ))
  end

  def wizard_insert_closers( builder )
    builder.insert_piece( Alpaca::Wizard::Closer.new( 0 ) { validate } )
    builder.insert_piece( Alpaca::Wizard::Closer.new( 1600 ) { save } )
  end

  def validate
    raise "invalid hostname" if ApplicationHelper.null?( params[:hostname] )
  end

  def save
    hostname_settings = HostnameSettings.find( :first )
    hostname_settings = HostnameSettings.new if hostname_settings.nil?
    hostname_settings.hostname = params[:hostname]
    hostname_settings.save
  end
end
