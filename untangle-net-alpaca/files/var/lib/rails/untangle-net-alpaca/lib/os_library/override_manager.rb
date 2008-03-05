#
# $HeadURL$
# Copyright (c) 2007-2008 Untangle, Inc.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License, version 2,
# as published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but
# AS-IS and WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE, TITLE, or
# NONINFRINGEMENT.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA.
#
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

  ## Helper method to write a script and make it executable
  ## if allowed to.
  def write_executable( path, *contents )
    return nil unless writable?( path )
    
    ## Write out the contentse of the file
    File.open( path, "w" ) { |f| f.print( contents ) }

    ## Make the script executable
    File.chmod( 0755, path )
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
