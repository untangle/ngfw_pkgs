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
class Alpaca::Table::TableModel
  def initialize( table_name, css_class, header_css_class, row_css_class, columns )
    @table_name = table_name
    @css_class = css_class
    @header_css_class = header_css_class
    @row_css_class = row_css_class
    @columns = columns
  end

  def row_id( row )
    "e-row-#{rand( 0x100000000 )}"
  end

  ## Override these methods to remove these buttons
  def has_action
    self.respond_to? "action"
  end

  def has_label
    true
  end

  def table_name( table_data, view )
    @table_name
  end

  attr_reader :css_class, :header_css_class, :row_css_class, :columns
end
