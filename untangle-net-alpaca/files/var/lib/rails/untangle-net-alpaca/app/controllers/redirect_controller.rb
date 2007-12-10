class RedirectController < ApplicationController  
  def manage
    @redirects = Redirect.find( :all, :conditions => [ "system_id IS NULL" ] )
    @system_redirect_list = Redirect.find( :all, :conditions => [ "system_id IS NOT NULL" ] )

    render :action => 'manage'
  end

  alias :index :manage

  def create_redirect
    ## Reasonable defaults
    @redirect = Redirect.new( :enabled => true, :position => -1, :description => "" )
  end

  def edit
    @row_id = params[:row_id]
    raise "unspecified row id" if @row_id.nil?
    
    @redirect = Redirect.new
    @redirect.description = params[:description]
    @redirect.new_ip = params[:new_ip]
    @redirect.new_enc_id = params[:new_enc_id]
    @redirect.enabled = params[:enabled]

    @interfaces, @parameter_list = RuleHelper::get_edit_fields( params )
  end

  def save
    ## Review : Internationalization
    if ( params[:commit] != "Save".t )
      redirect_to( :action => "manage" ) 
      return false
    end

    save_user_rules

    save_system_rules

    ## Commit all of the packet filter rules.
    os["packet_filter_manager"].commit

    ## Review : should have some indication that is saved.
    redirect_to( :action => "manage" )
  end

  def stylesheets
    [ "borax/list-table", "borax-redirect", "borax-overlay", "rule" ]
  end

  def scripts
    RuleHelper::Scripts + [ "redirect_manager" ]
  end

  private
  
  def save_user_rules
    redirect_list = []
    redirects = params[:redirects]
    enabled = params[:enabled]
    filters = params[:filters]
    description = params[:description]
    new_ip = params[:new_ip]
    new_enc_id = params[:new_enc_id]

    position = 0
    unless redirects.nil?
      redirects.each do |key|
        redirect = Redirect.new
        redirect.enabled, redirect.filter, redirect.system_id = enabled[key], filters[key], nil
        redirect.new_ip, redirect.new_enc_id = new_ip[key], new_enc_id[key]
        redirect.description, redirect.position, position = description[key], position, position + 1
        redirect_list << redirect
      end
    end

    ## Delete all of the non-system rules
    Redirect.destroy_all( "system_id IS NULL" )
    redirect_list.each { |redirect| redirect.save }
  end

  def save_system_rules
    rules = params[:system_redirects]
    system_ids = params[:system_system_id]
    enabled = params[:system_enabled]
    
    unless rules.nil?
      rules.each do |key|
        ## Skip anything with an empty or null key.
        next if ApplicationHelper.null?( key )

        redirect = Redirect.find( :first, :conditions => [ "system_id = ?", key ] )
        next if redirect.nil?
        redirect.enabled = enabled[key]
        redirect.save
      end
    end

  end
end
