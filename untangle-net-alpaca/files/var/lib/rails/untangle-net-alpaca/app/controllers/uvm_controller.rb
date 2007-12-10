class UvmController < ApplicationController  
  def manage
    @subscriptions = Subscription.find( :all, :conditions => [ "system_id IS NULL" ] )
    @system_subscription_list = Subscription.find( :all, :conditions => [ "system_id IS NOT NULL" ] )

    render :action => 'manage'
  end

  alias :index :manage

  def create_subscription
    ## Reasonable defaults
    @subscription = Subscription.new( :enabled => true, :subscribe => true, 
                                      :position => -1, :description => "" )
  end

  def edit
    @row_id = params[:row_id]
    raise "unspecified row id" if @row_id.nil?
    
    ## This is questionable
    @subscription = Subscription.new
    @subscription.description = params[:description]
    @subscription.subscribe = params[:subscribe]
    @subscription.enabled = params[:enabled]

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

  ## XMLRPC calls.
  def generate_rules
    ## Execute all of the packet filter rules.
    os["packet_filter_manager"].run_services
  end
  
  def commit_rules
    ## Commit all of the packet filter rules.
    os["packet_filter_manager"].commit    
  end

  def stylesheets
    [ "borax/list-table", "borax-subscription", "borax-overlay", "rule" ]
  end

  def scripts
    RuleHelper::Scripts + [ "subscription_manager" ]
  end


  private
  def save_user_rules
    sub_list = []
    subscriptions = params[:subscriptions]
    enabled = params[:enabled]
    subscribe = params[:subscribe]
    filters = params[:filters]
    description = params[:description]

    position = 0
    unless subscriptions.nil?
      subscriptions.each do |key|
        sub = Subscription.new
        sub.system_id = nil
        sub.enabled, sub.filter, sub.subscribe = enabled[key], filters[key], subscribe[key]
        sub.description, sub.position, position = description[key], position, position + 1
        sub_list << sub
      end
    end

    Subscription.destroy_all( "system_id IS NULL" );
    sub_list.each { |sub| sub.save }
  end

  def save_system_rules
    rules = params[:system_subscriptions]
    enabled = params[:system_enabled]
    
    unless rules.nil?
      rules.each do |key|
        ## Skip anything with an empty or null key.
        next if ApplicationHelper.null?( key )

        sub = Subscription.find( :first, :conditions => [ "system_id = ?", key ] )
        next if sub.nil?
        sub.enabled = enabled[key]
        sub.save
      end
    end
  end


end
