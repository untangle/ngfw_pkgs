# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  # return true if a field is nil or null.
  def ApplicationHelper.null?( field )
    return true if field.nil?
    field = field.strip
    return true if field.empty?
    return true if ( field.upcase == "NULL" )    
    false
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

  def table_checkbox( row_id, name, enabled )
    check_box( name, row_id, { :checked => enabled }, true, false )
  end

  def mac_address_link( address )
    link_to( address, "http://standards.ieee.org/cgi-bin/ouisearch?" + address.slice(0,8),  :popup => [ 'new_window', 'height=450,width=650,scrollbars=1,toolbar=1,status=1,location=1,menubar=1,resizeable=1' ] )
  end


  def handle_flash_messages
    css_class = false
    body = ""
    if !flash[:notification].nil? and flash[:notification].length > 0
      css_class = "notification"
      body << flash[:notification]
    end
    if !flash[:warning].nil? and flash[:warning].length > 0
      css_class = "warning"
      body << flash[:warning]
    end
    if !flash[:error].nil? and flash[:error].length > 0
      css_class = "error"
      body << flash[:error]
    end
    if css_class != false
      return "<div class=\"#{css_class}\">#{body}</div>"
    end
    return ""
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

  # generates the editable tables
  # Arguments are a hash like:
  #editable_table( 
  # action is no used
  #:action => "/arp/create_entry", 
  # the GetText translatable names that go at the tops of the columns
  #:header_columns => [ { :name => "Hostname".t }, 
  #                     { :name => "HWaddress".t },
  #		       { :name => "Delete".t } ],
  # the internal database names for the columns, must be in the same
  # order as the header
  #:column_names =>  [ "hostname", "hw_addr" ],
  # title that is displayed in h1 tags before the data
  #:title => "Static Arp".t,
  # rows is array of hashes in a format like the following comment below  
  #:rows => rows,
  # name of the variable to be used in the form, probably name of db table
  #:rows_name => "static_arp",
  # if auto size is true then javascript code will make each column the same
  # size
  #:auto_size => true,
  # to prevent editing on the client side
  #:read_only => true,
  # delete to false to remove the delete column
  #:delete => false,
  # add to false to remove plus button
  #:add => false
  # )
  #
  # Rows look like:
  #rows = []
  # @static_arps.each do |static_arp|
  #  rows << { :columns => [ { :value => static_arp.hostname },
  #  	               { :value => static_arp.hw_addr } ] }
  #end
  def editable_table( options = {} )
    result = "<div>"
    if ! options[:title].nil?
      result << "<div id=\"title\"><h1>" + options[:title] + "</h1></div>"
    end

    if ! options[:heading].nil?
      result << "<h2>" + options[:heading] + "</h2>"
    end


    tableId="e_table_#{rand( 0x100000000 )}"
    #result << link_to_remote( "+".t, :url => { :action => options[:action].to_s } )

    blank_columns = ""
    options[:column_names].each do |column|
      blank_columns << "<div class=\"list-table-column "+column+"\">"
      blank_columns << "<input name=\""+column+"['+rowId+']\" type=\"text\" size=\"30\" />"
      blank_columns << "</div>"
    end

    if options[:add].nil? || options[:add]

      result << javascript_tag("function addRow"+tableId+"() { var rowId=Math.floor(Math.random()*10000000000); new Insertion.Bottom('"+tableId+"','<li id=\"'+rowId+'\" class=\"list-table-row\"><input type=\"hidden\" name=\""+options[:rows_name]+"[]\" value=\"'+rowId+'\" />"+blank_columns+"<div class=\"minus\" onClick=\"Alpaca.removeStaticEntry(\\''+rowId+'\\')\"> - </div></li> '); resize"+tableId+"(); }")

      result << button_to_function("+".t, "addRow"+tableId+"()")
    end

    result << "<div class=\"list-table " + options[:class].to_s + "\">"
    result << "<ul id=\"" + tableId + "\" class=\"list-table-list " + options[:class].to_s + "\">"
    result << "<li class=\"header " + options[:header_class].to_s + "\">"
    
    options[:header_columns].each do |column|
      result << "<div class=\"list-table-header-column " + column[:class].to_s + "\">"
      result << column[:name].to_s + "</div>"
    end

    result << "</li>\n"

    options[:rows].each do |row|
      rowId="e-row-#{rand( 0x100000000 )}"
      result << "<li id=\""+rowId+"\" class=\"list-table-row " + row[:class].to_s + "\">"
      result << hidden_field_tag( options[:rows_name] + "[]", rowId )
      
      column_count = 0
      row[:columns].each do |column|
        result << "<div class=\"list-table-column " + column[:class].to_s  + " " + options[:column_names][column_count] + "\">"
        column_args = { :value => column[:value] }
        if ! options[:read_only].nil? && options[:read_only] == true
          column_args[:readonly] = "readonly"
        end
        result << text_field( options[:column_names][column_count], rowId, column_args )
        result << "</div>"
        column_count = column_count + 1
      end
      if options[:delete].nil? || options[:delete]
        result << "<div class=\"minus\" onClick=\"Alpaca.removeStaticEntry( '" + rowId + "' )\"> - </div>"
      end
      
      result << "</li>"
    end
    result << "</ul>\n</div></div>\n"

    auto_size = "function resize"+tableId+"() {"
    if ! options[:auto_size].nil? && options[:auto_size] == true
      auto_size << "var v"+tableId+" = document.getElementById('"+tableId+"'); var v"+tableId+"w= v"+tableId+".offsetWidth;  var c"+tableId+" = v"+tableId+".childNodes; for(var i = 0; i < c"+tableId+".length; i++){if (c"+tableId+"[i].nodeName.toLowerCase() == 'li') { var lic = c"+tableId+"[i].childNodes; for (var c = 0; c < lic.length; c++) { if (lic[c].nodeName.toLowerCase() == 'div') { lic[c].style.width = Math.floor((v"+tableId+"w) / "+options[:header_columns].length.to_s+")-6+'px';} } } }"
    end
    auto_size << "}"
    auto_size << "resize"+tableId+"();"
    result << javascript_tag(auto_size)
    return result
  end
end
