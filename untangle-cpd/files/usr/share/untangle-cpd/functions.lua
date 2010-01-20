require "luasql.sqlite3"
require "luasql.postgres"
require "md5"
require "logging"
require "logging.console"

-- This is just for time.
require "socket"
require "untangle"


local function create_table( table_name, statement )
   local query
   local hash = md5.sumhexa(statement)
      
   query = string.format( "SELECT * FROM db_version WHERE table_name='%s' AND version_id='%s'", table_name, hash )

   curs = assert( db:execute( query ))
   is_updated = not( curs:fetch() == nil )
   curs:close()
   if ( is_updated ) then
      logger:info( string.format( "The table '%s' is up to date", table_name ))
      return
   end

   assert( db:execute( string.format( "DROP TABLE IF EXISTS %s;", table_name )))
   assert( db:execute( statement ))

   query = string.format( "DELETE FROM db_version WHERE table_name='%s'", table_name )
   assert( db:execute( query ))
   query= string.format( "INSERT INTO db_version (table_name,version_id) VALUES ('%s', '%s' )", 
                         table_name, hash )                   
   assert( db:execute( query ))
end

local function init_database()
   assert( db:execute([[
                            CREATE TABLE IF NOT EXISTS db_version (
                               table_name TEXT,
                               version_id TEXT
                            );
                      ]]))
   local curs, is_updated
   
   create_table( "host_database", [[
                       CREATE TABLE IF NOT EXISTS host_database (
                          hw_addr TEXT,
                          ipv4_addr TEXT,
                          username TEXT,
                          last_session TIMESTAMP,
                          session_start TIMESTAMP
                       );
                 ]] )
end

cpd_node = nil
postgres = nil

local function uvm_db_execute( query )
   if ( postgres == nil ) then
      postgres = assert( luasql.postgres())
   end

   if ( uvm_db == nil ) then
      uvm_db = assert( postgres:connect("dbname=uvm user=postgres" ))
   end

   return uvm_db:execute( query )
end


local function _run_node_function( function_name, ... )
   if ( remote_uvm_context == nil ) then
      logger:debug( "Need a new UVM context, attempting to create a new instance." )
      remote_uvm_context = untangle.ServiceProxy:new( "localhost", 80, "http://localhost/webui/JSON-RPC", "RemoteUvmContext" )
   end

   if (  cpd_node == nil ) then
      logger:debug( "Need a new cpd instance, attempting to create a new instance." )

      local node_manager, tid, node = remote_uvm_context.nodeManager()
      tid = node_manager.nodeInstances( "untangle-node-cpd" )["list"][1]
      if ( tid == nil ) then
         logger:debug( "CPD Is not installed, cancelling call." )
         return
      end
      
      cpd_node = node_manager.nodeContext( tid ).node()
   end

   -- Run the function.
   return cpd_node[function_name]( ... )
end

