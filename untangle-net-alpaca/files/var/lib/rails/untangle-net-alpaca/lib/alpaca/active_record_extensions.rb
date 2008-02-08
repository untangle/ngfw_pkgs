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
module Alpaca::ActiveRecordExtensions
  module ExtensionClassMethods
    def ordered_find( *args )
      found = false
      
      args.each do |a| 
        next unless a.is_a? Hash 
        a[:order] = order_field 
        found = true
        break
      end
      
      args << { :order => order_field } unless found
      
      ## Return the new fixed args
      find( *args )
    end
  end

  def self.append_features(mod)
    #  help out people counting on transitive mixins
    unless mod.instance_of?(Class)
      raise TypeError, "Inclusion of an ActiveRecordExtensions in a module #{mod}"
    end
    super
  end
  
  def self.included(klass)
    super
    klass.extend( ExtensionClassMethods )
  end
  
  ## included module must define a method named order_field that defines the order
end
