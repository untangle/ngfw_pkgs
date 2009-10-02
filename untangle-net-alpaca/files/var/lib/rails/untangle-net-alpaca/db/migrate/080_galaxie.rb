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
class Galaxie < Alpaca::Migration
  def self.up
    ## Column for storing whether or not hosts in this network should spoof the host.
    add_column :arp_eater_networks, :is_spoof_host_enabled, :boolean, :default => true
    
    ## Column for a list of IP Networks / IP Addresses to apply the special NAT rule to.
    add_column :arp_eater_settings, :nat_hosts, :string, :default => ""

    add_file_override( :enabled => true, :writable => true, :description => "CHAP Secrets",
                       :path => "/etc/ppp/chap-secrets", :insert_first => true )
  end
  
  def self.down
    remove_column :arp_eater_networks, :is_spoof_host_enabled
    remove_column :arp_eater_settings, :nat_hosts
  end
end
