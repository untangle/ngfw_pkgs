namespace :alpaca do
  desc "Initialize the database for the untangle-net-alpaca"  
  task :init => :insert_system_rules

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


  desc "Upgrade task for settings from the UVM."
  task :upgrade => "alpaca:insert_system_rules"
  task :upgrade => "db:migrate" do
    Alpaca::UvmDataLoader.new.load_settings

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


