class DhcpController < ApplicationController
  def index
    manage
    render :action => 'manage'
  end

  def manage
    @static_entries = [ 1, 2, 3]
  end

  def stylesheets
    [ "dhcp/static-entry", "dhcp/dynamic-entry" ]
  end
end
