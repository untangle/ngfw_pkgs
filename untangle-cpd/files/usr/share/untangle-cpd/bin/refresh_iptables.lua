#!/usr/bin/lua5.1

local http = require( "socket.http" )
local json = require( "json" )
local ltn12 = require( "ltn12" )
local cgilua = {}
cgilua.urlcode = require( "cgilua.urlcode" )

local function run_command( command, args, options)
   args = args or {}
   options = options or {}

   host = options["host"] or "127.0.0.1"
   port = options["port"] or 3005
   path = options["path"] or "/"

   url = "http://" .. host .. ":" .. port .. "/"
   
   command_hash = { ["function"] = command }
   
   for k, v in pairs( args ) do
      if ( v == "true" ) then 
         v = "true" 
      end
   
      command_hash[k] = v
   end

   post = cgilua.urlcode.encodetable( {json_request = json.encode(command_hash)})

   output = {}
   status, return_code = http.request{
      url = url,
      source = ltn12.source.string(post),
      sink = ltn12.sink.table(output),
      method = "POST",

      headers = {
         Accept = "*/*",
         ["Content-Type"] =  "application/x-www-form-urlencoded",
         ["Content-Length"] = #post,
         ["Host"] = host .. ":" .. port
      }
   }
   
   if ( status == nil ) then
      return nil, "error connecting to host."
   end
   
   return json.decode( table.concat( output ))
end

function os.capture_command( cmd, strip_output )
   local f = assert( io.popen( cmd, "r" ))
   local s = assert( f:read("*a"))
   
   f:close()
   if ( not strip_output ) then
      return s
   end

   return string.gsub( string.gsub( s, "^%s+", "" ), "%s+$", "" )
end

local function handle_ipv4_param( type, param )
   local is_client = type == "client_address"
   if ( param == "any" ) then
      return ""
   end

   range_start, range_end = string.match( param, "(%d+%.%d+%.%d+%.%d+)%s*-%s*(%d+%.%d+%.%d+%.%d+)%s*")
   if ( not ( range_start == nil )) then
      is_client = ( is_client ) and "src" or "dst"

      return string.format( " -m iprange --%s-range %s-%s", is_client, range_start, range_end )
   end
   
   is_client = ( is_client ) and "source" or "destination"

   return string.format( " --%s %s", is_client, param )
end

local function handle_intf_param( type, param )
   if ( param < 0 ) then
      return ""
   end

   assert( param < 8, "param must be less then 8" )

   return string.format( " -m mark --mark $((1 << %d ))/$((1 << %d ))", param, param )
end

local day_table = {
   monday = "Mon",
   mon = "Mon",
   m = "Mon",

   tuesday = "Tue",
   tue = "Tue",
   tu = "Tue",

   wednesday = "Wed",
   wed = "Wed",
   w = "Wed",

   thursday = "Thu",
   thur = "Thu",
   thu = "Thu",
   thr = "Thu",
   th = "Thu",

   friday = "Fri",
   fri = "Fri",
   f = "Fri",

   saturday = "Sat",
   sat = "Sat",
   sa = "Sat",

   sunday = "Sun",
   sun = "Sun",
   su = "Sun"
}

local function get_days_param( days )
   if ( days == nil ) then
      return ""
   end

   local day_string, day_set, day, num_days = nil, {}, nil, 0

   for day in string.gmatch( days, "(%a+)%s*,?" ) do
      day = string.lower( day )
      assert( day_table[day], "Invalid day: '" .. day .. "'" )
      day = day_table[day]

      if ( day_set[day] == nil ) then
         day_string = ( day_string == nil ) and day or day_string .. "," .. day
         day_set[day] = true
         num_days = num_days + 1
      end
   end
   
   if ( num_days == 7 ) then
      return ""
   end

   return string.format( " --weekdays %s ", day_string )
end

local function get_time_param( start_time, end_time )
   assert( string.find( start_time, "^%d%d?:%d%d?$" ), "Invalid start time format expecting hh:mm" )
   assert( string.find( end_time, "^%d%d?:%d%d?$" ), "Invalid end time format expecting hh:mm" )
   
   if ( start_time == "00:00" and end_time == "23:59" ) then
      return ""
   end

   return  string.format( " --timestart %s --timestop %s ", start_time, end_time )
end

local function handle_time( rule )
   local days, time = get_days_param( rule["days"] ), get_time_param( rule["start_time"], rule["end_time"] )
   if ( days == "" and time == "" ) then
      return ""
   end
   
   return  " -m time " .. days .. time
end

local function handle_ignore_param( type, param )
   -- This is just a field to indicate whether or not the rule capture or enable values.
   return ""
end
   
local command_handler = {
   client_address = handle_ipv4_param,
   server_address = handle_ipv4_param,
   client_interface = handle_intf_param,
   time = handle_time_param,
   capture = handle_ignore_param,
   enabled = handle_ignore_param,
   start_time = handle_ignore_param,
   end_time = handle_ignore_param,
   days = handle_ignore_param
}

-- @param rule The rule to add.
local function build_rule( rule, target )
   local iptables_command, type, param = "iptables -t mangle -A untangle-cpd "

   if ( not ( rule["enabled"] == true )) then
      return
   end
   
   -- Verify there is at least one parameter.
   assert( not ( next( rule ) == nil ))
   
   for type, param in pairs( rule ) do
      iptables_command = iptables_command .. command_handler[type]( type, param )
   end

   -- Add in the time parameter
   iptables_command = iptables_command .. handle_time( rule )
   
   iptables_command = iptables_command .. "  " .. target
   
   return iptables_command
