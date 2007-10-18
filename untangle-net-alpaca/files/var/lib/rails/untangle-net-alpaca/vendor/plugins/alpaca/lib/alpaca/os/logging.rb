module Alpaca::OS::Logging
  ## Used whenever the base logger doesn't load for some reason.
  class FakeLogger
    def method_missing( method_id )
    end
  end
  
  @fakeLogger = FakeLogger.new

  def logger
    ActionController::Base.logger rescue @fakeLogger
  end
end
