#!/usr/bin/lua5.1

local modname = ...
local M = {}
_G[modname] = M
package.loaded[modname] = M

local http = require( "socket.http" )
local json = require( "json" )
local ltn12 = require( "ltn12" )
local table = require( "table" )

setfenv(1,M)

RequestHandler = {}
function RequestHandler:new()
   local o = { cookies = {}}
   setmetatable(o,self)
   self.__index = self
   return o
end

function RequestHandler:make_request( host, port, url, postdata )
   output = {}
   local cookies, k, v = {}
   for k,v in pairs( self.cookies ) do
      cookies[#cookies +1] = k .. "=" .. v
   end
      
   response, e, headers = http.request{
      url = url,
      source = ltn12.source.string(postdata),
      sink = ltn12.sink.table(output),
      method = "POST",
      redirect = false,

      headers = {
         Accept = "*/*",
         ["Content-Type"] =  "text/plain",
         ["Content-Length"] = #postdata,
         ["Host"] = host .. ":" .. port,
         ["Cookie"] = table.concat( cookies, "; " )
      }
   }
      
   cookies = headers["set-cookie"]
   if ( not ( cookies == nil )) then
      -- Just ignoring the path.
      for k,v in string.gmatch( cookies, "(%w+)=(%w+)") do
         if ( not ( string.lower(k) == "path" )) then
            self.cookies[k] = v
         end
      end
   end
   
   return table.concat( output )
end

-- Shared value that increments for each request.
ServiceProxy = { request_id =  0 }

-- If the value is inside of ServiceProxy use it, otherwise create a new ServiceProxy
-- with the correct parameters.
local function create_remote_method( t, key )
   local v = ServiceProxy[key]

   if ( v == nil ) then
      if ( not ( t.service_name  == nil )) then
         key = t.service_name .. "." .. key
      end
      
      return ServiceProxy:new( t.host, t.port, t.service_url, key, t.handler )
   else
      return v
   end
end

-- Call a method
local function call_remote_method( t, ... )
   return t:r( t.service_name, unpack( arg )) 
end

function ServiceProxy:new( host, port, service_url, service_name, handler )
   handler = handler or RequestHandler:new()
   
   host = host or "localhost" 
   port = port or 80
   service_url = service_url or "http://localhost/webui/JSON-RPC"
   
   o = {
      host = host,
      port = port,
      service_url = service_url,
      service_name = service_name,
      handler = handler
   }

   setmetatable(o,self)
   self.__index = create_remote_method
   self.__call  = call_remote_method

   return o   
end

function ServiceProxy:__tostring()
   return self.service_url .. " : " .. self.service_name
end

function ServiceProxy:r( method_id, ... )
   ServiceProxy.request_id = ServiceProxy.request_id + 1
   postdata = json.encode({
      method = method_id,
      params = arg,
      id = ServiceProxy.request_id
   })

   response_data = self.handler:make_request( self.host, self.port, self.service_url, postdata )
   response = json.decode(response_data)
   error = response["error"]

   if ( not ( error == nil )) then
      assert( false, string.format( "Unable to execute method %s, %s", 
                                    method_id, error["msg"] ))
   end

   result = response["result"]
   if (( type( result ) == "table" ) and ( result['JSONRPCType'] == "CallableReference" )) then
      object_id = result["objectID"]
      assert( not ( object_id  == nil ), "Object ID must not be nil for a callable reference." )
      
      object_id = string.format( ".obj#%s", result["objectID"] )
      
      return ServiceProxy:new( self.host, self.port, self.service_url, object_id, self.handler )
   end

   self.handle_fixups( result, response["fixups"] )

   return result
end

function ServiceProxy:handle_fixups( result, fixups )
   if ( fixups == nil ) then
      return
   end

   if ( not ( type( fixups ) == "table" )) then
      return
   end

   for _,v in ipairs( fixups ) do
      destination = v[1]
      source = v[2]

      original = self.find_object( result, source )
      assert( original, "Fixup is nil" )
      
      -- Remove the final element from the table. [a,b,c] -> [a,b] (c is the value you want to set)
      child = table.remove( destination )

      copy = self.find_object( result, destination )

      assert( copy, "Fixup destination is nil" )
      copy[child] = original
   end
end

function ServiceProxy:find_object( result, path )
   object = base
   
   for _,v in ipairs( path ) do
      object = object[v]
   end

   return object
end

remote_uvm_context = ServiceProxy:new( "localhost", 80, "http://localhost/webui/JSON-RPC", "RemoteUvmContext" )
