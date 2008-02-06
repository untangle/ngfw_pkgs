class Alpaca::Migration < ActiveRecord::Migration
  @@positions = {}
  
  def self.add_redirect( attributes = {} )
    add_sample_rule( Redirect, attributes )
  end

  def self.add_file_override( attributes = {} )
    add_sample_rule( FileOverride, attributes )
  end

  def self.add_bypass_rule( attributes = {} )
    add_sample_rule( Subscription, attributes )
  end

  def self.add_sample_rule( klazz, attributes )
    @@positions = {} if @@positions.nil?
    @@positions[klazz] = 0 unless @@positions.include?( klazz )
    ## Set the position and make sure to disable all of these rules
    attributes[:position] = @@positions[klazz] += 1
    attributes[:system_id] = nil if klazz.method_defined?( "system_id=" )
    klazz.new( attributes ).save
  end
end
