require "luasql.sqlite3"
require "md5"
require "logging"
require "logging.console"

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
                          session_id TEXT,
                          php_session_data TEXT,
                          hw_addr TEXT,
                          ipv4_addr TEXT,
                          username TEXT,
                          last_session TIMESTAMP,
                          session_start TIMESTAMP
                       );
                 ]] )
end


-- This creates a new entry into the IPSet.
-- If Necessary, this will 

-- XXX This may be better done in one shell script run run with sudo.
local function add_ipset_entry( hw_addr, ipv4_addr )
   -- Get the network prefix (this is used to indicate which set to put it in
   local network_prefix = string.match( ipv4_addr, "^%d+%.%d+" )
   local set_name, result

   -- Have to delete the entry from any existing sets.
   if ( hw_addr == nil ) then
      set_name = "basic-" .. network_prefix
      command = [[
            ipset -N %s ipmap --from %s.0.0 --to %s.255.255 || ipset -nL %s | awk 'BEGIN { exit_status=1 };  /References: 0/ { exit_status=0 } ; END { exit exit_status }'
      ]]
      result = os.execute( string.format( command,  set_name, set_name, network_prefix, network_prefix, set_name ))

      if ( result == 0 ) then
         os.execute( cpd_home .. "/usr/share/untangle-cpd/bin/refresh_iptables.lua" )
      end

      -- Just add it, this is faster than testing first.
      os.execute( string.format( "ipset -A %s %s", set_name, ipv4_addr ))

      -- Delete if from the MAC IP MAP in case it is in there.
      os.execute( string.format( "ipset -D hw-addr-%s %s", network_prefix, ipv4_addr ))
   else
      -- Get rid of the single digit characters (ipset does not like)
      hw_addr = hw_addr .. " "
      hw_addr = string.gsub( hw_addr, "(%d%d)", "%1_")
      hw_addr = string.gsub( hw_addr, "(%d[^_%d])", "0%1" )
      hw_addr = string.gsub( hw_addr, "_", "" )
      
      set_name = "hw-addr-" .. network_prefix
      result = os.execute( string.format( "ipset -N %s macipmap --from %s.0.0 --to %s.255.255", set_name, network_prefix, network_prefix))

      if ( result == 0 ) then
         os.execute( cpd_home .. "/usr/share/untangle-cpd/bin/refresh_iptables.lua" )
      end
      
      -- If this is not in the IPSet, add it to the set (have to remove it first, only one MAC per IP)
      if ( not ( os.execute( string.format( "ipset -T %s %s:%s", set_name, ipv4_addr, hw_addr )) == 0 )) then
         os.execute( string.format( "ipset -D %s %s", set_name, ipv4_addr ))
         os.execute( string.format( "ipset -A %s %s:%s", set_name, ipv4_addr, hw_addr ))
      end
      -- Delete if from basic IP Map in case it is in there.
      os.execute( string.format( "ipset -D basic-%s %s", network_prefix, ipv4_addr ))
   end
end

local function remove_ipset_entry( ipv4_addr )
   -- Get the network prefix (this is used to indicate which set to put it in
   local network_prefix = string.match( ipv4_addr, "^%d+%.%d+" )

   logger:info( string.format( "Removing the ip address '%s'", ipv4_addr ))
   
   -- Try to delete from the basic set
   os.execute( string.format( "ipset -D basic-%s %s", network_prefix, ipv4_addr ))
   -- Try to delete from the MAC IP map.
   os.execute( string.format( "ipset -D hw-addr-%s %s", network_prefix, ipv4_addr ))
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

-- Start of initialization
if ( db ) then
   db:close(true)
   db = nil
end

if ( sqlite3 ) then
   sqlite3:close()
   sqlite3 = nil
end

logger = logging.console()

logger:setLevel(logging.DEBUG)
 
sqlite3 = assert( luasql.sqlite3())

db = assert(sqlite3:connect(cpd_config.sqlite_file))

cpd_home = os.getenv( "CPD_HOME" ) or ""

init_database()
