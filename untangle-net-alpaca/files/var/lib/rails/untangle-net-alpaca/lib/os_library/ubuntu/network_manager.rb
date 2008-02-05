class OSLibrary::Ubuntu::NetworkManager < OSLibrary::Debian::NetworkManager

  InterfacesStatusFile = "/var/run/network/ifstate"

  def get_interfaces_status_file
    return InterfacesStatusFile
  end

end
