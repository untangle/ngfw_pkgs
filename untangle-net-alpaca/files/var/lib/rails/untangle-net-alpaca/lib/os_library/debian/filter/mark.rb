## Utility for generating the mark, and all of their combinations
#
# $HeadURL$
# Copyright (c) 2007-2008 Untangle, Inc.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License, version 2,
# as published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but
# AS-IS and WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE, TITLE, or
# NONINFRINGEMENT.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA.
#
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
