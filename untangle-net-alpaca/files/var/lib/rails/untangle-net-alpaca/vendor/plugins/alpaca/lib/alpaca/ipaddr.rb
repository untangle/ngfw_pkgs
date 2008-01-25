## Load the global ipaddr.
require "ipaddr"

class ::IPAddr
  ## Simple method to only return an IPAddr if val is a valid IP Address.
  def self.parse( val )
    begin
      ## Invalid if there are two many slashes (IPAddr doesn't catch this)
      return nil if ( val.count( "/" ) > 1 )
      return self.new( val )
    rescue
    end

    ## Return nil on failure
    nil
  end
end
