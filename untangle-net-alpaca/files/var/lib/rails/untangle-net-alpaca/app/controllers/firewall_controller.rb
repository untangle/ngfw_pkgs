class FirewallController < ApplicationController  
  def manage
    @firewalls = Firewall.find( :all )
    @actions = FirewallHelper::Actions.map { |o| [ o[0].t, o[1] ] }

    render :action => 'manage'
  end

  alias :index :manage

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
    if ( params[:commit] != "Save Changes".t )
      redirect_to( :action => "manage" )
      return false
    end

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
        fw.enabled, fw.filter, fw.target = enabled[key], filters[key], target[key]
        fw.description, fw.position, position = description[key], position, position + 1
        fw_list << fw
      end
    end

    Firewall.destroy_all
    fw_list.each { |fw| fw.save }

    ## Review : should have some indication that is saved.
    redirect_to( :action => "manage" )
  end

  def stylesheets
    [ "borax/list-table", "borax-firewall", "borax-overlay", "rule" ]
  end

  def scripts
    RuleHelper::Scripts + [ "firewall_manager" ]
  end
end
