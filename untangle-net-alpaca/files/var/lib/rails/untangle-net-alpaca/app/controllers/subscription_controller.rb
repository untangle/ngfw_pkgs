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
class SubscriptionController < ApplicationController  
  def manage
    @subscriptions = Subscription.find( :all )

    render :action => 'manage'
  end

  alias :index :manage

  def create_subscription
    ## Reasonable defaults
    @subscription = Subscription.new( :enabled => true, :subscribe => true, :position => -1, :description => "" )
  end

  def save
    ## Review : Internationalization
    if ( params[:commit] != "Save".t )
      redirect_to( :action => "manage" ) 
      return false
    end

    sub_list = []
    subscriptions = params[:subscriptions]
    enabled = params[:enabled]
    subscribe = params[:subscribe]
    filters = params[:filters]
    description = params[:description]

    logger.debug( "Read out the subscription: #{subscriptions.join}" )

    position = 0
    unless subscriptions.nil?
      subscriptions.each do |key|
        sub = Subscription.new
        sub.enabled, sub.subscribe, sub.filter = enabled[key], subscribe[key], filters[key]
        sub.description, sub.position, position = description[key], position, position + 1
        sub_list << sub
      end
    end

    Subscription.destroy_all
    sub_list.each { |sub| sub.save }

    ## Review : should have some indication that is saved.
    redirect_to( :action => "manage" )
  end

  def stylesheets
    [ "borax/list-table", "borax-subscription", "borax-overlay", "rule" ]
  end

  def scripts
    RuleHelper::Scripts + [ "subscription_manager" ]
  end
end
