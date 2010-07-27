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

  def self.add_qos_rule( attributes = {} )
    add_sample_rule( QosRule, attributes )
  end

  def self.add_qos_class( attributes = {} )
    QosClass.new(attributes).save
  end

  def self.add_sample_rule( klazz, attributes )
    @@positions = {} if @@positions.nil?
    
    ## Automatically append the new entries at the end.
    unless @@positions.include?( klazz )
      p = klazz.maximum :position
      p = 0 if p.nil?
      @@positions[klazz] = p
    end

    ## Set the position
    insert_first = attributes.delete( :insert_first )
    if insert_first.nil? || ( insert_first != true )
      attributes[:position] = ( @@positions[klazz] += 1 )
    else
      @@positions[klazz] += 1
      klazz.update_all( "position = position + 1 " )
      attributes[:position] = 1
    end

    attributes[:system_id] = nil if klazz.method_defined?( "system_id=" )
    klazz.new( attributes ).save
  end
end
