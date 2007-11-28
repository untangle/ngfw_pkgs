## Utility for generating the mark, and all of their combinations
class OSLibrary::Debian::Filter::Mark
  def initialize( mark, mask )
    @mark = mark
    @mask = mask
  end
  
  ## Expand the mark given this mark and mask
  def self.expand( current, new_values )
    ## Create an empty entry to hook onto if the current one is nil
    current = self.new( 0, 0 ) if current.nil?

    ## flatten the array
    current = [ current ].flatten
    
    current.map do |c|
      new_values.map do |mark,mask|
        self.new( c.mark | mark, c.mask | mask )
      end
    end.flatten
  end

  def to_s
    "-m mark --mark #{self.mark}/#{self.mark}"
  end
  
  attr_reader :mark, :mask
end
