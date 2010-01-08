#!/usr/bin/lua

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

   range_start, range_end = string.match( param, "(%d+%.%d+%.%d+%.%d+)%s*-%s*(%d+%.%d+%.%d+%.%d+)%s*")
   if ( not ( range_start == nil )) then
      is_client = ( is_client ) and "src" or "dst"

      return string.format( " -m iprange --%s-range %s-%s", is_client, range_start, range_end )
   end
   
   is_client = ( is_client ) and "source" or "destination"

   return string.format( " --%s %s", is_client, param )
end

local function handle_intf_param( type, param )
   assert( param > 0, "param must be greater then zero" )
   assert( param <= 8, "param must be less then or equal to 8" )

   return string.format( " -m mark --mark $((1 << ( %d - 1 )))/$((1 << ( %d - 1 )))", param, param )
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

local function handle_time_param( type, param )
   local start_time, end_time, days = param["start_time"], param["end_time"], param["days"]
   
   assert( string.find( start_time, "^%d%d?:%d%d?:%d%d?$" ), "Invalid start time format expecting hh:mm:ss" )
   assert( string.find( end_time, "^%d%d?:%d%d?:%d%d?$" ), "Invalid start time format expecting hh:mm:ss" )
   
   if ( days == nil ) then
      return  string.format( " -m time --timestart %s --timestop %s ", start_time, end_time )
   end
   
   local day_string, day_set, day = nil, {}
   
   days = days .. ","
   
   for day in string.gmatch( days, "(%a+)%s*," ) do
      day = string.lower( day )
      assert( day_table[day], "Invalid day: '" .. day .. "'" )
      day = day_table[day]

      if ( day_set[day] == nil ) then
         day_string = ( day_string == nil ) and day or day_string .. "," .. day
         day_set[day] = true
      end
   end

   return  string.format( " -m time --timestart %s --timestop %s --weekdays %s ", start_time, end_time, day_string )
end

local function handle_capture_param( type, param )
   -- This is just a field to indicate whether or not the rule captures traffic or not.
   return ""
end
   
local command_handler = {
   client_address = handle_ipv4_param,
   server_address = handle_ipv4_param,
   interface = handle_intf_param,
   time = handle_time_param,
   capture = handle_capture_param
}

-- @param rule The rule to add.
local function build_rule( rule, target )
   local iptables_command, type, param = "iptables -t mangle -A untangle-cpd "
   
   -- Verify there is at least one parameter.
   assert( not ( next( rule ) == nil ))
   
   for type, param in pairs( rule ) do
      one_param = true
      iptables_command = iptables_command .. command_handler[type]( type, param )
   end
   
   iptables_command = iptables_command .. "  " .. target
   
   return iptables_command
end

-- Add rules to escape hosts that are in the ipsets.
local function add_ipset_rules( commands )
   local output, i = os.capture_command( cpd_home .. "/usr/share/untangle-cpd/bin/get_ipsets nonempty", true )
   
   local base_command = "iptables -t mangle -A untangle-cpd -m set --set %s src -j RETURN"
   for i in string.gmatch( output, "%S+" ) do
      commands[#commands+1] = string.format( base_command, i )
   end
end

-- These are the rules that run if the traffic should be captured.
local function add_capture_rules( commands )
   commands[#commands+1] = "iptables -t mangle -A untangle-cpd-capture ! -p tcp -j DROP"
   
   if ( accept_https ) then
      commands[#commands+1] = "iptables -t mangle -A untangle-cpd-capture -p tcp -m multiport ! --destination-ports 80,443 -j RESET"
   else
      commands[#commands+1] = "iptables -t mangle -A untangle-cpd-capture -p tcp -m multiport ! --destination-ports 80 -j DROP"
   end
   commands[#commands+1] = "iptables -t mangle -A untangle-cpd-capture -j MARK --set-mark  0x00100000/0x08100000"
end


-- start of script
cpd_home = os.getenv( "CPD_HOME" ) or ""

iptables_conf = os.getenv( "CPD_IPTABLES_CONF" ) or "/etc/untangle-cpd/iptables_conf.lua"

dofile( iptables_conf )

capture_rules = cpd_config["capture_rules"] or {}
accept_https = cpd_config["accept_https"]

commands = {}

-- these shouldn't be necessary, as they are created in the alpaca.
commands[#commands+1] = "iptables -t mangle -N untangle-cpd > /dev/null 2>&1"
commands[#commands+1] = "iptables -t mangle -F untangle-cpd"
commands[#commands+1] = "iptables -t mangle -N untangle-cpd-capture > /dev/null 2>&1"
commands[#commands+1] = "iptables -t mangle -F untangle-cpd-capture"

-- Return all of the "special" traffic
commands[#commands+1] = "iptables -t mangle -A untangle-cpd -i utun -j RETURN"
commands[#commands+1] = "iptables -t mangle -A untangle-cpd -i lo -j RETURN"
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

-- This won't be necessary once this is tied into running the other iptables rules.
commands[#commands+1] = "iptables -t nat -D PREROUTING -m mark --mark 0x00100000/0x00100000 -p tcp --destination-port 80 -j REDIRECT --to-ports 64158"
commands[#commands+1] = "iptables -t nat -I PREROUTING 1 -m mark --mark 0x00100000/0x00100000 -p tcp --destination-port 80 -j REDIRECT --to-ports 64158"

if ( accept_https ) then
   commands[#commands+1] = "iptables -t nat -D PREROUTING -m mark --mark 0x00100000/0x00100000 -p tcp --destination-port 443 -j REDIRECT --to-ports 64159"
   commands[#commands+1] = "iptables -t nat -I PREROUTING -m mark --mark 0x00100000/0x00100000 -p tcp --destination-port 443 -j REDIRECT --to-ports 64159"
end

table.foreach( commands, function( a, b ) os.execute( b ) end )
