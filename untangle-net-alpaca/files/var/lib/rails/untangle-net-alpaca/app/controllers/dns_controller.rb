class DnsController < ApplicationController  
  def manage
    @dns_server_settings = DnsServerSettings.find( :first )
    @dns_server_settings = DnsServerSettings.create_default if @dns_server_settings.nil?
    @static_entries = DnsStaticEntry.find( :all )

    ## Retrieve all of the dynamic entries from the DHCP server manager
    refresh_dynamic_entries
    
    ## this allows this method to be aliased.
    render :action => 'manage'
  end

  alias :index :manage

  def save
    ## Review : Internationalization
    return redirect_to( :action => "manage" ) if ( params[:commit] != "Save".t )

    dns_server_settings = DnsServerSettings.find( :first )
    dns_server_settings = DnsServerSettings.create_default if dns_server_settings.nil?
    dns_server_settings.update_attributes( params[:dns_server_settings] )
    dns_server_settings.save
    
    static_entry_list = []
    indices = params[:static_entries]
    hostnames = params[:hostname]
    ip_addresses = params[:ip_address]
    descriptions = params[:description]

    position = 0
    unless indices.nil?
      indices.each do |key,value|
        dse = DnsStaticEntry.new
        dse.hostname, dse.ip_address, dse.description = hostnames[key], ip_addresses[key], descriptions[key]
        dse.position, position = position, position + 1
        static_entry_list << dse
      end
    end

    DnsStaticEntry.destroy_all
    static_entry_list.each { |dse| dse.save }

    os["dns_server_manager"].commit
    
    ## Review : should have some indication that is saved.
    return redirect_to( :action => "manage" )
  end

  def create_static_entry
    @static_entry = DnsStaticEntry.new
  end

  def refresh_dynamic_entries
    ## Retrieve all of the dynamic entries from the DNS server manager
    @dynamic_entries = os["dns_server_manager"].dynamic_entries
    @dynamic_entries = @dynamic_entries.sort_by { |a| IPAddr.new(a.ip_address).to_i }   
  end

  def stylesheets
    [] # [ "dns/static-entry", "dns/dynamic-entry", "borax/list-table" ]
  end

  def scripts
    [] # [ "dns_server_manager" ] 
  end

end
