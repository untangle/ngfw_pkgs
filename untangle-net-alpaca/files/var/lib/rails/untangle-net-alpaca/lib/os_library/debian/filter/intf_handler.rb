## Handler for interface based filtering
class OSLibrary::Debian::Filter::IntfHandler
  include Singleton
  
  def handle( parameter, value, filters )    
    filters[parameter]  = value.split( "," ).uniq.map do |index|
      n = index.to_i
      raise "invalid index #{index}" if n.to_s != index
      raise "invalid index #{index}" if (( n > 8 ) || ( n < 1 ))
      mark = ( 1 << ( n - 1 ))

      ## anyone bit set should trigger the mark
      ## Review : change to bitmark when we get that working.
      "-m mark --mark #{mark}/#{mark}"
    end
  end

  def parameters
    [ "s-intf" ]
  end
end
