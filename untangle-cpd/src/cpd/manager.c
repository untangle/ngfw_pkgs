/*
 * Copyright (c) 2003-2008 Untangle, Inc.
 * All rights reserved.
 *
 * This software is the confidential and proprietary information of
 * Untangle, Inc. ("Confidential Information"). You shall
 * not disclose such Confidential Information.
 *
 * $Id$
 */

#include <pthread.h>

#include <stdlib.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <unistd.h>

#include <lua5.1/lua.h>
#include <lua5.1/lauxlib.h>
#include <lua5.1/lualib.h>

#include <net/if.h>

#include <mvutil/debug.h>
#include <mvutil/errlog.h>
#include <mvutil/unet.h>
#include <mvutil/utime.h>

#include "cpd.h"
#include "cpd/manager.h"
#include "status.h"

#define _MAX_SHUTDOWN_TIMEOUT     10

/* This is the file that should contain the routing table */
#define _ROUTE_FILE              "/proc/net/route"
/* For simplicity the route table is divided into 128 byte chunks */
#define _ROUTE_READ_SIZE         0x80

static struct
{
    int init;

    pthread_mutex_t mutex;
    
    pthread_t cleanup_thread;
    pthread_t log_thread;

    cpd_config_t config;
    
    lua_State *lua_state;

    char* lua_script;
    char* sqlite_file;
    time_t script_mtime;

    /* The next time wake up to cleanup expired hosts. */
    struct timespec next_update;
} _globals = {
    .init = 0,
    .cleanup_thread = 0,
    .log_thread = 0,
    .lua_script = NULL,
    .script_mtime = 0,
    .mutex = PTHREAD_RECURSIVE_MUTEX_INITIALIZER_NP,
};

static int _update_lua_script( void );
static int _update_lua_config( cpd_config_t* config, char* sqlite_file );
static char* _ether_ntoa_r(const struct ether_addr *addr, char* buffer, int buffer_len );
static int _lua_clock_gettime( lua_State *L );

static int _start_cleanup_thread( void );
static int _stop_cleanup_thread( void );
static void* _cleanup_thread( void* arg );


static int _start_log_thread( void );
static int _stop_log_thread( void );
static void* _log_thread( void* arg );


static void _push_ip_header( u_int nfmark, struct iphdr* ip_header );

int cpd_manager_init( cpd_config_t* config, char* sqlite_file, char* lua_script )
{
    if ( _globals.init != 0 ) {
        return errlog( ERR_CRITICAL, "cpd_manager_init was called twice.\n" );
    }

    if ( config == NULL ) {
        return errlogargs();
    }

    /* Create an instance of lua */
    if (( _globals.lua_state = luaL_newstate()) == NULL ) {
        return errlog( ERR_CRITICAL, "luaL_newstate\n" );
    }

    if (( _globals.lua_script = strndup( lua_script, FILENAME_MAX )) == NULL ) {
        return errlog( ERR_CRITICAL, "strndup\n" );
    }

    if (( _globals.sqlite_file = strndup( sqlite_file, FILENAME_MAX )) == NULL ) {
        return errlog( ERR_CRITICAL, "strndup\n" );
    }
    
    luaL_openlibs( _globals.lua_state );
    
    lua_register( _globals.lua_state, "clock_gettime", _lua_clock_gettime );

    if ( cpd_manager_set_config( config ) < 0 ) {
        return errlog( ERR_CRITICAL, "cpd_manager_set_config\n" );
    }

    if ( _update_lua_script() < 0 ) {
        return errlog( ERR_CRITICAL, "_update_lua_script\n" );
    }

    if ( _start_cleanup_thread() < 0 ) {
        return errlog( ERR_CRITICAL, "start_cleanup_thread\n" );
    }

    if ( _start_log_thread() < 0 ) {
        return errlog( ERR_CRITICAL, "start_log_thread\n" );
    }

    _globals.init = 1;
    
    clock_gettime( CLOCK_MONOTONIC, &_globals.next_update );

    return 0;
}

