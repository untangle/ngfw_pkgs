namespace :alpaca do
  EtcHostFile = "/etc/hosts"

  desc "Initialize the database for the untangle-net-alpaca"  
  task :init => :insert_system_rules
  task :init => :update_interface_order 

  desc "Load all of the system rules."
  task :insert_system_rules => "db:migrate" do
    Alpaca::SystemRules.insert_system_rules
  end

  desc "Restore all of the settings from the database"
  task :restore => :init do
    ## Reload all of the managers
    os = Alpaca::OS.current_os
    Dir.new( "#{RAILS_ROOT}/lib/os_library" ).each do |manager|
      next if /_manager.rb$/.match( manager ).nil?
      
      ## Load the manager for this os, this will complete all of the initialization at
      os["#{manager.sub( /.rb$/, "" )}"]
    end

    ## Commit the network settings only if there are interfaces setup.
    os["network_manager"].commit unless Interface.find( :first ).nil?
  end

  desc "Load the network settings from the box."
  task :load_configuration => :init do
    Alpaca::ConfigurationLoader.new.load_configuration

    ## Reload all of the managers
    os = Alpaca::OS.current_os
    Dir.new( "#{RAILS_ROOT}/lib/os_library" ).each do |manager|
      next if /_manager.rb$/.match( manager ).nil?
      
      ## Load the manager for this os, this will complete all of the initialization at
      os["#{manager.sub( /.rb$/, "" )}"]
    end

    ## Commit the network settings only if there are interfaces setup.
    os["network_manager"].commit unless Interface.find( :first ).nil?
  end

  desc "Configure a box from a predefined configuration."
  task :preconfigure => :init do
    Alpaca::ConfigurationLoader.new.preconfigure

    ## Reload all of the managers
    os = Alpaca::OS.current_os
    Dir.new( "#{RAILS_ROOT}/lib/os_library" ).each do |manager|
      next if /_manager.rb$/.match( manager ).nil?
      
      ## Load the manager for this os, this will complete all of the initialization at
      os["#{manager.sub( /.rb$/, "" )}"]
    end

    ## Commit the network settings only if there are interfaces setup.
    os["network_manager"].commit unless Interface.find( :first ).nil?
  end
end


