class OSLibrary::Debian::HostnameManager < OSLibrary::HostnameManager
  include Singleton

  HostnameFile = "/etc/hostname"

  MailNameFile = "/etc/mailname"

  ## Retrieve the current hostnanme
  def current
    `hostname`.strip
  end

  def register_hooks
    os["network_manager"].register_hook( 200, "hostname_manager", "commit", :hook_commit )
  end
  
  def hook_commit
    settings = HostnameSettings.find( :first )
    return if ( settings.nil? || settings.hostname.nil? || settings.hostname.empty? )

    ## Save the hostname
    os["override_manager"].write_file( HostnameFile, "#{settings.hostname}\n" )
    
    ## Save the hostname to /etc/mailname
    os["override_manager"].write_file( MailNameFile, "#{settings.hostname}\n" )

    run_command( "hostname #{settings.hostname}" )
  end
end

