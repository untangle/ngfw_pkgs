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
class Tahoe < Alpaca::Migration
  def self.up
    create_table :qos_settings do |table|
      #if true the apply qos and qos_rules, if false do nothing
      table.column :enabled, :boolean
      #upload rate in kbps
      table.column :upload, :integer
      #download rate in kbps
      table.column :download, :integer
    end
 
    create_table :qos_rules do |table|
      table.column :enabled, :boolean
      table.column :description, :string
      table.column :filter, :string
      table.column :priority, :integer
      table.column :position, :integer
    end
  end

  def self.down
    drop_table :qos_settings
    drop_table :qos_rules
  end
end
