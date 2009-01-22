#
# $HeadURL: svn://chef/work/pkgs/untangle-net-alpaca/files/var/lib/rails/untangle-net-alpaca/app/controllers/firewall_controller.rb $
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
class PacketFilterController < ApplicationController
  def get_settings
    settings = {}
    settings["user_rules"] = Firewall.find( :all, :conditions => [ "system_id IS NULL" ] )
    settings["system_rules"] = Firewall.find( :all, :conditions => [ "system_id IS NOT NULL" ] )

    json_result( :values => settings )
  end

  def set_settings
    s = json_params

    ## Destroy all of the user rules
    Firewall.destroy_all( "system_id IS NULL" )
    position = 0
    s["user_rules"].each do |entry|
      rule = Firewall.new( entry )
      rule.position = position
      rule.save
      position += position
    end
    
    s["system_rules"].each do |entry|
      rule = Firewall.find( :first, :conditions => [ "system_id = ?", entry["system_id"]] )
      next if rule.nil?
      rule.enabled = entry["enabled"]
      rule.save
    end

    ## Commit all of the packet filter rules.
    os["packet_filter_manager"].commit
    
    json_result
  end

  alias_method :index, :extjs
  
  def manage
    @firewalls = Firewall.find( :all, :conditions => [ "system_id IS NULL" ] )
    @system_firewall_list = Firewall.find( :all, :conditions => [ "system_id IS NOT NULL" ] )

    @actions = FirewallHelper::Actions.map { |o| [ o[0].t, o[1] ] }
    render :action => 'manage'
  end

  def create_firewall
    @actions = FirewallHelper::Actions.map { |o| [ o[0].t, o[1] ] }

    ## Reasonable defaults
    @firewall = Firewall.new( :enabled => true, :position => -1, :description => "" )
  end

  def edit
    @row_id = params[:row_id]
    raise "unspecified row id" if @row_id.nil?

    ## Not sure if the helpers are reevaluated each time, which could effect
    ## how changes to the locale manifest themselves.
    @actions = FirewallHelper::Actions.map { |o| [ o[0].t, o[1] ] }
    
    @firewall = Firewall.new
    @firewall.description = params[:description]
    @firewall.target = params[:target]
    @firewall.enabled = params[:enabled]

    @interfaces, @parameter_list = RuleHelper::get_edit_fields( params )
  end

  def save
    ## Review : Internationalization
    if ( params[:commit] != "Save".t )
      redirect_to( :action => "manage" )
      return false
    end

    save_user_rules
    
    ## Now update the system rules
    save_system_rules

    ## Commit all of the packet filter rules.
    os["packet_filter_manager"].commit

    ## Review : should have some indication that is saved.
    redirect_to( :action => "manage" )
  end

  def scripts
    RuleHelper::Scripts
  end

  private
  
  def save_user_rules
    fw_list = []
    firewalls = params[:firewalls]
    enabled = params[:enabled]
    filters = params[:filters]
    description = params[:description]
    target = params[:target]

    position = 0
    unless firewalls.nil?
      firewalls.each do |key|
        fw = Firewall.new
        fw.system_id = nil
        fw.enabled, fw.filter, fw.target = enabled[key], filters[key], target[key]
        fw.description, fw.position, position = description[key], position, position + 1
        fw_list << fw
      end
    end

    Firewall.destroy_all( "system_id IS NULL" );
    fw_list.each { |fw| fw.save }
  end

  def save_system_rules
    rules = params[:system_firewalls]
    enabled = params[:system_enabled]
    
    unless rules.nil?
      rules.each do |key|
        ## Skip anything with an empty or null key.
        next if ApplicationHelper.null?( key )

        fw = Firewall.find( :first, :conditions => [ "system_id = ?", key ] )
        next if fw.nil?
        fw.enabled = enabled[key]
        fw.save
      end
    end
  end
end
