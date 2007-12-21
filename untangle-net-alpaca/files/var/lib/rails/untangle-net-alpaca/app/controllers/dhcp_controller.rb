## REVIEW This should be renamed to dhcp_server_controller.
## REVIEW Should create a consistent way to build these tables.
class DhcpController < ApplicationController
  def index
    manage
    render :action => 'manage'
  end

  def create_static_entry
    @static_entry = DhcpStaticEntry.new
    if ! params[:mac_address].nil? && ! params[:ip_address].nil?
      @static_entry.mac_address = params[:mac_address]
      @static_entry.ip_address = params[:ip_address]
      @static_entry.description = params[:description]
    end
  end

  def manage
    @dhcp_server_settings = DhcpServerSettings.find( :first )
    @dhcp_server_settings = DhcpServerSettings.new if @dhcp_server_settings.nil?
    manage_entries
  end

  def manage_entries
    @dhcp_server_settings = DhcpServerSettings.find( :first )
    @dhcp_server_settings = DhcpServerSettings.new if @dhcp_server_settings.nil?
    @static_entries = DhcpStaticEntry.find( :all )

    ## Retrieve all of the dynamic entries from the DHCP server manager
    refresh_dynamic_entries
  end

  def save
    ## Review : Internationalization
    return redirect_to( :action => "manage" ) if ( params[:commit] != "Save".t )

    dhcp_server_settings = DhcpServerSettings.find( :first )
    dhcp_server_settings = DhcpServerSettings.new if dhcp_server_settings.nil?
    dhcp_server_settings.update_attributes( params[:dhcp_server_settings] )
    dhcp_server_settings.save
    
    os["dhcp_server_manager"].commit

    save_entries
    ## Review : should have some indication that is saved.
    return redirect_to( :action => "manage" )
  end

  def save_entries
    static_entry_list = []
    indices = params[:static_entries]
    mac_addresses = params[:mac_address]
    ip_addresses = params[:ip_address]
    descriptions = params[:description]

    position = 0
    unless indices.nil?
      indices.each do |key|
        dse = DhcpStaticEntry.new
        dse.mac_address, dse.ip_address, dse.description = mac_addresses[key], ip_addresses[key], descriptions[key]
        dse.position, position = position, position + 1
        static_entry_list << dse
      end
    end

    DhcpStaticEntry.destroy_all
    static_entry_list.each { |dse| dse.save }

    os["dhcp_server_manager"].commit
    #return redirect_to( :action => "manage_entries" )
  end

  def refresh_dynamic_entries
    ## Retrieve all of the dynamic entries from the DHCP server manager
    @dynamic_entries = os["dhcp_server_manager"].dynamic_entries    
  end

  def stylesheets
    [ "dhcp/static-entry", "dhcp/dynamic-entry", "borax/list-table" ]
  end

  def scripts
    [ "dhcp_server_manager" ] 
  end
end
