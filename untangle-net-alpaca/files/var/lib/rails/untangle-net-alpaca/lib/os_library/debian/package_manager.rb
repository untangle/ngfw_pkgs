class OSLibrary::Debian::PackageManager < OSLibrary::PackageManager
  def installed?( package )
    #XXX TMB replace ` with modified run_command
    status = `apt-get -s install #{package}`
    if status =~ / 0 newly installed/
      return true
    end
    return false
  end
  def install( package )
    run_command( "apt-get install #{package}" )
  end
end