void cpd_manager_destroy( void )
{
    _stop_cleanup_thread();

    _stop_log_thread();

    if ( _globals.lua_state != NULL ) {
        lua_close(_globals.lua_state);
    }
    _globals.lua_state = NULL;
    
    if ( _globals.lua_script != NULL ) {
        free( _globals.lua_script );
    }
    _globals.lua_script = NULL;

    if ( _globals.sqlite_file != NULL ) {
        free( _globals.sqlite_file );
    }
    _globals.sqlite_file = NULL;

    _globals.init = -1;
}

/**
 * Copies in the config to the global config
 */
int cpd_manager_set_config( cpd_config_t* config )
{
    if ( config == NULL ) {
        return errlogargs();
    }
    
    int _critical_section() {
        debug( 9, "Loading new config\n" );
                
        memcpy( &_globals.config, config, sizeof( _globals.config ));

        if ( _update_lua_config( config, _globals.sqlite_file ) < 0 ) {
            return errlog( ERR_CRITICAL, "_update_lua_config\n" );
        }
        
        return 0;
    }

    if ( pthread_mutex_lock( &_globals.mutex ) != 0 ) return perrlog( "pthread_mutex_lock" );
    int ret = _critical_section();
    if ( pthread_mutex_unlock( &_globals.mutex ) != 0 ) return perrlog( "pthread_mutex_unlock" );
    
    if ( ret < 0 ) return errlog( ERR_CRITICAL, "_critical_section\n" );
    
    return 0;
}

/**
 * Gets the config
 */
int cpd_manager_get_config( cpd_config_t* config )
{
    if ( config == NULL ) return errlogargs();
    
    int _critical_section() {
        debug( 9, "Copying out config\n" );
        memcpy( config, &_globals.config, sizeof( _globals.config ));
        return 0;
    }

    if ( pthread_mutex_lock( &_globals.mutex ) != 0 ) return perrlog( "pthread_mutex_lock" );
    int ret = _critical_section();
    if ( pthread_mutex_unlock( &_globals.mutex ) != 0 ) return perrlog( "pthread_mutex_unlock" );
    
    if ( ret < 0 ) return errlog( ERR_CRITICAL, "_critical_section\n" );
    
    return 0;
}

/**
 * Retrieve the status of the CPD daemon
 */
int cpd_manager_get_status( cpd_status_t* status )
{
    if ( status == NULL ) {
        return errlogargs();
    }

    int _critical_section()
    {
        return errlog( ERR_WARNING, "Implement me\n" );
    }

    if ( pthread_mutex_lock( &_globals.mutex ) != 0 ) return perrlog( "pthread_mutex_lock" );
    int ret = _critical_section();
    if ( pthread_mutex_unlock( &_globals.mutex ) != 0 ) return perrlog( "pthread_mutex_unlock" );

    if ( ret < 0 ) return errlog( ERR_CRITICAL, "_critical_section\n" );

    return 0;
}

/**
 * Replace a Host / MAC Address
 */
int cpd_manager_replace_host( cpd_host_database_username_t* username, 
                              struct ether_addr* hw_addr, struct in_addr* ipv4_addr,
                              int update_session_start )
{
    if ( username == NULL ) {
        return errlogargs();
    }
    
    if ( ipv4_addr == NULL ) {
        return errlogargs();
    }

    int _critical_section()
    {
        char hw_addr_str[24];
        hw_addr_str[0] = '\0';

        /* If necessary reload the lua script */
        if ( _update_lua_script() < 0 ) {
            return errlog( ERR_CRITICAL, "_update_lua_script\n" );
        }

        lua_getglobal( _globals.lua_state, "cpd_replace_host" );
        if ( !lua_isfunction( _globals.lua_state, -1 )) {
            lua_pop( _globals.lua_state, 1 );
            return errlog( ERR_CRITICAL, "cpd_replace_host is not a function.\n" );
        }
        lua_pushstring( _globals.lua_state, username->u );
        if ( hw_addr == NULL ) {
            lua_pushnil( _globals.lua_state );
        } else {
            _ether_ntoa_r( hw_addr, hw_addr_str, sizeof( hw_addr_str ));
            lua_pushstring( _globals.lua_state, hw_addr_str );
        }
        lua_pushstring( _globals.lua_state, unet_next_inet_ntoa( ipv4_addr->s_addr ));
        lua_pushboolean( _globals.lua_state, update_session_start );

        if ( lua_pcall( _globals.lua_state, 4, 1, 0 ) != 0 ) {
            return errlog( ERR_CRITICAL, "lua_pcall %s\n", lua_tostring( _globals.lua_state, -1 ));
        }

        if ( !lua_isboolean( _globals.lua_state, -1 )) {
            lua_pop( _globals.lua_state, 1 );
            return errlog( ERR_CRITICAL, "cpd_replace_host did not return a boolean\n" );
        }
        
        int success = lua_toboolean( _globals.lua_state, -1 );
        lua_pop( _globals.lua_state, -1 );
        return success;
    }

    if ( pthread_mutex_lock( &_globals.mutex ) != 0 ) return perrlog( "pthread_mutex_lock" );
    int ret = _critical_section();
    if ( pthread_mutex_unlock( &_globals.mutex ) != 0 ) return perrlog( "pthread_mutex_unlock" );

    if ( ret < 0 ) return errlog( ERR_CRITICAL, "_critical_section\n" );

    return ret;
}

