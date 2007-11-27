## Handle for the IP based filtering
class OSLibrary::Debian::Filter::IPHandler
  include Singleton
  
  def handle( parameter, value, filters )
    is_src = ( parameter == 's-addr' )
    if ( value.include?( "-" ))
      range_start, range_end, extra = value.split( "-" )
      raise "invalid range #{value}" unless extra.nil?
      range_start = IPAddr.new( "#{range_start}/32" )
      range_end = IPAddr.new( "#{range_end}/32" )
      filters[parameter] = "-m iprange --#{is_src ? "src" : "dst"}-range #{range_start}-#{range_end}"
    elsif ( value.include?( "," ))
      ## This will be significantly improved by using IPset.
      filters[parameter] = value.split( "," ).uniq.map do |ip|
        IPAddr.new( ip )
        ## Review ( support - )
        filters[parameter] = "--#{is_src ? "source" : "destination"} #{ip}"
      end
    else
      ## just verify that it parses
      IPAddr.new( value )
      filters[parameter] = "--#{is_src ? "source" : "destination"} #{value}"
    end
  end

  def parameters
    [ "s-addr", "d-addr" ]
  end
end
