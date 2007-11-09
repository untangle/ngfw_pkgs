class Alpaca::Component
  include Alpaca::OS::OSExtensions  

  def initialize( params, session, request )
    @params = params
    @session = session
    @request = request
  end

  attr_reader :params, :session, :request
end
