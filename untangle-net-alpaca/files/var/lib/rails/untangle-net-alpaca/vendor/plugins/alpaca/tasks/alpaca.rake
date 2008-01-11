namespace :alpaca do
  desc "Initialize the database for the untangle-net-alpaca"  
  task :init => :insert_system_rules

  desc "Load all of the system rules."
  task :insert_system_rules => "db:migrate" do
    Alpaca::SystemRules.insert_system_rules
  end
end


