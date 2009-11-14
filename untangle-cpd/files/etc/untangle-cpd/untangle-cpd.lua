require "luasql.sqlite3"
require "md5"

local function create_table( table_name, statement )
   local query
   local hash = md5.sumhexa(statement)
      
   query = string.format( "SELECT * FROM db_version WHERE table_name='%s' AND version_id='%s'", table_name, hash )

   curs = assert( db:execute( query ))
   is_updated = not( curs:fetch() == nil )
   curs:close()
   if ( is_updated ) then
      print( string.format( "The table '%s' is up to date", table_name ))
      return
   end

   assert( db:execute( string.format( "DROP TABLE IF EXISTS %s;", table_name )))
   assert( db:execute( statement ))

   query = string.format( "INSERT INTO db_version (table_name,version_id) VALUES ('%s', '%s' );", table_name, hash )
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
                       CREATE TABLE  IF NOT EXISTS host_database (
                          hw_addr TEXT,
                          ipv4_addr TEXT,
                          username TEXT,
                          last_session TIMESTAMP,
                          session_start_time TIMESTAMP
                       );
                 ]] )
end

function cpd_replace_host( username, hw_addr, ipv4_addr, update_session_start )
   local query, num_rows, hw_addr_str

   update_session_start = update_session_start or false
   
   if ( hw_addr == nil ) then
      hw_addr_str = "NULL"
   else
      hw_addr_str = "'" .. hw_addr .. "'"
   end

   if ( update_session_start ) then
      query = string.format( "UPDATE host_database SET username='%s', hw_addr=%s, session_start_time=datetime('now'), last_session=datetime('now') WHERE ipv4_addr='%s'", username, hw_addr_str, ipv4_addr )
   else
      query = string.format( "UPDATE host_database SET username='%s', hw_addr=%s, last_session=datetime('now') WHERE ipv4_addr='%s'", username, hw_addr_str, ipv4_addr )
   end
   
   num_rows = assert( db:execute( query ))
   
   if ( num_rows > 1 ) then
      print( string.format( "Database is corrupt for address '%s' / '%s', clearing entries", ipv4_addr, hw_addr or "empty" ))
      assert( db:execute( string.format( "DELETE FROM host_database WHERE ipv4_adddr='%s'", ipv4_addr )))
   elseif ( num_rows == 1 ) then
      print( string.format( "Updated username (%s) for address '%s' / '%s'", username, ipv4_addr, hw_addr or "empty" ))
      return true
   else
      print( string.format( "Creating new entry for '%s' / '%s'", ipv4_addr, hw_addr or "empty" ))
   end
   
   query = string.format( "INSERT INTO host_database ( username, ipv4_addr, hw_addr, session_start_time, last_session ) VALUES ( '%s', '%s', %s, datetime('now'), datetime('now') )",  username, ipv4_addr, hw_addr_str )
   
   num_rows = assert( db:execute( query ))
   assert( num_rows == 1, "INSERT didn't create a new row." )
   return false
end

function cpd_get_ipv4_addr_username( ipv4_addr )
end

function cpd_remove_ipv4_addr( ipv4_addr )
   return assert( db:execute( string.format( "DELETE FROM host_database WHERE ipv4_addr='%s'", ipv4_addr )))
end

function cpd_remove_hw_addr( hw_addr )
   if ( hw_addr == nil ) then
      return assert( db:execute( "DELETE FROM host_database WHERE hw_addr IS NULL" ))
   else
      return assert( db:execute( string.format( "DELETE FROM host_database WHERE hw_addr='%s'",
                                                hw_addr )))
   end
end

function cpd_clear_host_database( )
   return assert( db:execute( "DELETE FROM host_database WHERE 1" ))
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
 
sqlite3 = assert( luasql.sqlite3())

db = assert(sqlite3:connect(cpd_config.sqlite_file))

init_database()
