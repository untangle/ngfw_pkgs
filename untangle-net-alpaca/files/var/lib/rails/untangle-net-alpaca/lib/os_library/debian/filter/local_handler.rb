## Handle for the IP based filtering
class OSLibrary::Debian::Filter::LocalHandler
  include Singleton
  
  def handle( parameter, value, filters )
    filters["chain"] = "INPUT"
  end

  def parameters
    [ "d-local" ]
  end
end
