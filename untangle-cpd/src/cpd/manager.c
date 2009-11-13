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
#include "cpd/host_database.h"
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
    cpd_config_t config;
    cpd_host_database_t host_database;
    
    lua_State *lua_state;

    char* lua_script;
    char* sqlite_file;
    time_t script_mtime;

    /* The next time wake up to cleanup expired hosts. */
    struct timespec next_update;
} _globals = {
    .init = 0,
    .lua_script = NULL,
    .script_mtime = 0,
    .mutex = PTHREAD_RECURSIVE_MUTEX_INITIALIZER_NP,
};

static int _update_lua_script( void );
static int _update_lua_config( cpd_config_t* config, char* sqlite_file );

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

    if ( cpd_manager_set_config( config ) < 0 ) {
        return errlog( ERR_CRITICAL, "cpd_manager_set_config\n" );
    }

    if ( _update_lua_script() < 0 ) {
        return errlog( ERR_CRITICAL, "_update_lua_script\n" );
    }

    if ( cpd_host_database_init( &_globals.host_database ) < 0 ) {
        return errlog( ERR_CRITICAL, "cpd_host_database_init\n" );
    }

    _globals.init = 1;
    
    clock_gettime( CLOCK_MONOTONIC, &_globals.next_update );

    

    return 0;
}

void cpd_manager_destroy( void )
{
    cpd_host_database_destroy( &_globals.host_database );

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
                
        if ( _update_lua_config( config, _globals.sqlite_file ) < 0 ) {
            return errlog( ERR_CRITICAL, "_update_lua_config\n" );
        }

        memcpy( &_globals.config, config, sizeof( _globals.config ));
        
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
            lua_pushstring( _globals.lua_state, ether_ntoa_r( hw_addr, hw_addr_str ));
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
        
        int is_new_entry = lua_toboolean( _globals.lua_state, -1 );
        lua_pop( _globals.lua_state, -1 );
        return is_new_entry;
    }

    if ( pthread_mutex_lock( &_globals.mutex ) != 0 ) return perrlog( "pthread_mutex_lock" );
    int ret = _critical_section();
    if ( pthread_mutex_unlock( &_globals.mutex ) != 0 ) return perrlog( "pthread_mutex_unlock" );

    if ( ret < 0 ) return errlog( ERR_CRITICAL, "_critical_section\n" );

    return 0;    
}

/**
 * Remove IPv4 host (will remove corresponding MAC if it exists)
 */
int cpd_manager_remove_ipv4_addr( struct in_addr* ipv4_addr )
{    
    if ( ipv4_addr == NULL ) {
        return errlogargs();
    }

    int _critical_section()
    {
        cpd_host_database_entry_t entry;

        if ( cpd_host_database_remove_ipv4_addr( &_globals.host_database, ipv4_addr, &entry ) < 0 ) {
            return errlog( ERR_CRITICAL, "cpd_host_database_remove_ipv4_addr\n" );
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
 * Remove Hardware Address (will remove corresponding IPv4 if it exists)
 */
int cpd_manager_remove_hw_addr( struct ether_addr* hw_addr )
{    
    if ( hw_addr == NULL ) {
        return errlogargs();
    }

    int _critical_section()
    {
        cpd_host_database_entry_t entry;

        if ( cpd_host_database_remove_hw_addr( &_globals.host_database, hw_addr, &entry ) < 0 ) {
            return errlog( ERR_CRITICAL, "cpd_host_database_remove_hw_addr\n" );
        }

        return 0;
    }

    if ( pthread_mutex_lock( &_globals.mutex ) != 0 ) return perrlog( "pthread_mutex_lock" );
    int ret = _critical_section();
    if ( pthread_mutex_unlock( &_globals.mutex ) != 0 ) return perrlog( "pthread_mutex_unlock" );

    if ( ret < 0 ) return errlog( ERR_CRITICAL, "_critical_section\n" );

    return 0;    
}

static int _update_lua_script( void )
{
    debug( 9, "Checking if the LUA script has been updated.\n" );
    struct stat script_stat;
    if ( stat( _globals.lua_script, &script_stat ) < 0 ) {
        return perrlog( "stat" );
    }

    /* Uses == instead of <= so that time shifting back and forwards
     * will not affect this. */
    if (( _globals.script_mtime != 0 ) && ( script_stat.st_mtime == _globals.script_mtime )) {
        debug( 9, "Script is up to date, not reloading.\n" );
        return 0;
    }
    
    debug( 9, "Reloading script %s.\n", _globals.lua_script );

    if ( luaL_loadfile( _globals.lua_state, _globals.lua_script ) || 
         lua_pcall( _globals.lua_state, 0, 0, 0 )) {
        return errlog( ERR_CRITICAL, "Cannot load lua script %s\n", 
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

    lua_pushnumber( _globals.lua_state, _globals.config.idle_timeout );
    lua_setfield( _globals.lua_state, -2, "idle_timeout" );

    lua_pushnumber( _globals.lua_state, _globals.config.max_session_length );
    lua_setfield( _globals.lua_state, -2, "max_session_length" );

    lua_pushstring( _globals.lua_state, sqlite_file );
    lua_setfield( _globals.lua_state, -2, "sqlite_file" );

    lua_setglobal( _globals.lua_state, "cpd_config" );

    return 0;
}
