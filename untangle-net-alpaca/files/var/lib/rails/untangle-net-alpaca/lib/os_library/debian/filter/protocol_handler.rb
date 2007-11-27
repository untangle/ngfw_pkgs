## Handle for the IP based filtering
class OSLibrary::Debian::Filter::ProtocolHandler
  include Singleton
  
  def handle( parameter, value, filters )
    ## There should be a better way.
    filters[parameter] = value.split( "," ).uniq.map { |protocol| "-p #{protocol}" }
  end

  def parameters
    [ "protocol" ]
  end
end