/**
 * Remove IPv4 host.
 * Returns the number of entries that were removed (one or zero)
 */
int cpd_manager_remove_ipv4_addr( struct in_addr* ipv4_addr )
{
    if ( ipv4_addr == NULL ) {
        return errlogargs();
    }

    int _critical_section()
    {
        /* If necessary reload the lua script */
        if ( _update_lua_script() < 0 ) {
            return errlog( ERR_CRITICAL, "_update_lua_script\n" );
        }

        lua_getglobal( _globals.lua_state, "cpd_remove_ipv4_addr" );
        if ( !lua_isfunction( _globals.lua_state, -1 )) {
            lua_pop( _globals.lua_state, 1 );
            return errlog( ERR_CRITICAL, "cpd_remove_ipv4_addr is not a function.\n" );
        }
        lua_pushstring( _globals.lua_state, unet_next_inet_ntoa( ipv4_addr->s_addr ));
        if ( lua_pcall( _globals.lua_state, 1, 1, 0 ) != 0 ) {
            return errlog( ERR_CRITICAL, "lua_pcall %s\n", lua_tostring( _globals.lua_state, -1 ));
        }

        if ( !lua_isnumber( _globals.lua_state, -1 )) {
            lua_pop( _globals.lua_state, 1 );
            return errlog( ERR_CRITICAL, "cpd_remove_ipv4_addr did not return a number\n" );
        }
        
        int num_entries = lua_tointeger( _globals.lua_state, -1 );
        lua_pop( _globals.lua_state, -1 );
        return num_entries;
    }

    if ( pthread_mutex_lock( &_globals.mutex ) != 0 ) return perrlog( "pthread_mutex_lock" );
    int ret = _critical_section();
    if ( pthread_mutex_unlock( &_globals.mutex ) != 0 ) return perrlog( "pthread_mutex_unlock" );

    if ( ret < 0 ) return errlog( ERR_CRITICAL, "_critical_section\n" );

    return ret;
}


/**
 * Remove Hardware Address (will remove all corresponding IPv4 if it exists)
 * @param hw_addr The hardware address to remove.  If this is NULL, this remove will all
 *                of the entries that don't have a MAC Address.
 * Returns the number of entries that were removed.
 */
