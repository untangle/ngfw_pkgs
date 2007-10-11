require "ipaddr"

class ::IPAddr
  ## Simple method to only return an IPAddr if val is a valid IP Address.
  def self.parse( val )
    begin
      return self.new( val )
    rescue
    end

    ## Return nil on failure
    nil
  end
end