local function run_node_function( function_name, ... )
   success, message = pcall( _run_node_function, function_name, ... )
    if ( not success ) then
       logger:debug( string.format( "Error calling cpd.%s [%s], removing context.", function_name, message ))
       -- If the call failed, remove both of the nodes.
       remote_uvm_context = nil
       cpd_node = nil
    end
 end


 -- This creates a new entry into the IPSet.
 -- If Necessary, this will 

 -- XXX This may be better done in one shell script run run with sudo.
 local function add_ipset_entry( hw_addr, ipv4_addr )
    if ( not ( hw_addr == nil )) then
       logger:info( "hw_addr is current not supported and is ignored." )
    end

    -- Insert an entry into the main ipset.
    os.execute( string.format( "ipset -A %s %s", authenticated_ipset, ipv4_addr ))
 end

 local function remove_ipset_entry( ipv4_addr )
 -- Insert an entry into the main ipset.
    os.execute( string.format( "ipset -D %s %s", authenticated_ipset, ipv4_addr ))
 end

 function cpd_replace_host( username, hw_addr, ipv4_addr, update_session_start )
    local query, num_rows, hw_addr_str

    if ( update_session_start == nil ) then
       update_session_start = false
    end

    if ( hw_addr == nil ) then
       hw_addr_str = "NULL"
    else
       hw_addr_str = "'" .. hw_addr .. "'"
    end

    add_ipset_entry( hw_addr, ipv4_addr )

    if ( update_session_start ) then
       query = string.format( "UPDATE host_database SET username='%s', hw_addr=%s, session_start=datetime('now'), last_session=datetime('now') WHERE ipv4_addr='%s'", username, hw_addr_str, ipv4_addr )
    else
       query = string.format( "UPDATE host_database SET username='%s', hw_addr=%s, last_session=datetime('now') WHERE ipv4_addr='%s'", username, hw_addr_str, ipv4_addr )
    end

    num_rows = assert( db:execute( query ))

    if ( num_rows > 1 ) then
       logger:warn( string.format( "Database is corrupt for address '%s' / '%s', clearing entries", ipv4_addr, hw_addr or "empty" ))
       assert( db:execute( string.format( "DELETE FROM host_database WHERE ipv4_adddr='%s'", ipv4_addr )))
    elseif ( num_rows == 1 ) then
       logger:info( string.format( "Updated username (%s) for address '%s' / '%s'", username, ipv4_addr, hw_addr or "empty" ))
       return true
    else
       logger:info( string.format( "Creating new entry for '%s' / '%s'", ipv4_addr, hw_addr or "empty" ))
    end

    query = string.format( "INSERT INTO host_database ( username, ipv4_addr, hw_addr, session_start, last_session ) VALUES ( '%s', '%s', %s, datetime('now'), datetime('now') )",  username, ipv4_addr, hw_addr_str )

    num_rows = assert( db:execute( query ))
    assert( num_rows == 1, "INSERT didn't create a new row." )
    return false
 end

 function cpd_get_ipv4_addr_username( ipv4_addr )
 end

 function cpd_remove_ipv4_addr( ipv4_addr )
    remove_ipset_entry( ipv4_addr )
    return assert( db:execute( string.format( "DELETE FROM host_database WHERE ipv4_addr='%s'", ipv4_addr )))
 end

 function cpd_remove_hw_addr( hw_addr )
    local curs, where_clause
    local row = {}

    if ( hw_addr == nil ) then
       where_clause = "hw_addr IS NULL"
    else
       where_clause = string.format( "hw_addr='%s'", hw_addr )
    end

    curs = assert( db:execute( "SELECT ipv4_addr FROM host_database WHERE " .. where_clause ))

    row = curs:fetch( row,  "n" )
    while row do
       remove_ipset_entry( row[1] )
       row = curs:fetch( row,  "n" )
    end
    curs:close()

    return assert( db:execute( "DELETE FROM host_database WHERE " .. where_clause ))
 end

 function cpd_clear_host_database( )
    logger:info( "Clearing the host database." )
    num_results = assert( db:execute( "DELETE FROM host_database WHERE 1" ))
    os.execute( cpd_home .. "/usr/share/untangle-cpd/bin/sync_ipsets" )
    return num_results
 end

 -- Clear out any hosts that have been around too long.
 function cpd_expire_sessions( sync_ipset )
    local idle_timeout, max_session_length, row = cpd_config.idle_timeout_s, cpd_config.max_session_length_s, {}
    local curs, where_clause

    curs = assert( db:execute( string.format( "SELECT datetime('now', '-%d seconds'), datetime('now', '-%d seconds')",
                                              idle_timeout, max_session_length )))
    row = curs:fetch( row, "n" )
    curs:close()

    where_clause = string.format( "last_session < '%s'", row[1] )
    if ( max_session_length > 0 ) then
       where_clause = where_clause .. string.format( " OR session_start < '%s'", row[2] )
    end

    -- Delete all of the expired sessions.
    num_rows = assert( db:execute( "DELETE FROM host_database WHERE " .. where_clause ))

    if (( num_rows > 0 ) or sync_ipset ) then
       os.execute( cpd_home .. "/usr/share/untangle-cpd/bin/sync_ipsets" )
    end

    return num_rows
 end

 local function init_log_events()
    now_sec, now_nsec = clock_gettime( 1 )

    logger:debug( "Reinitializing log events" )

    return { 
       blocks = { event_count = 0 },
       authorize = { event_count = 0 },
       next_log = ( now_sec + LOG_INTERVAL_SEC )
    }
 end

 local function log_block_events( block_events )
    -- Query for each table
    local query, timestamp = {}

    query[#query+1] = "INSERT INTO n_cpd_block_evt ( event_id, time_stamp, proto, client_intf,  client_address, client_port, server_address, server_port ) VALUES ";

    for _,event in ipairs( block_events ) do
       timestamp = os.date( "%Y-%m-%d %H:%M:%S", event.timestamp )
       -- Strip off the 0.
       timestamp = timestamp .. tostring( event.timestamp % 1 ):sub(2)

       if ( #query > 1 ) then
          query[#query+1] = ","
       end

       query[#query+1] = string.format( "(nextval('hibernate_sequence'), '%s', %d, %d, INET '%s', %d, INET '%s', %d )",
                                        timestamp, event.protocol, event.client_intf,
                                        event.source_address, event.source_port,
                                        event.destination_address, event.destination_port )
    end

    assert( uvm_db_execute( table.concat( query, " " )))
 end

 local function flush_buffer( buffer )
    logger:info( "Log timeout expired, logging events" )

    if ( buffer.blocks.event_count > 0 ) then
       run_node_function( "incrementCount", "BLOCK", buffer.blocks.event_count )
    end

    -- Log all of the bufferd block events
    log_block_events( buffer.blocks.buffer )

    if ( buffer.authorize.event_count > 0 ) then
       run_node_function( "incrementCount", "AUTHORIZE", buffer.authorize.event_count )
    end
 end

 -- Log a packet that was blocked.
 local function cpd_handle_packet_block( prefix, packet )
    local source_address, count, now, buffer = packet.source_address

    log_events.blocks = log_events.blocks or {}

    -- If necessary create a new buffer for this address
    log_events.blocks[source_address] = log_events.blocks[source_address] or 0
    count = log_events.blocks[source_address]

    log_events.blocks.buffer  = log_events.blocks.buffer or {}
    buffer = log_events.blocks.buffer

    if (( count < HOST_LOG_BUFFER_MAX ) and ( #buffer < SYSTEM_LOG_BUFFER_MAX )) then
       packet.timestamp = socket.gettime()
       -- If the buffer isn't full for this host, add the packet to the buffer.
       buffer[#buffer + 1] = packet
    else
       logger:debug( string.format( "Buffer is full for host[%s].", source_address ))
    end

    log_events.blocks[source_address] = log_events.blocks[source_address] + 1

    -- Increment the total number of blocks.
    log_events.blocks.event_count = log_events.blocks.event_count or 0
    log_events.blocks.event_count = log_events.blocks.event_count + 1

    now_sec, now_nsec = clock_gettime( 1 )
    log_events.next_log = log_events.next_log or ( now_sec + LOG_INTERVAL_SEC )
    if ( log_events.next_log < now_sec ) then
       -- Flush all of the buffer data.
       buffer = log_events
       log_events = init_log_events()
       local success, message = pcall( flush_buffer, buffer )
       if ( not success ) then
          logger:warn( string.format( "Error flushing buffer[%s], dropping events, reconnecting to postgres.",
                                      message ))
          uvm_db = nil
      end
   end
end

function cpd_handle_packet( prefix, packet )
   if ( prefix == "cpd-block" ) then
      cpd_handle_packet_block( prefix, packet )
   elseif ( prefix == "cpd-authorized" ) then
      cpd_handle_packet_authorized( prefix, packet )
   end
end

-- Start of initialization
if ( db ) then
   db:close(true)
   db = nil
end

if ( sqlite3 ) then
   sqlite3:close()
   sqlite3 = nil
end


-- Each host gets to log 20 entries per interval.
HOST_LOG_BUFFER_MAX = 20

-- Total system can log 100 entries per interval
SYSTEM_LOG_BUFFER_MAX = 100

-- Log every ten seconds
LOG_INTERVAL_SEC = 10

logger = logging.console()

logger:setLevel(logging.DEBUG)
 
sqlite3 = assert( luasql.sqlite3())

db = assert(sqlite3:connect(cpd_config.sqlite_file))

cpd_home = os.getenv( "CPD_HOME" ) or ""

cpd_node = nil
remote_uvm_context = nil

authenticated_ipset = "cpd-ipv4-authenticated"

if ( not ( log_events  )) then
  log_events = init_log_events()
end

init_database()