int cpd_manager_remove_hw_addr( struct ether_addr* hw_addr )
{    
    int _critical_section()
    {
        char hw_addr_str[24];
        hw_addr_str[0] = '\0';

        /* If necessary reload the lua script */
        if ( _update_lua_script() < 0 ) {
            return errlog( ERR_CRITICAL, "_update_lua_script\n" );
        }

        lua_getglobal( _globals.lua_state, "cpd_remove_hw_addr" );
        if ( !lua_isfunction( _globals.lua_state, -1 )) {
            lua_pop( _globals.lua_state, 1 );
            return errlog( ERR_CRITICAL, "cpd_remove_hw_addr is not a function.\n" );
        }
        
        if ( hw_addr == NULL ) {
            lua_pushnil(_globals.lua_state);
        } else {
            _ether_ntoa_r( hw_addr, hw_addr_str, sizeof( hw_addr_str ));
            lua_pushstring( _globals.lua_state, hw_addr_str );
        }
        
        if ( lua_pcall( _globals.lua_state, 1, 1, 0 ) != 0 ) {
            return errlog( ERR_CRITICAL, "lua_pcall %s\n", lua_tostring( _globals.lua_state, -1 ));
        }

        if ( !lua_isnumber( _globals.lua_state, -1 )) {
            lua_pop( _globals.lua_state, 1 );
            return errlog( ERR_CRITICAL, "cpd_remove_hw_addr did not return a number\n" );
        }
        
        int num_entries = lua_tointeger( _globals.lua_state, -1 );
        lua_pop( _globals.lua_state, -1 );
        return num_entries;
    }

    if ( pthread_mutex_lock( &_globals.mutex ) != 0 ) return perrlog( "pthread_mutex_lock" );
    int ret = _critical_section();
    if ( pthread_mutex_unlock( &_globals.mutex ) != 0 ) return perrlog( "pthread_mutex_unlock" );

    if ( ret < 0 ) return errlog( ERR_CRITICAL, "_critical_section\n" );

    return ret;
}

int cpd_manager_handle_tcp_packet( char* prefix, u_int nfmark, 
                                   struct iphdr* ip_header, struct tcphdr* tcp_header )
{
    if ( prefix == NULL ) {
        return errlogargs();
    }
    
    if ( ip_header == NULL ) {
        return errlogargs();
    }

    if ( tcp_header == NULL ) {
        return errlogargs();
    }

    int _critical_section()
    {
        /* If necessary reload the lua script */
        if ( _update_lua_script() < 0 ) {
            return errlog( ERR_CRITICAL, "_update_lua_script\n" );
        }

        lua_getglobal( _globals.lua_state, "cpd_handle_packet" );
        if ( !lua_isfunction( _globals.lua_state, -1 )) {
            lua_pop( _globals.lua_state, 1 );
            return errlog( ERR_CRITICAL, "cpd_handle_packet is not a function.\n" );
        }
        
        lua_pushstring( _globals.lua_state, prefix );

        lua_newtable( _globals.lua_state );
        _push_ip_header( nfmark, ip_header );
        
        lua_pushnumber( _globals.lua_state, ntohs( tcp_header->source ));
        lua_setfield( _globals.lua_state, -2, "source_port" );

        lua_pushnumber( _globals.lua_state, ntohs( tcp_header->dest ));
        lua_setfield( _globals.lua_state, -2, "destination_port" );
        
        if ( lua_pcall( _globals.lua_state, 2, 0, 0 ) != 0 ) {
            return errlog( ERR_CRITICAL, "lua_pcall %s\n", lua_tostring( _globals.lua_state, -1 ));
        }

        return 0;
    }

    if ( pthread_mutex_lock( &_globals.mutex ) != 0 ) return perrlog( "pthread_mutex_lock" );
    int ret = _critical_section();
    if ( pthread_mutex_unlock( &_globals.mutex ) != 0 ) return perrlog( "pthread_mutex_unlock" );

    if ( ret < 0 ) return errlog( ERR_CRITICAL, "_critical_section\n" );

    return ret;
}

int cpd_manager_handle_udp_packet( char* prefix, u_int nfmark, 
                                   struct iphdr* ip_header, struct udphdr* udp_header )
{
    if ( prefix == NULL ) {
        return errlogargs();
    }
    
    if ( ip_header == NULL ) {
        return errlogargs();
    }

    if ( udp_header == NULL ) {
        return errlogargs();
    }

    int _critical_section()
    {
        /* If necessary reload the lua script */
        if ( _update_lua_script() < 0 ) {
            return errlog( ERR_CRITICAL, "_update_lua_script\n" );
        }

        lua_getglobal( _globals.lua_state, "cpd_handle_packet" );
        if ( !lua_isfunction( _globals.lua_state, -1 )) {
            lua_pop( _globals.lua_state, 1 );
            return errlog( ERR_CRITICAL, "cpd_handle_packet is not a function.\n" );
        }
        
        lua_pushstring( _globals.lua_state, prefix );

        lua_newtable( _globals.lua_state );
        _push_ip_header( nfmark, ip_header );
        
        lua_pushnumber( _globals.lua_state, ntohs( udp_header->source ));
        lua_setfield( _globals.lua_state, -2, "source_port" );

        lua_pushnumber( _globals.lua_state, ntohs( udp_header->dest ));
        lua_setfield( _globals.lua_state, -2, "destination_port" );
        
        if ( lua_pcall( _globals.lua_state, 2, 0, 0 ) != 0 ) {
            return errlog( ERR_CRITICAL, "lua_pcall %s\n", lua_tostring( _globals.lua_state, -1 ));
        }

        return 0;
    }

