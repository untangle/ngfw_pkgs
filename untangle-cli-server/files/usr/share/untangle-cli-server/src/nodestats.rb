
class NodeStats
  
   attr :tcpSessionCount 
   attr :tcpSessionTotal 
   attr :tcpSessionRequestTotal 
   attr :udpSessionCount 
   attr :udpSessionTotal 
   attr :udpSessionRequestTotal 
   attr :c2tBytes 
   attr :c2tChunks 
   attr :t2sBytes 
   attr :t2sChunks 
   attr :s2tBytes 
   attr :s2tChunks 
   attr :t2cBytes 
   attr :t2cChunks 
   attr :startDate 
   attr :lastConfigureDate 
   attr :lastActivityDate
  
  def initialize(new_stats, snmp_stat_map)

    @tcpSessionCount = 0;
    @tcpSessionTotal = 0;
    @tcpSessionRequestTotal = 0;
    @udpSessionCount = 0;
    @udpSessionTotal = 0;
    @udpSessionRequestTotal = 0;
    @c2tBytes = 0;
    @c2tChunks = 0;
    @t2sBytes = 0;
    @t2sChunks = 0;
    @s2tBytes = 0;
    @s2tChunks = 0;
    @t2cBytes = 0;
    @t2cChunks = 0;
    @startDate = @lastConfigureDate = @lastActivityDate = Time.now();

    @counters = Array.new(16, 0);
    
    metrics = new_stats.getMetrics();

    # These may not exist, for transforms that are off or have no MPipe
    # metric = metrics.get("tcpLiveSessionCounter");
    # @tcpSessionCount = metric.nil? ? 0 : metric.getCount();
    metric = metrics.get("tcpTotalSessionCounter");
    @tcpSessionTotal = metric.nil? ? 0 : metric.getCount();
    metric = metrics.get("tcpTotalSessionRequestCounter");
    @tcpSessionRequestTotal = metric.nil? ? 0 : metric.getCount();
    # metric = metrics.get("udpLiveSessionCounter");
    # @udpSessionCount = metric.nil? ? 0 : metric.getCount();
    metric = metrics.get("udpTotalSessionCounter");
    @udpSessionTotal = metric.nil? ? 0 : metric.getCount();
    metric = metrics.get("udpTotalSessionRequestCounter");
    @udpSessionRequestTotal = metric.nil? ? 0 : metric.getCount();

    # These always exist.
    @c2tBytes = metrics.get("c2nBytes").getCount();
    @c2tChunks = metrics.get("c2nChunks").getCount();
    @t2sBytes = metrics.get("n2sBytes").getCount();
    @t2sChunks = metrics.get("n2sChunks").getCount();
    @s2tBytes = metrics.get("s2nBytes").getCount();
    @s2tChunks = metrics.get("s2nChunks").getCount();
    @t2cBytes = metrics.get("n2cBytes").getCount();
    @t2cChunks = metrics.get("n2cChunks").getCount();
    #keys = metrics.keySet();
    #keys.each() {|k| puts k };
    #metrics.values().each() {|v| puts v.getCount() };
    
    real_last_activity_date = false;
    (7..11).each do |i|
      if !snmp_stat_map[i].nil?
      	metric = metrics.get(snmp_stat_map[i]);
	# Bug 4504 -- count index is zero based, not one based
      	@counters[i - 1] = metric.getCount() 
        # set last activity date to be the most RECENT date for any stat monitored for this node.
	if !real_last_activity_date
	  @lastActivityDate = metric.getLastActivityDate();
	  real_last_activity_date = true;
	elsif @lastActivityDate.compareTo(metric.getLastActivityDate()) < 0
	  @lastActivityDate = metric.getLastActivityDate();
	end
      end
    end
    
  end
    
  def getCount(i)
    @counters[i];
  end

end
