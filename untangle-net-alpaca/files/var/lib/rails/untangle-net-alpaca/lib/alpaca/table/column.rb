## Data that is in the table 
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
class Alpaca::Table::Column
  ## css_class : The CSS Class for this columns
  ## title : Title to display in the header
  ## otherwise, generate_column must build the div.
  ## Pass in the block capable of converting a row to this column of data.
  def initialize( css_class, title, attributes = {}, &generator )
    @css_class = css_class
    title = "&nbsp;" if ( title.nil? || title.empty? )
    @title = title
    @attributes = attributes
    @generator = generator
  end
  
  ## Abstract method, given a row of a data, return the HTML
  ## to fill that row.
  ## return "&nbsp;" if @generator.nil?
  
  def generate_column( row, options ={} )
    return "&nbsp;" if @generator.nil?

    @generator.call( row, options )
  end

  ## Override this method for more advanced attributes
  def generate_attributes( row, options = {} )
    ## Convert the options into an HTML string
    @attributes.map { |k,v| "#{k}='#{v}'" }.join( " " )
  end

  ## Override this to generate a more complicated header
  def generate_header( options = {} )
    self.title.t
  end
  
  attr_reader :css_class, :title, :attributes
end
