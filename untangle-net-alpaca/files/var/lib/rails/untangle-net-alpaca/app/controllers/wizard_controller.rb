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
class WizardController < ApplicationController
  InterfaceKey = "interface-config"

  ## This is the method helpers use to dynamically add stages
  ## to the wizard.
  InsertStagesMethod = "wizard_insert_stages"

  ## This is a method to register variables that are needed to generate the review page
  ReviewMethod = "wizard_generate_review"

  InsertClosersMethod = "wizard_insert_closers"

  def index
    @title = "Setup Wizard"

    ## This should be in a global place
    @cidr_options = OSLibrary::NetworkManager::CIDR.map { |k,v| [ format( "%-3s &nbsp; %s", k, v ) , k ] }

    @cidr_options.sort! { |a,b| a[1].to_i <=> b[1].to_i }

    @builder = Alpaca::Wizard::Builder.new( Alpaca::Wizard::Stage )

    ## Iterate all of the helpers in search of stages for the wizard
    iterate_components do |component|
      next unless component.respond_to?( InsertStagesMethod )
      component.send( InsertStagesMethod, @builder )
    end
  end

  def generate_review
    @stage_id = params[:stage_id]
    
    raise "Unable to determine stage to replace" if ApplicationHelper.null?( @stage_id )

    @review = {}
    ## Iterate all of the components in search of stages for the wizard
    iterate_components do |component|
      next unless component.respond_to?( ReviewMethod )
      component.send( ReviewMethod, @review )
    end
  end
  
  def save
    builder = Alpaca::Wizard::Builder.new( Alpaca::Wizard::Closer )

    ## Iterate all of the components in search of stages for the wizard
    iterate_components do |component|
      next unless component.respond_to?( InsertClosersMethod )
      component.send( InsertClosersMethod, builder )
    end
    
    ## Iterate all of the closers calling save.
    builder.iterate_pieces do |closer|
      closer.save
    end
  end

end
