## Handler for interface based filtering
class OSLibrary::Debian::Filter::IntfHandler
  include OSLibrary::Debian::Filter
  include Singleton
  
  def handle( parameter, value, filters )    
    ## Indicate which marks should be set
    intf_marks = value.split( "," ).uniq.map do |index|
      n = index.to_i
      raise "invalid index #{index}" if n.to_s != index
      raise "invalid index #{index}" if (( n > 8 ) || ( n < 1 ))
      mark = ( 1 << ( n - 1 ))

      ## The mask is the mark
      [ mark, mark ]
    end

    filters["mark"] = Mark.expand( filters["mark"], intf_marks )

    puts "marks: #{filters["mark"]}"
  end

  def parameters
    [ "s-intf" ]
  end
end
