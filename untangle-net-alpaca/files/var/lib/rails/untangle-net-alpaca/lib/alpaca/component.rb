class Alpaca::Component
  include Alpaca::OS::OSExtensions  
  include ActionView::Helpers::UrlHelper
  include ERB::Util

  def initialize( controller, params, session, request, name = nil )
    @controller = controller
    @params = params
    @session = session
    @request = request

    if name.nil?
      name = self.class.name.sub( /^.*::(.*)Component/, '\1' ).underscore
      ## This means that the substitution didn't work.
      name = nil unless name.index( "::" ).nil?
    end

    @name = name
  end

  alias :url_helper_url_for :url_for
  
  def url_for( options )
    case options
    when Hash
      ## Automatically append the name of the controller when asked.
      options[:controller] = @name unless options.include?( :controller )
    end

    url_helper_url_for( options )
  end

  def menu_item( priority, name, options )
    Alpaca::Menu::Item.new( priority, name, url_for( options ))
  end

  attr_reader :params, :session, :request, :name
end
