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
class Viper < Alpaca::Migration
  def self.up
    # add new qos settings
    add_column :qos_settings, :default_class, :integer, :default => 3
    add_column :qos_settings, :scaling_factor, :integer, :default => 100
    # add new priority rules
    add_column :qos_settings, :prioritize_dns, :integer, :default => 2
    add_column :qos_settings, :prioritize_tcp_control, :integer, :default => 2
    add_column :qos_settings, :prioritize_openvpn, :integer, :default => 0

    # create new class/priority table
    create_table :qos_classes do |table|
      table.column :class_id, :integer
      table.column :upload_reserved, :integer
      table.column :upload_limit, :integer
      table.column :download_reserved, :integer
      table.column :download_limit, :integer
    end

    # create default values (8 different classes)
    # class 0 is reserved for default 
    add_qos_class( :class_id => 1, :upload_reserved => 50, :upload_limit => 100, :download_reserved => 50, :download_limit => 100 )
    add_qos_class( :class_id => 2, :upload_reserved => 25, :upload_limit => 100, :download_reserved => 25, :download_limit => 100 )
    add_qos_class( :class_id => 3, :upload_reserved => 12, :upload_limit => 100, :download_reserved => 12, :download_limit => 100 )
    add_qos_class( :class_id => 4, :upload_reserved =>  6, :upload_limit => 100, :download_reserved =>  6, :download_limit => 100 )
    add_qos_class( :class_id => 5, :upload_reserved =>  3, :upload_limit =>  75, :download_reserved =>  3, :download_limit =>  75 )
    add_qos_class( :class_id => 6, :upload_reserved =>  2, :upload_limit =>  50, :download_reserved =>  2, :download_limit =>  50 )
    add_qos_class( :class_id => 7, :upload_reserved =>  2, :upload_limit =>  10, :download_reserved =>  2, :download_limit =>  10 )

    # remove old columns
    remove_column :qos_settings, :download
    remove_column :qos_settings, :download_percentage
    remove_column :qos_settings, :upload
    remove_column :qos_settings, :upload_percentage
    remove_column :qos_settings, :prioritize_ack

    # change default priorities 
    change_column_default(:qos_settings, :prioritize_ssh, 2)
    change_column_default(:qos_settings, :prioritize_ping, 2)
    change_column_default(:qos_settings, :prioritize_gaming, 0)

    # change interfaces default bandwidth
    change_column_default(:interfaces, :download_bandwidth, 10000)
    change_column_default(:interfaces, :upload_bandwidth, 10000)

    # remove SSH rule (now has a built-in)
    custom_rules = QosRule.find( :all, :conditions => [ "description='SSH Traffic'" ] )
    custom_rules.each do |rule|
      rule.destroy
    end

    # remove DNS rule (now has a built-in)
    custom_rules = QosRule.find( :all, :conditions => [ "description='DNS Traffic'" ] )
    custom_rules.each do |rule|
      rule.destroy
    end

    # convert rules
    qos_rules = QosRule.find( :all )
    if !qos_rules.nil?
      qos_rules.each do |entry| 
        entry.priority = 1 if entry.priority == 10
        entry.priority = 2 if entry.priority == 20
        entry.priority = 3 if entry.priority == 30

        entry.save
      end
    end

    # convert priorities
    qos_settings = QosSettings.find( :first )
    # settings should always exists
    qos_settings = QosSettings.new if qos_settings.nil?
    if !qos_settings.nil?
      qos_settings.prioritize_ping = 1 if qos_settings.prioritize_ping == 10
      qos_settings.prioritize_ping = 2 if qos_settings.prioritize_ping == 20
      qos_settings.prioritize_ping = 3 if qos_settings.prioritize_ping == 30

      qos_settings.prioritize_gaming = 1 if qos_settings.prioritize_gaming == 10
      qos_settings.prioritize_gaming = 2 if qos_settings.prioritize_gaming == 20
      qos_settings.prioritize_gaming = 3 if qos_settings.prioritize_gaming == 30

      qos_settings.save
    end
  end
  
  def self.down
    remove_column :qos_settings, :default_class
    remove_column :qos_settings, :scaling_factor
    remove_column :qos_settings, :prioritize_dns
    remove_column :qos_settings, :prioritize_tcp_control

    drop_table :qos_class

    add_column :qos_settings, :download, :integer, :default => 1500
    add_column :qos_settings, :download_percentage, :integer, :default => 80
    add_column :qos_settings, :upload, :integer, :default => 384
    add_column :qos_settings, :upload_percentage, :integer, :default => 95
    add_column :qos_settings, :prioritize_ack, :integer, :default => 10

    change_column_default(:qos_settings, :prioritize_ssh, 20)
    change_column_default(:qos_settings, :prioritize_ping, 20)
    change_column_default(:qos_settings, :prioritize_gaming, 20)
    change_column_default(:interfaces, :download_bandwidth, 1500)
    change_column_default(:interfaces, :upload_bandwidth, 384)

    # set back to medium (settings don't convert back 1-1)
    qos_rules = QosRule.find( :all )
    if !qos_rules.nil?
      qos_rules.each do |entry| 
        entry.priority = 20
        entry.save
      end
    end

    # set back to medium (settings don't convert back 1-1)
    qos_settings = QosSettings.find( :first )
    if !qos_settings.nil?
      qos_settings.prioritize_ping = 20
      qos_settings.prioritize_gaming = 20
      qos_settings.save
    end
  end
end
