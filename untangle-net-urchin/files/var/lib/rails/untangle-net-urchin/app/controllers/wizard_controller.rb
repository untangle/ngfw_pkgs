class WizardController < ApplicationController
  WizardPages = [ "welcome", "interface-test", "interface[]", "review" ].freeze

  def index
    @title = "Setup Wizard"

    @interfaces = networkManager.interfaces
  end

  def networkManager
    ## REVIEW DebianSarge is hardcoded, need to move this out.
    OSLibrary.getOS( "DebianSarge" ).manager( "network_manager" )
  end

  ## This is the navigational form
  def nav
    direction, current, interface_count = params[:direction], params[:current], params[:interface_count]
    
    raise "empty parameter" if direction.nil? || current.nil? || interface_count.nil?

    interface_count = interface_count.to_i
    raise "invalid count" if interface_count == 0

    current = current.sub( /^sl-/, "" )
    
    raise "invalid direction" unless ( direction == "prev" || direction == "next" )
    
    ## This is the case where it is not of the interface configuration panels
    pages = expandPages( interface_count )
    index = pages.index( current )
    raise "Current page '#{current}' is not valid" if index.nil?
    
    case direction
    when "prev" then index -= 1
    when "next" then index += 1
    end
    
    raise "At the first page" if index < 0
    raise "At the final page" if index >= pages.size

    @current = pages[index]
  end

  private
  
  def expandPages( interface_count )
    WizardPages.collect do |p| 
      next p if /\[\]$/.match( p ).nil?
      interfaces = []
      interface_count.times { |n| interfaces << "interface[#{n}]" }
      interfaces
    end.flatten
  end
end
