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
class RuleController < ApplicationController
  def stylesheets
    [ "rule", "borax/list-table" ]
  end

  def scripts
    RuleHelper::Scripts
  end

  def create_parameter
    @list_id = params[:list_id]

    @parameter = Rule.new
    @parameter.parameter, @parameter.value = "s-addr", ""
  end

  def create_port_forward_parameter
    ## this little nugget removes the source port for port forwards 
    @filter_types = RedirectHelper::filter_types

    create_parameter
    render :action => 'create_parameter'
  end

  def index
    interfaces = Interface.find( :all )
    interfaces.sort! { |a,b| a.index <=> b.index }

    ## This is a javascript array of the interfaces
    @interfaces = interfaces.map { |i| "new Array( '#{i.index}', '#{i.name.t}' )" }

    filters = params[:filters]
    
    unless ApplicationHelper.null?( filters )
      @parameter_list = filters.split( RuleHelper::Separator ).map do |f| 
        rule = Rule.new
        rule.parameter, rule.value = f.split( RuleHelper::TypeSeparator )
        rule
      end
    end

    @parameter_list =  [ Rule.new ] if ( @parameter_list.nil? || @parameter_list.empty? )
  end
  
  def create_filter_list
    interfaces = Interface.find( :all )
    interfaces.sort! { |a,b| a.index <=> b.index }

    @filter_id = params[:filter_id]
    raise "unspecified filter id" if @filter_id.nil?

    ## This is a javascript array of the interfaces
    @interfaces = interfaces.map { |i| "new Array( '#{i.index}', '#{i.name.t}' )" }
    
    filters = params[:filters]

    unless ApplicationHelper.null?( filters )
      @parameter_list = filters.split( RuleHelper::Separator ).map do |f| 
        rule = Rule.new
        rule.parameter, rule.value = f.split( RuleHelper::TypeSeparator )
        rule
      end
    end

    if ( @parameter_list.nil? || @parameter_list.empty? )
      r = Rule.new
      r.parameter, r.value = "s-addr", ""
      @parameter_list = [r]
    end
  end
end
