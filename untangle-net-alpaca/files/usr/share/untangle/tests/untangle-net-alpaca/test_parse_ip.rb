
class IPAddrTester
  def initialize
    @any_errors = false
  end
  def parse_ip( value, expected )
    actual = IPAddr.parse_ip( value )
    if ( actual != expected )
      puts "Invalid result(#{actual}) parse_ip #{value}, expected #{expected}"
      @any_errors = true
    end
  end

  def parse( value, expected )
    actual = IPAddr.parse( value )
    if ( actual != expected )
      puts "Invalid result(#{actual}) parse #{value}, expected #{expected}"
      @any_errors = true
    end
  end

  attr_reader :any_errors
end

tester = IPAddrTester.new

puts "\n\n\nThis will print an error message if any of the strings fail to parse.\n\n\n"

tester.parse_ip( "1.2.3.4", IPAddr.new( "1.2.3.4" ))
tester.parse_ip( "255.255.255.255", IPAddr.new( "255.255.255.255" ))
tester.parse_ip( "0.0.0.0", IPAddr.new( "0.0.0.0" ))

tester.parse_ip( "1.2.3.4.5", nil )
tester.parse_ip( "1.256.3.4", nil )
tester.parse_ip( "www.untangle.com", nil )
tester.parse_ip( "br.eth0", nil )


tester.parse( "1.2.3.4", IPAddr.new( "1.2.3.4" ))
tester.parse( "255.255.255.255", IPAddr.new( "255.255.255.255" ))
tester.parse( "0.0.0.0", IPAddr.new( "0.0.0.0" ))


tester.parse( "1.2.3.4.5", nil )
tester.parse( "1.256.3.4", nil )
tester.parse( "www.untangle.com", nil )
tester.parse( "br.eth0", nil )

tester.parse( "1.2.3.4/32", IPAddr.new( "1.2.3.4" ))
tester.parse( "255.255.255.255/32", IPAddr.new( "255.255.255.255" ))

tester.parse( "1.2.3.4.5/32", nil )
tester.parse( "1.256.3.4/32", nil )
tester.parse( "www.untangle.com/32", nil )
tester.parse( "br.eth0", nil )

for t in 0..32
  tester.parse( "1.2.3.4/#{t}", IPAddr.new( "1.2.3.4/#{t}" ))
end

for t in 33..40
  tester.parse( "1.2.3.4/#{t}", nil )
end

if tester.any_errors
  exit( 1)
else
  exit( 0 )
end



