## Handle for the Port based filtering
class OSLibrary::Debian::Filter::PortHandler
  include Singleton

  def handle( parameter, value, filters )
    is_src = ( parameter == 's-port' )
    
    if ( value.include?( "-" ))
      range_start, range_end, extra = value.split( "-" )
      raise "invalid range #{value}" unless extra.nil?
      
      raise "Invalid range start '#{range_start}'" unless RuleHelper.is_valid_port?( range_start )
      raise "Invalid range end '#{range_end}'" unless RuleHelper.is_valid_port?( range_end )

      ## Create a multiport rule to match the range.
      filters[parameter] = "#{match( parameter)} #{range_start}:#{range_end}"
    else
      value.split( "," ).each { |p| raise "Invalid port '#{p}'" unless RuleHelper.is_valid_port?( p )}
      filters[parameter] = "#{match( parameter)} #{value}"
    end
  end

  def parameters
    [ "s-port", "d-port" ]
  end
  
  def match( parameter )
    match = "-m multiport "
    return "#{match} --source-ports " if ( parameter == "s-port" )
    return "#{match} --destination-ports "
  end
end
  