    if ( pthread_mutex_lock( &_globals.mutex ) != 0 ) return perrlog( "pthread_mutex_lock" );
    int ret = _critical_section();
    if ( pthread_mutex_unlock( &_globals.mutex ) != 0 ) return perrlog( "pthread_mutex_unlock" );

    if ( ret < 0 ) return errlog( ERR_CRITICAL, "_critical_section\n" );

    return ret;
}

int cpd_manager_handle_ip_packet( char* prefix, u_int nfmark, 
                                  struct iphdr* ip_header )
{
    if ( prefix == NULL ) {
        return errlogargs();
    }
    
    if ( ip_header == NULL ) {
        return errlogargs();
    }

    int _critical_section()
    {
        /* If necessary reload the lua script */
        if ( _update_lua_script() < 0 ) {
            return errlog( ERR_CRITICAL, "_update_lua_script\n" );
        }

        lua_getglobal( _globals.lua_state, "cpd_handle_packet" );
        if ( !lua_isfunction( _globals.lua_state, -1 )) {
            lua_pop( _globals.lua_state, 1 );
            return errlog( ERR_CRITICAL, "cpd_handle_packet is not a function.\n" );
        }
        
        lua_pushstring( _globals.lua_state, prefix );

        lua_newtable( _globals.lua_state );
        _push_ip_header( nfmark, ip_header );
        
        lua_pushnumber( _globals.lua_state, ntohs( 0 ));
        lua_setfield( _globals.lua_state, -2, "source_port" );

        lua_pushnumber( _globals.lua_state, ntohs( 0 ));
        lua_setfield( _globals.lua_state, -2, "destination_port" );
        
        if ( lua_pcall( _globals.lua_state, 2, 0, 0 ) != 0 ) {
            return errlog( ERR_CRITICAL, "lua_pcall %s\n", lua_tostring( _globals.lua_state, -1 ));
        }

        return 0;
    }

    if ( pthread_mutex_lock( &_globals.mutex ) != 0 ) return perrlog( "pthread_mutex_lock" );
    int ret = _critical_section();
    if ( pthread_mutex_unlock( &_globals.mutex ) != 0 ) return perrlog( "pthread_mutex_unlock" );

    if ( ret < 0 ) return errlog( ERR_CRITICAL, "_critical_section\n" );

    return ret;    
}



/**
 * Remove all of the entries in the host database.
 * @return The number of entries that were removed.
 */
int cpd_manager_clear_host_database( void )
{
    int _critical_section()
    {
        /* If necessary reload the lua script */
        if ( _update_lua_script() < 0 ) {
            return errlog( ERR_CRITICAL, "_update_lua_script\n" );
        }

        lua_getglobal( _globals.lua_state, "cpd_clear_host_database" );
        if ( !lua_isfunction( _globals.lua_state, -1 )) {
            lua_pop( _globals.lua_state, 1 );
            return errlog( ERR_CRITICAL, "cpd_clear_host_database is not a function.\n" );
        }
                
        if ( lua_pcall( _globals.lua_state, 0, 1, 0 ) != 0 ) {
            return errlog( ERR_CRITICAL, "lua_pcall %s\n", lua_tostring( _globals.lua_state, -1 ));
        }

        if ( !lua_isnumber( _globals.lua_state, -1 )) {
            lua_pop( _globals.lua_state, 1 );
            return errlog( ERR_CRITICAL, "cpd_clear_host_database did not return a number\n" );
        }
        
        int num_entries = lua_tointeger( _globals.lua_state, -1 );
        lua_pop( _globals.lua_state, -1 );
        return num_entries;
    }

    if ( pthread_mutex_lock( &_globals.mutex ) != 0 ) return perrlog( "pthread_mutex_lock" );
    int ret = _critical_section();
    if ( pthread_mutex_unlock( &_globals.mutex ) != 0 ) return perrlog( "pthread_mutex_unlock" );

    if ( ret < 0 ) return errlog( ERR_CRITICAL, "_critical_section\n" );

    return ret;
}

