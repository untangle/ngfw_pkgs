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
class OSLibrary::Debian::HostnameManager < OSLibrary::HostnameManager
  include Singleton

  HostnameFile = "/etc/hostname"

  MailNameFile = "/etc/mailname"

  ## Update hostname script, used to update the files /etc/hosts
  UpdateHostNameScript = "/etc/untangle-net-alpaca/scripts/update-address.d/10-hostname"

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

    ## Update /etc/hosts
    run_command( UpdateHostNameScript )
  end
end

