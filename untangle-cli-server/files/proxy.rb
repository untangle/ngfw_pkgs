require "drb"

module Proxy
  attr :proxies
  
  ## Register a proxy class, and return whether or not this is a new class for the proxy..
  def register(destination,uri=nil)
    Debug.debug "#{destination}.respond_to?( \"handle\" ) => #{destination.respond_to?( "handle" )}"
    destinationClass = destination.class

    defaults

    ## register the proxy destination with the proxy (therefore the
    ## proxy knows which object to send the method to.
    @proxies[destinationClass] = destination
    Debug.debug "#{destination}.respond_to?( \"handle\" ) => #{destination.respond_to?( "handle" )}"
    
    if ( destination.respond_to?( "handle" ) && destination.kind_of?( DRb::DRbUndumped ))
      @handles[destination.handle] = DRbObject.new( destination, uri )
    end
  end

  ## Remove a class from the proxied objects
  def deregister(clz)
    defaults
    
    proxy = @proxies[clz]
    @proxies[clz] = nil
    @handles[proxy.handle] = nil if ( !proxy.nil? && proxy.respond_to?( "handle" ))
  end
  
  def method_missing(meth,*a, &block)
    ## Nothing to do if there aren't any proxies.
    super if @proxies.nil?
    
    defaults

    ## Find a handle if one exists
    if ( a.empty? && !@handles.nil? )
      handle = @handles[meth.to_s]
      return handle unless handle.nil?
    end
    
    Debug.devel "checking for #{@handles[meth.to_s]} / '#{meth.to_s}'"
    
    ## Find the first proxy that has the method
    @proxies.each do |c,p| 
      ## If the proxy defines handle, then it shouldn't be called directly
      next if p.respond_to?( "handle" )
      return p.send( meth, *a, &block ) if p.respond_to?( meth )
    end

    ## Didn't find a proxy, must call the parent
    super
  end

  def respond_to?(meth)
    ## Check this object first
    return true if super
    
    defaults

    return true unless @handles[meth.to_s].nil?

    @proxies.each { |c,p| return true if p.respond_to?( meth ) }

    return false
  end

  def defaults
    @proxies = {} if @proxies.nil?
    @handles = {} if @handles.nil?
  end
end
