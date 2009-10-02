# Methods added to this helper will be available to all templates in the application.
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
module ApplicationHelper
  ## Send this instead of sending out a password stored in the database
  PASSWORD_STRING = "-[![N \"]"

  # return true if a field is nil or null.
  def ApplicationHelper.null?( field )
    return true if field.nil?
    ## Just in case the field is not a string.
    field = field.to_s
    field = field.strip
    return true if field.empty?
    return true if ( field.upcase == "NULL" )    
    false
  end

  # print a default value if null
  def print_field( value, default_value = "&nbsp;" )
    return default_value if ApplicationHelper.null?( value )
    value
  end

  def ApplicationHelper.active_record_to_json( results )
    rows = results.collect{ |u| u.attributes }
    fields = rows[0].keys.collect{ |u| { :name => u } }
    
    return { :metaData => { :totalProperty => 'count', :root => 'rows', :id => 'id', :fields => fields  }, :count => results.length, :rows => rows }.to_json
  end

  def build_table( data, table_model )
    render( :partial => "application/table", :locals => { :table_model => table_model, :data => data } )
  end

  def build_footer( actionable=true )
    render( :partial => "application/footer", :locals => { :actionable => actionable } )
  end

  def table_delete_button( row_id )
    "&nbsp;"
  end

  def table_checkbox( row_id, name, enabled, readonly = false )
    options = { :checked => enabled }
    options[:disabled] = true if readonly
    check_box( name, row_id, options, true, false )
  end

  def mac_address_link( address, title="" )
    return "" if ApplicationHelper.null?( address )
    link_to( address, "http://standards.ieee.org/cgi-bin/ouisearch?" + address.slice(0,8).gsub(/:/,''),  :title => title, :popup => [ 'new_window', 'height=450,width=650,scrollbars=1,toolbar=1,status=1,location=1,menubar=1,resizeable=1' ] )
  end

  def ApplicationHelper.get_user_command_output( session_id, key, stdout_offset = 0, stderr_offset = 0 )
    values = { "stdout" => "", "stderr" => "" }

    command_directory = Alpaca::OS::ManagerBase::UserCommandDirectory
    output_key = "#{session_id}-#{key}"
    stdout = "#{command_directory}/command-#{output_key}.out"
    stderr = "#{command_directory}/command-#{output_key}.err"
    ret = "#{command_directory}/command-#{output_key}.ret"
    
    File.open( stdout ) do |f|
      f.seek( stdout_offset, IO::SEEK_SET )
      begin
        f.read( 16 * 1024, values["stdout"] )
      rescue
      end
      values["stdout_offset"] = f.pos
    end

    File.open( stderr ) do |f|
      f.seek( stderr_offset, IO::SEEK_SET )
      begin
        f.read( 16 * 1024, values["stderr"] )
      rescue
      end
      values["stderr_offset"] = f.pos
    end
    
    if File.exists?( ret )
      File.open( ret ) do |f|
        ## If it is more than
        values["return_code"] = f.read( 256 )
      end
    else
      values["return_code"] = -1
    end

    return values
  end

  #Needs work for better validation
  #Do we need to support more than standard Ethernet?
  #The arp protocol does.
  def ApplicationHelper.mac?( address )
    return ApplicationHelper.safe_characters?( address )
  end

  #Needs work for better validation
  #Maybe see RFCs mentioned in http://en.wikipedia.org/wiki/FQDN
  def ApplicationHelper.hostname?( address )
    return ApplicationHelper.safe_characters?( address )
  end

  #Needs work for better validation
  #Could more precisely match ipv4 and ipv6 notation
  #But should be OK with networks and netmasks maybe even CIDR notation
  def ApplicationHelper.ip_address?( address )
    return ApplicationHelper.safe_characters?( address )
  end

  #attempt at a shell safe set of characters
  #especially avoiding ; " ' | > < && || / \
  def ApplicationHelper.safe_characters?( chars )
    if chars =~ /^[-A-Za-z0-9:_.,]+$/
      return true
    end
    return false
  end

  #attempt at safe characters for description
  #especially avoiding ; " ' | > < && || / \
  def ApplicationHelper.description?( chars )
    if chars =~ /^[-A-Za-z0-9:_., ]*$/
      return true
    end
    return false
  end
end
