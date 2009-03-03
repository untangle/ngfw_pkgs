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
class Escalade < Alpaca::Migration
  DefaultUploadBandwidth = 384
  DefaultDownloadBandwidth = 1500
  
  def self.up
    add_column :interfaces, :download_bandwidth, :integer, :default => DefaultDownloadBandwidth
    add_column :interfaces, :upload_bandwidth, :integer, :default => DefaultUploadBandwidth

    copy_qos_bandwidth
  end

  def self.down
    remove_column :interfaces, :download_bandwidth
    remove_column :interfaces, :upload_bandwidth
  end

  def self.copy_qos_bandwidth
    external_interface = Interface.find( :all, :conditions => [ "wan = ?", true ] )
    return if external_interface.nil? || external_interface.length != 1

    external_interface = external_interface[0]

    u = DefaultUploadBandwidth
    d = DefaultDownloadBandwidth

    qos_settings = QosSettings.find( :first )    
    unless qos_settings.nil?
      u = qos_settings.upload
      d = qos_settings.download
    end

    external_interface.upload_bandwidth, external_interface.download_bandwidth = u, d
    external_interface.save
  end
end

