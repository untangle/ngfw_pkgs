## Handle for the IP based filtering
class OSLibrary::Debian::Filter::LocalHandler
  include OSLibrary::Debian::Filter
  include Singleton
  
  def handle( parameter, value, filters )
    filters["chain"] = "INPUT"

    ## Also indicate the mark that should be set
    m = OSLibrary::Debian::PacketFilterManager::MarkInput
    filters["mark"] = Mark.expand( filters["mark"], [[ m, m ]] )
  end

  def parameters
    [ "d-local" ]
  end
end
