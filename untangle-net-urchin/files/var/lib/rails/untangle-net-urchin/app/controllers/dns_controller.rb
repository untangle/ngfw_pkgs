class DnsController < ApplicationController
  def index
    manage
    render :action => 'manage'
  end

  def manage
    @static_entries = [ 1, 2, 3]
  end

  def stylesheets
    [ "dns/static-entry", "dns/dynamic-entry" ]
  end
end