/**
 * Remove all of the entries that have expired.
 * @return the number of hosts that were removed.
 */
int cpd_manager_expire_sessions( void )
{
    int _critical_section()
    {
        /* If necessary reload the lua script */
        if ( _update_lua_script() < 0 ) {
            return errlog( ERR_CRITICAL, "_update_lua_script\n" );
        }

        lua_getglobal( _globals.lua_state, "cpd_expire_sessions" );
        if ( !lua_isfunction( _globals.lua_state, -1 )) {
            lua_pop( _globals.lua_state, 1 );
            return errlog( ERR_CRITICAL, "cpd_expire_sessions is not a function.\n" );
        }
                
        if ( lua_pcall( _globals.lua_state, 0, 1, 0 ) != 0 ) {
            return errlog( ERR_CRITICAL, "lua_pcall %s\n", lua_tostring( _globals.lua_state, -1 ));
        }

        if ( !lua_isnumber( _globals.lua_state, -1 )) {
            lua_pop( _globals.lua_state, 1 );
            return errlog( ERR_CRITICAL, "cpd_expire_sessions did not return a number\n" );
        }
        
        int num_entries = lua_tointeger( _globals.lua_state, -1 );
        lua_pop( _globals.lua_state, -1 );
        return num_entries;
    }

    if ( pthread_mutex_lock( &_globals.mutex ) != 0 ) return perrlog( "pthread_mutex_lock" );
    int ret = _critical_section();
    if ( pthread_mutex_unlock( &_globals.mutex ) != 0 ) return perrlog( "pthread_mutex_unlock" );

    if ( ret < 0 ) return errlog( ERR_CRITICAL, "_critical_section\n" );

    return ret;
}

/**
 * Flush out any log entries (logged packets) and update all of the timeouts.
 */
int cpd_manager_log_sessions( void )
{
    int _critical_section()
    {
        /* If necessary reload the lua script */
        if ( _update_lua_script() < 0 ) {
            return errlog( ERR_CRITICAL, "_update_lua_script\n" );
        }

        lua_getglobal( _globals.lua_state, "cpd_log_sessions" );
        if ( !lua_isfunction( _globals.lua_state, -1 )) {
            lua_pop( _globals.lua_state, 1 );
            return errlog( ERR_CRITICAL, "cpd_log_sessions is not a function.\n" );
        }
                
        if ( lua_pcall( _globals.lua_state, 0, 1, 0 ) != 0 ) {
            return errlog( ERR_CRITICAL, "lua_pcall %s\n", lua_tostring( _globals.lua_state, -1 ));
        }

        if ( !lua_isnumber( _globals.lua_state, -1 )) {
            lua_pop( _globals.lua_state, 1 );
            return errlog( ERR_CRITICAL, "cpd_log_sessions did not return a number\n" );
        }
        
        int num_entries = lua_tointeger( _globals.lua_state, -1 );
        lua_pop( _globals.lua_state, -1 );
        return num_entries;
    }

    if ( pthread_mutex_lock( &_globals.mutex ) != 0 ) return perrlog( "pthread_mutex_lock" );
    int ret = _critical_section();
    if ( pthread_mutex_unlock( &_globals.mutex ) != 0 ) return perrlog( "pthread_mutex_unlock" );

    if ( ret < 0 ) return errlog( ERR_CRITICAL, "_critical_section\n" );

    return ret;
}


static int _update_lua_script( void )
{
    debug( 10, "Checking if the LUA script has been updated.\n" );
    struct stat script_stat;
    if ( stat( _globals.lua_script, &script_stat ) < 0 ) {
        return perrlog( "stat" );
    }

    /* Uses == instead of <= so that time shifting back and forwards
     * will not affect this. */
    if (( _globals.script_mtime != 0 ) && ( script_stat.st_mtime == _globals.script_mtime )) {
        debug( 10, "Script is up to date, not reloading.\n" );
        return 0;
    }
    
    debug( 9, "Reloading script %s.\n", _globals.lua_script );

    if ( luaL_loadfile( _globals.lua_state, _globals.lua_script ) || 
         lua_pcall( _globals.lua_state, 0, 0, 0 )) {
        return errlog( ERR_CRITICAL, "Cannot load lua script '%s'\n", 
                       lua_tostring( _globals.lua_state, -1 ));
    }

    _globals.script_mtime = script_stat.st_mtime;
    
    return 0;
}

