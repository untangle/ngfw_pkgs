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
class QosController < ApplicationController
  def index
    manage
    render :action => 'manage'
  end

  def create_qos
    @qos = QosRules.new
  end

  def edit
    @row_id = params[:row_id]
    raise "unspecified row id" if @row_id.nil?

    ## Not sure if the helpers are reevaluated each time, which could effect
    ## how changes to the locale manifest themselves.
    @priorities = QosHelper::QosTableModel::Priorities.map { |o| [ o[0].t, o[1] ] }
   
    @qos = QosRules.new
    @qos.description = params[:description]
    @qos.priority = params[:priority]
    @qos.enabled = params[:enabled]

    @interfaces, @parameter_list = RuleHelper::get_edit_fields( params )
  end


  def manage
    @qos_settings = QosSettings.find( :first )
    @qos_settings = QosSettings.new if @qos_settings.nil?
    
    @qoss = QosRules.find( :all )
    @bandwidth = os["qos_manager"].estimate_bandwidth
    @status = os["qos_manager"].status
  end

  def save
    ## Review : Internationalization
    return redirect_to( :action => "manage" ) if ( params[:commit] != "Save".t )

    qos_settings = QosSettings.find( :first )
    qos_settings = QosSettings.new if qos_settings.nil?
    qos_settings.update_attributes( params[:qos_settings] )
    qos_settings.save


    qos_list = []
    qoss = params[:qoss]
    enabled = params[:enabled]
    filters = params[:filters]
    description = params[:description]
    priority = params[:priority]

    position = 0
    unless qoss.nil?
      qoss.each do |key|
        qos = QosRules.new
        qos.enabled, qos.filter, qos.priority = enabled[key], filters[key], priority[key]
        qos.description, qos.position, position = description[key], position, position + 1
        qos_list << qos
      end
    end

    QosRules.destroy_all( );
    qos_list.each { |qos| qos.save }

    
    os["qos_manager"].commit

    ## Review : should have some indication that is saved.
    return redirect_to( :action => "manage" )
  end

  def status
    
  end

end
