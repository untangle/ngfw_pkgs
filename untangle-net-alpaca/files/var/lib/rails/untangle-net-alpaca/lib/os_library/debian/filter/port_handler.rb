## Handle for the Port based filtering
class OSLibrary::Debian::Filter::PortHandler
  include Singleton

  def handle( parameter, value, filters )
    is_src = ( parameter == 's-port' )
    
    if ( value.include?( "-" ))
      range_start, range_end, extra = value.split( "-" )
      raise "invalid range #{value}" unless extra.nil?
      raise "Invalid range start #{range_start}" if ( range_start.to_i.to_s != range_start )
      raise "Invalid range end #{range_end}" if ( range_end.to_i.to_s != range_end )
      
      filters[parameter] = "-m multiport --#{is_src ? "source" : "ports"} #{range_start}:#{range_end}"
    elsif ( value.include?( "," ))
      value.split( "," ).each { |p| raise "Invalid port" if p.to_i.to_s != p }
      filters[parameter] = "-m multiport --#{is_src ? "source" : "ports"} #{value}"
    else
      ## just verify that it parses
      raise "Invalid port" if value.to_i.to_s != value
      filters[parameter] = "--#{is_src ? "source" : "destination"}-port #{value}"
    end
  end

  def parameters
    [ "s-port", "d-port" ]
  end
end
  
