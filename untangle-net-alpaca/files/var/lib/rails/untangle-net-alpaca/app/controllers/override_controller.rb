class OverrideController < ApplicationController

  def register_menu_items
    ## REVIEW : This should be declared in the status controller.
    menu_organizer.register_item( "/main/override", Alpaca::Menu::Item.new( 600, "Overrides", "/override" ))
  end
  
  def index
    manage
    render :action => 'manage'
  end

  def manage
    @fileOverrideList = FileOverride.ordered_find( :all )
  end

  def create_file_override
    @file_override = FileOverride.new
    ## Reasonable defaults
    ## Review: is there some way to do this in the model.
    @file_override.enabled = true
    @file_override.writeable = false
    @file_override.path = ""
    @file_override.position = -1
  end

  def file_override_remove
    @rowId = params[ :id ]

    raise "no row id" if @rowId.nil?

    raise "invalid row id syntax" if /^fo-row-[0-9]*$/.match( @rowId ).nil?
  end

  def save
    ## Review : Internationalization
    return redirect_to( :action => "manage" ) if ( params[:commit] != "Save Changes".t )

    
    fileOverrideList = []

    indices = params[:fileOverrides]
    enabled = params[:enabled]
    writeable = params[:writeable]
    path = params[:path]
    
    # No file overrides to save if there are no indices
    position = 0
    unless indices.nil?
      indices.each do |key,value|
        ## fileOverride
        fo = FileOverride.new()
        fo.enabled, fo.writeable, fo.path = enabled[key], writeable[key], path[key]
        fo.position = position
        position += 1
        fileOverrideList << fo
      end
    end
    
    ## Delete all of the old ones
    FileOverride.destroy_all
    
    ## Save all of the new ones
    fileOverrideList.each { |fo| fo.save }

    ## Review : should have some indication that is saved.
    return redirect_to( :action => "manage" )
  end
end