end

-- Add rules to escape hosts that are in the ipset.
local function add_ipset_rules( commands )
   -- Return any users in the set named ipv4-cpd-authenticated.
   commands[#commands+1] = "ipset -N cpd-ipv4-authenticated iphash"
   commands[#commands+1] = "iptables -t mangle -A untangle-cpd -m set --set cpd-ipv4-authenticated src -j RETURN"
end

-- These are the rules that run if the traffic should be captured.
local function add_capture_rules( commands )
   commands[#commands+1] = "iptables -t mangle -I untangle-cpd-capture 1 -j ULOG --ulog-nlgroup 1 --ulog-cprange 80 --ulog-prefix cpd-block"
   commands[#commands+1] = "iptables -t mangle -A untangle-cpd-capture ! -p tcp -j DROP"
   
   if ( accept_https ) then
      commands[#commands+1] = "iptables -t mangle -A untangle-cpd-capture -p tcp -m multiport ! --destination-ports 80,443 -j RESET"
   else
      commands[#commands+1] = "iptables -t mangle -A untangle-cpd-capture -p tcp -m multiport ! --destination-ports 80 -j DROP"
   end
   commands[#commands+1] = "iptables -t mangle -A untangle-cpd-capture -j MARK --set-mark  0x00100000/0x08100000"
end

-- Insert a rule that should be removed first in case there is one that already exists.
local function replace_rule( commands, table, chain, rule, rule_index, add_rule )
   -- Run it twice for safety.
   commands[#commands+1] = "iptables -t " .. table .. "  -D " .. chain .. " " .. rule .. " > /dev/null 2>&1"
   commands[#commands+1] = "iptables -t " .. table .. "  -D " .. chain .. " " .. rule .. " > /dev/null 2>&1"

   -- Default add_rule to true
   if ( add_rule == nil ) then
      add_rule = true
   end

   rule_index = rule_index or ""
   
   if ( add_rule ) then
      commands[#commands+1] = "iptables -t " .. table .. "  -I " .. chain .. " " .. rule_index .. " " .. rule .. " > /dev/null 2>&1"
   end
end


-- start of script
cpd_home = os.getenv( "CPD_HOME" ) or ""

cpd_config = run_command( "get_config" ) or {}
cpd_config = cpd_config["config"] or {}

capture_rules = cpd_config["capture_rules"] or {}
accept_https = cpd_config["accept_https"]

-- Force is_enabled to be true or false
is_enabled = cpd_config["enabled"]
if ( is_enabled == nil ) then
   is_enabled = false
end

commands = {}

-- these shouldn't be necessary, as they are created in the alpaca.
commands[#commands+1] = "iptables -t mangle -N untangle-cpd > /dev/null 2>&1"
commands[#commands+1] = "iptables -t mangle -F untangle-cpd"
commands[#commands+1] = "iptables -t mangle -N untangle-cpd-capture > /dev/null 2>&1"
commands[#commands+1] = "iptables -t mangle -F untangle-cpd-capture"

-- Return all of the "special" traffic
if ( cpd_config["enabled"] == true ) then
   commands[#commands+1] = "iptables -t mangle -A untangle-cpd -i utun -j RETURN"
   commands[#commands+1] = "iptables -t mangle -A untangle-cpd -i lo -j RETURN"
   
   -- Defaulting capture_bypassed to false.
   if ( not cpd_config["capture_bypassed_traffic"] ) then
      commands[#commands+1] = "iptables -t mangle -A untangle-cpd -m mark --mark 0x1000000/0x1000000 -j RETURN"
   end
   
   commands[#commands+1] = "iptables -t mangle -A untangle-cpd -m pkttype ! --pkt-type UNICAST -j RETURN"

   -- Return all local traffic
   commands[#commands+1] = "iptables -t mangle -A untangle-cpd -m mark --mark 0x100/0x100 -j RETURN"
   commands[#commands+1] = "iptables -t mangle -A untangle-cpd -m state --state ESTABLISHED,RELATED -j RETURN"
   
   -- Update the capture rules.
   add_capture_rules(commands)

   -- Return all of the IP Addresses that are in one of the sets.
   add_ipset_rules(commands)

   for _, rule in ipairs( capture_rules ) do 
      if ( rule["capture"] ) then
         -- Clear the firewall drop mark, and set the captive portal mark.
         commands[#commands +1] = build_rule( rule, "-g untangle-cpd-capture" )
      else
         commands[#commands +1] = build_rule( rule, "-j RETURN" )
      end
   end
end

replace_rule( commands, "nat", "PREROUTING", "-m mark --mark 0x00100000/0x00100000 -p tcp --destination-port 80 -j REDIRECT --to-ports 64158", 1, is_enabled )

replace_rule( commands, "nat", "PREROUTING", "-m mark --mark 0x00100000/0x00100000 -p tcp --destination-port 443 -j REDIRECT --to-ports 64159", 1, is_enabled and accept_https )

table.foreach( commands, function( a, b ) print( b ) ; os.execute( b ) end )
