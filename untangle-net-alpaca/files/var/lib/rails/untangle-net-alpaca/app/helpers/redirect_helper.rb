module RedirectHelper
  def self.is_local( ip )
    return ( ip == "localhost" || ip == "127.0.0.1" )
  end
end
