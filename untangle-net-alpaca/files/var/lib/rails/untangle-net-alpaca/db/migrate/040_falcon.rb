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
      table.column :enabled, :boolean, :default => false
      table.column :gateway, :string
      table.column :timeout_ms, :integer
      table.column :rate_ms, :integer
      table.column :broadcast, :boolean

      ## This is presently unused.
      table.column :interface, :string
    end

    create_table :arp_eater_networks do |table|
      table.column :enabled, :boolean, :default => false
      table.column :description, :string
      table.column :spoof, :boolean
      table.column :passive, :boolean, :default => true
      table.column :ip, :string
      table.column :netmask, :string
      table.column :gateway, :string
      table.column :timeout_ms, :integer
      table.column :rate_ms, :integer
    end

    add_column :alpaca_settings, :send_icmp_redirects, :boolean, :default => true

    add_column :dhcp_server_settings, :max_leases, :integer, :default => 500

    add_file_override( :enabled => true, :writable => true, :description => "sysctl configuration",
                       :path => "/etc/untangle-net-alpaca/sysctl", :insert_first => true )
  end

  def self.down
    drop_table :arp_eater_settings
    drop_table :arp_eater_networks
    remove_column :alpaca_settings, :send_icmp_redirects
    remove_column :dhcp_server_settings, :max_leases
  end
end
