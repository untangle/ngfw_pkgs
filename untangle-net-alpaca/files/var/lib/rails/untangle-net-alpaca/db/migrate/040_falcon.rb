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
class Falcon < Alpaca::Migration
  def self.up
    create_table :arp_eater_settings do |table|
      table.column :enabled, :boolean
      table.column :gateway, :string
      table.column :timeout_ms, :int
      table.column :rate_ms, :int
      table.column :broadcast, :boolean

      ## This is presently unused.
      table.column :interface, :string
    end

    create_table :arp_eater_networks do |table|
      table.column :enabled, :boolean
      table.column :description, :string
      table.column :spoof, :boolean
      table.column :opportunistic, :boolean
      table.column :ip, :string
      table.column :netmask, :string
      table.column :gateway, :string
      table.column :timeout_ms, :int
      table.column :rate_ms, :int
    end
  end

  def self.down
    drop_table :arp_eater_settings
    drop_table :arp_eater_networks
  end
end