static int _update_lua_config( cpd_config_t* config, char* sqlite_file )
{
    /* Set the config table in lua */
    lua_newtable( _globals.lua_state );
    lua_pushboolean( _globals.lua_state, _globals.config.is_enabled );
    lua_setfield( _globals.lua_state, -2, "is_enabled" );

    lua_pushboolean( _globals.lua_state, _globals.config.concurrent_logins );
    lua_setfield( _globals.lua_state, -2, "concurrent_logins" );

    lua_pushboolean( _globals.lua_state, _globals.config.capture_bypassed );
    lua_setfield( _globals.lua_state, -2, "capture_bypassed_traffic" );

    lua_pushnumber( _globals.lua_state, _globals.config.idle_timeout_s );
    lua_setfield( _globals.lua_state, -2, "idle_timeout_s" );

    lua_pushnumber( _globals.lua_state, _globals.config.max_session_length_s );
    lua_setfield( _globals.lua_state, -2, "max_session_length_s" );

    lua_pushboolean( _globals.lua_state, _globals.config.redirect_https_enabled );
    lua_setfield( _globals.lua_state, -2, "redirect_https_enabled" );    

    lua_pushboolean( _globals.lua_state, _globals.config.use_https_page );
    lua_setfield( _globals.lua_state, -2, "use_https_page" );

    lua_pushstring( _globals.lua_state, sqlite_file );
    lua_setfield( _globals.lua_state, -2, "sqlite_file" );

    lua_setglobal( _globals.lua_state, "cpd_config" );
    
    return 0;
}

static char* _ether_ntoa_r(const struct ether_addr *addr, char* buffer, int buffer_len )
{
    if ( addr == NULL ) {
        return errlogargs_null();
    }

    if ( buffer == NULL ) {
        return errlogargs_null();
    }
    
    if ( buffer_len < 24 ) {
        return errlog_null( ERR_CRITICAL, "Buffer is less than %d characters\n", 24 );
    }

    uint8_t* o = (uint8_t*)addr->ether_addr_octet;

    snprintf( buffer, buffer_len, "%02x:%02x:%02x:%02x:%02x:%02x",
              o[0], o[1], o[2], o[3], o[4], o[5] );

    return buffer;
}

static int _lua_clock_gettime( lua_State *L )
{
    if ( !lua_isnumber( L, 1 )) {
        lua_pushstring( L, "'clk_id' should be a number" );
        lua_error(L);
    }
    
    clockid_t clk_id = (clockid_t)lua_tonumber( L, 1 );

    switch ( clk_id ) {
    case CLOCK_REALTIME:
    case CLOCK_MONOTONIC:
    case CLOCK_PROCESS_CPUTIME_ID:
    case CLOCK_THREAD_CPUTIME_ID:
        break;
    default:
        lua_pushstring( L, "'clk_id' is invalid" );
        lua_error(L);
    }

    struct timespec ts;
    if ( clock_gettime( clk_id, &ts ) < -1 ) {
        perrlog( "clock_gettime" );
        lua_pushstring( L, "'Unable to fetch time" );
        lua_error( L );
    }

    lua_pushnumber( L, ts.tv_sec );
    lua_pushnumber( L, ts.tv_nsec );

    return 2;
}


static int _start_cleanup_thread( void )
{
    if ( _globals.cleanup_thread != 0 ) {
        return errlog( ERR_CRITICAL, "_globals.cleanup_thread is non-zero\n" );
    }
    
    if ( pthread_create( &_globals.cleanup_thread, NULL, _cleanup_thread, NULL ) < 0 ) {
        return perrlog( "pthread_create" );
    }

    
    if ( _globals.cleanup_thread == 0 ) {
        return errlog( ERR_CRITICAL, "cleanup_thread is zero, coding error.\n" );
    }

    return 0;
}

