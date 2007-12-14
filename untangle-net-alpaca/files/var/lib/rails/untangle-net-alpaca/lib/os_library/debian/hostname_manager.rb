class OSLibrary::Debian::HostnameManager < OSLibrary::HostnameManager
  include Singleton

  HostnameFile = "/etc/hostname"

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
    os["override_manager"].write_file( HostnameFile, "#{settings.hostname}" )

    run_command( "hostname #{settings.hostname}" )
  end
end

