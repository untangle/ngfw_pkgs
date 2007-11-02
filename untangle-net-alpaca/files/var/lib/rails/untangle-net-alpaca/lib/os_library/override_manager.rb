class OSLibrary::OverrideManager < Alpaca::OS::ManagerBase
  ## This should commit and update all of the packet filter settings.
  def commit
    logger.debug "commit has nothing to do for the override manager"
  end

  def writable?( path )
    fileOverrideList = FileOverride.ordered_find( :all )
    
    fileOverrideList.each do |fo|
      ## Ignore all of the disabled entries
      next unless fo.enabled

      ## Check if the entry matches 
      pattern = fo.path

      ## automatically prefix with a ^ to match the beginning of the string
      pattern = "^#{pattern}" unless ( pattern.index( "^" ) == 0 )
      next if path.match( pattern ).nil?

      ## Return 
      return fo.writable
    end
    
    ## Default to writable
    return true
  end

  def service_enabled?
    raise "unsupported"
  end


  ## Helper method to only write out 
  ## a file, if allowed to.
  def write_file( path, *contents )
    return nil unless writable?( path )
    
    ## Write out the contentse of the file
    File.open( path, "w" ) { |f| f.print( contents ) }
  end

  ## Helper method to only remove a file if allowed to.
  def rm_file( path )
    return nil unless writable?( path )
    
    FileUtils.rm( path, :force => true )
  end

  ## Don't think this one is going to be implemented.
  def start_service
    raise "unsupported"
  end
  
  

end
