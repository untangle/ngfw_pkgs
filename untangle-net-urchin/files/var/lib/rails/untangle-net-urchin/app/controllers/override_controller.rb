require_dependency "os_library"

class OverrideController < ApplicationController
  layout "main"
  
  def index
    manage
    render :action => 'manage'
  end

  def manage
    @fileOverrideList = FileOverride.find( :all, :order => "position" )
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
    return redirect_to( :action => "manage" ) if ( params[:commit] != "Save Changes" )

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

    ## Review : Internationalization
    return redirect_to( :action => "manage" )
  end
end
