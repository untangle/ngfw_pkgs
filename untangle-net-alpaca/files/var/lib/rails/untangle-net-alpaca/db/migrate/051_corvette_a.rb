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
class CorvetteA < Alpaca::Migration
  def self.up
    add_column :dhcp_server_settings, :is_authoritative, :boolean, :default => false
    add_column :dhcp_server_settings, :is_custom_field_enabled, :boolean, :default => false
    add_column :dhcp_server_settings, :custom_field, :string, :default => ""
  end
  
  def self.down
    remove_column :dhcp_server_settings, :is_authoritative
    remove_column :dhcp_server_settings, :is_custom_field_enabled
    remove_column :dhcp_server_settings, :custom_field
  end
end
