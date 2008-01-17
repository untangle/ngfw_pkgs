class ActiveRoute
  attr_accessor( :target, :netmask, :description, :interface )
  def gateway
    if @gateway == "0.0.0.0"
      return "&nbsp;"
    end
    return @gateway
  end

  def gateway=( gateway )
    @gateway = gateway
  end

end
