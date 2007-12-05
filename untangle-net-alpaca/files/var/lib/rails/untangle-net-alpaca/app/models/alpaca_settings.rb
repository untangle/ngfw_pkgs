## These are settings for the DHCP server
class AlpacaSettings < ActiveRecord::Base
  class Level
    include Comparable
    @@levels = {}
    def initialize( level, name )
      @level, @name = level, name
      ## Insert them into to the hash
      @@levels[name] = self
      @@levels[level] = self
    end
                   
    Basic = Level.new( 1000, "Basic" )
    Advanced = Level.new( 2000, "Advanced" )

    attr_reader :level, :name

    def <=>( other )
      raise "Unable to compare a #{self.class} with a #{other.class}" unless other.is_a?( self.class )
      self.level  <=> other.level
    end
    
    ## Get a level by id or name
    def self.get_level( n )
      l = @@levels[n]
      return l unless l.nil?
      ## Always return advanced, this way if someone is having fun with their database, they won't
      ## screw up other settings in the process.
      return Advanced
    end
  end

  def get_config_level
    Level.get_level( self.config_level )
  end
end
