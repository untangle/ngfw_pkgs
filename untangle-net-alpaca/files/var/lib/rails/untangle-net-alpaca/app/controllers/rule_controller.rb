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
