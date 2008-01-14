class IntfPppoe < ActiveRecord::Base
  HiddenPassword = "        "
  def accept( interface, visitor )
    visitor.intf_pppoe( interface, self )
  end

  def password=( pass )
    if ( pass != IntfPppoe::HiddenPassword )
      write_attribute( :password, pass )
    else
      logger.debug( "Ignoring password set to HiddenPassword" )
    end
  end

  def hidden_password
    pass = read_attribute( :password )
    if pass.nil? || pass.length == 0
      return ""
    end
    return IntfPppoe::HiddenPassword
  end

end