static int _stop_cleanup_thread( void )
{
    pthread_t thread = _globals.cleanup_thread;
    
    _globals.cleanup_thread = 0;

    if ( thread == 0 ) {
        return 0;
    }
    
    pthread_kill( thread, SIGUSR1 );
    
    return 0;
}



static void* _cleanup_thread( void* arg )
{
    int time_left = 0;

    while ( pthread_self() == _globals.cleanup_thread ) {
        if ( time_left == 0 ) {
            time_left = _globals.config.expiration_frequency_s;
            
            if ( time_left <= 0 ) {
                time_left = 60;
            }
        }

        if (( time_left = sleep( time_left )) != 0 ) {
            perrlog( "sleep" );
            continue;
        }

        if ( cpd_manager_expire_sessions() < 0 ) {
            errlog( ERR_CRITICAL, "cpd_manager_expire_sessions\n" );
        }
    }

    return NULL;
}

static int _start_log_thread( void )
{
    if ( _globals.log_thread != 0 ) {
        return errlog( ERR_CRITICAL, "_globals.log_thread is non-zero\n" );
    }
    
    if ( pthread_create( &_globals.log_thread, NULL, _log_thread, NULL ) < 0 ) {
        return perrlog( "pthread_create" );
    }

    
    if ( _globals.log_thread == 0 ) {
        return errlog( ERR_CRITICAL, "log_thread is zero, coding error.\n" );
    }

    return 0;
}

static int _stop_log_thread( void )
{
    pthread_t thread = _globals.log_thread;
    
    _globals.log_thread = 0;

    if ( thread == 0 ) {
        return 0;
    }
    
    pthread_kill( thread, SIGUSR1 );
    
    return 0;
}



static void* _log_thread( void* arg )
{
    int time_left = 0;

    while ( pthread_self() == _globals.log_thread ) {
        if ( time_left <= 0 ) {
            time_left = 10;
            
        }

        if (( time_left = sleep( time_left )) != 0 ) {
            perrlog( "sleep" );
            continue;
        }

        if ( cpd_manager_log_sessions() < 0 ) {
            errlog( ERR_CRITICAL, "cpd_manager_log_sessions\n" );
        }
    }

    return NULL;
}


static void _push_ip_header( u_int nfmark, struct iphdr* ip_header )
{
    lua_pushstring( _globals.lua_state, unet_next_inet_ntoa( ip_header->saddr ));
    lua_setfield( _globals.lua_state, -2, "source_address" );

    lua_pushstring( _globals.lua_state, unet_next_inet_ntoa( ip_header->daddr ));
    lua_setfield( _globals.lua_state, -2, "destination_address" );

    lua_pushnumber( _globals.lua_state, ip_header->ttl );
    lua_setfield( _globals.lua_state, -2, "ttl" );

    lua_pushnumber( _globals.lua_state, ip_header->tos );
    lua_setfield( _globals.lua_state, -2, "tos" );

    lua_pushnumber( _globals.lua_state, ip_header->protocol );
    lua_setfield( _globals.lua_state, -2, "protocol" );

    lua_pushnumber( _globals.lua_state, nfmark );
    lua_setfield( _globals.lua_state, -2, "nfmark" );

    int client_intf = -1;

    switch ( nfmark & 0xF ) {
    case ( 1 << 0):
        client_intf = 0;
        break;
    case ( 1 << 1 ):
        client_intf = 1;
        break;
    case ( 1 << 2 ):
        client_intf = 2;
        break;
    case ( 1 << 3 ):
        client_intf = 3;
        break;
    case ( 1 << 4):
        client_intf = 4;
        break;
    case ( 1 << 5 ):
        client_intf = 5;
        break;
    case ( 1 << 6 ):
        client_intf = 6;
        break;
    case ( 1 << 7 ):
        client_intf = 7;
        break;
    }

    if ( client_intf == -1 ) {
        debug( 3, "Invalid nfmark %#010x, using interface interface.\n", nfmark );
        client_intf = 1;
    }

    lua_pushnumber( _globals.lua_state, client_intf );
    lua_setfield( _globals.lua_state, -2, "client_intf" );

}




