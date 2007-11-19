class RedirectController < ApplicationController  
  def manage
    @redirects = Redirect.find( :all )

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
    
    ## This is questionable
    @redirect = Redirect.new
    @redirect.description = params[:description]
    @redirect.new_ip = params[:new_ip]
    @redirect.new_enc_id = params[:new_enc_id]

    @interfaces, @parameter_list = RuleHelper::get_edit_fields( params )
  end

  def save
    ## Review : Internationalization
    if ( params[:commit] != "Save Changes".t )
      redirect_to( :action => "manage" ) 
      return false
    end

    sub_list = []
    redirects = params[:redirects]
    enabled = params[:enabled]
    filters = params[:filters]
    description = params[:description]
    new_ip = params[:new_ip]
    new_enc_id = params[:new_enc_id]

    logger.debug( "Read out the redirect: #{redirects.join}" )

    position = 0
    unless redirects.nil?
      redirects.each do |key|
        sub = Redirect.new
        sub.enabled, sub.filter = enabled[key], filters[key]
        sub.new_ip, sub.new_enc_id = new_ip[key], new_enc_id[key]
        sub.description, sub.position, position = description[key], position, position + 1
        sub_list << sub
      end
    end

    Redirect.destroy_all
    sub_list.each { |sub| sub.save }

    ## Review : should have some indication that is saved.
    redirect_to( :action => "manage" )
  end

  def stylesheets
    [ "borax/list-table", "borax-redirect", "borax-overlay", "rule" ]
  end

  def scripts
    RuleHelper::Scripts + [ "redirect_manager" ]
  end
end
