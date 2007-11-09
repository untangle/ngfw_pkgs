class Alpaca::Components::InterfaceComponent < Alpaca::Component
  ## Register all of the menu items.
  def register_menu_items( menu_organizer )
    ## REVIEW : should be a more elegant way of specifying the URL.
    menu_organizer.register_item( "/main/interfaces", Alpaca::Menu::Item.new( 200, "Interfaces", "/interface/list" ))

    ## Retrieve all of the interfaces
    interfaces = Interface.find(:all)
    interfaces.sort! { |a,b| a.index <=> b.index }

    interfaces.each do |i|
      menu_item = Alpaca::Menu::Item.new( i.index, i.name, "/interface/config/#{i.id}" )
      menu_organizer.register_item( "/main/interfaces/#{i.os_name}", menu_item )
    end    
  end

  class InterfaceTestStage < Alpaca::Wizard::Stage
    def initialize( interface_list )
      super( "interface-test", "Detection".t, 100 )
      @interface_list = interface_list
    end

    attr_reader :interface_list
  end

  class InterfaceStage < Alpaca::Wizard::Stage
    def initialize( id, interface, wan )
      name = InterfaceController::DefaultInterfaceMapping[interface.os_name]
      name = [ interface.os_name ] if name.nil?
      name = name[0]
      super( id, name, 200 )
      @interface, @wan = interface, wan
    end

    def partial
      "interface_config"
    end
    attr_reader :interface, :wan
  end

  ## Insert the desired stages for the wizard.
  def wizard_insert_stages( builder )
    ## Can't use the shorthand because this is a module.
    ## @interfaces = os["network_manager"].interfaces
    interface_list = Alpaca::OS.current_os["network_manager"].interfaces

    ## Sort the interface list
    interface_list.sort! do |a,b|
      a_mapping = InterfaceController::DefaultInterfaceMapping[a.os_name]
      b_mapping = InterfaceController::DefaultInterfaceMapping[b.os_name]
      
      next a.os_name <=> b.os_name if ( a_mapping.nil? && b_mapping.nil? )
      next -1 if !a_mapping.nil? && b_mapping.nil?
      next 1 if a_mapping.nil? && !b_mapping.nil?

      ## Both are non-nil
      a_mapping[1] <=> b_mapping[1]
    end

    ## Register the detection stage
    builder.insert_piece( InterfaceTestStage.new( interface_list ))

    ## Register all of the interfaces
    index = 0
    interface_list.each do |interface| 
      s = InterfaceStage.new( "interface-config-#{index+=1}", interface, index == 1 )
      builder.insert_piece( s )
    end
  end
end
