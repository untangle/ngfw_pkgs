module DhcpHelper
  def self.wizard_save( params, session, request )
    ## Iterate all of the interfaces
    interfaceList = params[:interfaceList]
    
    raise "Invalid interface list" if ( interfaceList.nil?  || interfaceList.empty? )
    
    internal = nil
    interfaceList.each { |interface|

    ## Create a new set of settings
    dhcp_server_settings = DnsServerSettings.new
    
    dhcp_server_settings.enabled = true
    ## Have to calculate the start and end address.
    dhcp_server_settings.start = 
      
    
    ## Review : Perhaps this should do something less harsh
    DhcpStaticEntry.destroy_all

  end

end
