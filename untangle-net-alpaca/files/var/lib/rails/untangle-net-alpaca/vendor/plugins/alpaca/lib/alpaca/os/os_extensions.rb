module Alpaca::OS::OSExtensions
  def os
    Alpaca::OS.current_os
  end
end

ActionController::Base.send :include, Alpaca::OS::OSExtensions

Alpaca::OS::ManagerBase.send :include, Alpaca::OS::OSExtensions

