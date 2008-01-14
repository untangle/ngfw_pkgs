class DdclientSettings < ActiveRecord::Base
  HiddenPassword = "        "

  def password=( pass )
    if ( pass != DdclientSettings::HiddenPassword )
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
    return DdclientSettings::HiddenPassword
  end
end
