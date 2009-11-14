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

#include <stdlib.h>
#include <stddef.h>

/* including stdarg.h here, since recent libmicrohttpd-dev in sid doesn't do
   it on its own. -- Seb, Wed, 19 Nov 2008 15:10:30 -0800 */
#include <stdarg.h>
#include <microhttpd.h>

#include <mvutil/debug.h>
#include <mvutil/errlog.h>
#include <mvutil/unet.h>

#include "json/object_utils.h"
#include "json/serializer.h"
#include "json/server.h"

#include "cpd.h"
#include "cpd/manager.h"
#include "cpd/status.h"

/* ten-4 */
#define STATUS_OK 104
#define STATUS_ERR 99

#define _ADD_ACTIVE_HOST_MAX 256

static struct json_object *_hello_world( struct json_object* request );

static struct json_object *_get_config( struct json_object* request );

static struct json_object *_set_config( struct json_object* request );

static struct json_object *_set_debug_level( struct json_object* request );

static struct json_object *_replace_host( struct json_object* request );

static struct json_object *_remove_ipv4_addr( struct json_object* request );

static struct json_object *_remove_hw_addr( struct json_object* request );

static struct json_object *_clear_host_database( struct json_object* request );

static struct json_object *_get_ipv4_addr( struct json_object* request );

static struct json_object *_get_hw_addr( struct json_object* request );

static struct json_object *_list_functions( struct json_object* request );

static struct json_object *_get_status( struct json_object* request );

static struct json_object *_shutdown( struct json_object* request );


extern void cpd_main_shutdown( void );

static struct
{
    char *config_file;
    /* Use this response when there is an internal error */
    struct json_object* internal_error;

    /* The time that instance started. */
    struct timeval startup_time;

    /* Time of the startup in json */
    struct json_object* startup_time_json;

    json_server_function_entry_t function_table[];
} _globals = {
    .config_file = NULL,
    .internal_error = NULL,
    .startup_time_json = NULL,
    .function_table = {
        { .name = "hello_world", .function = _hello_world },
        { .name = "get_config", .function = _get_config },
        { .name = "set_config", .function = _set_config },
        { .name = "set_debug_level", .function = _set_debug_level },
        { .name = "replace_host", .function = _replace_host },
        { .name = "remove_ipv4_addr", .function = _remove_ipv4_addr },
        { .name = "remove_hw_addr", .function = _remove_hw_addr },
        { .name = "clear_host_database", .function = _clear_host_database },
        { .name = "list_functions", .function = _list_functions },
        { .name = "get_status", .function = _get_status },        
        { .name = "shutdown", .function = _shutdown },
        { .name = NULL, .function = NULL }
    }
};

int cpd_functions_init( char* config_file )
{
    _globals.config_file = config_file;

    /* Update the startup time */
    if ( gettimeofday( &_globals.startup_time, NULL ) < 0 ) {
        return perrlog( "gettimeofday" );
    }

    _globals.startup_time_json = json_object_utils_create_timeval( &_globals.startup_time );
    if ( _globals.startup_time_json == NULL ) {
        return errlog( ERR_CRITICAL, "json_object_utils_create_timeval\n" );
    }

    if (( _globals.internal_error = json_server_build_response( STATUS_ERR, 0, "Internal error occurred" ))
        == NULL ) {
        return errlog( ERR_CRITICAL, "json_server_build_response\n" );
    }

    return 0;
}

int cpd_functions_load_config( cpd_config_t* config )
{
    if ( config == NULL ) return errlogargs();

    if ( cpd_manager_set_config( config ) < 0 ) {
        return errlog( ERR_CRITICAL, "cpd_manager_set_config\n" );
    }

    return 0;
}

json_server_function_entry_t *cpd_functions_get_json_table()
{
    return _globals.function_table;
}

static struct json_object* _hello_world( struct json_object* request )
{
    struct json_object* response = NULL;
    if (( response = json_server_build_response( STATUS_OK, 0, "Hello from cpd" )) == NULL ) {
        return errlog_null( ERR_CRITICAL, "json_server_build_response\n" );
    }

    json_object_object_add( response, "startup_time", json_object_get( _globals.startup_time_json ));
            
    return response;
}

static struct json_object *_get_config( struct json_object* request )
{
    cpd_config_t config;

    if ( cpd_manager_get_config( &config ) < 0 ) {
        errlog( ERR_CRITICAL, "cpd_manager_get_config\n" );
        return json_object_get( _globals.internal_error );
    }

    struct json_object* response = NULL;

    if (( response = json_server_build_response( STATUS_OK, 0, "Retrieved settings" )) == NULL ) {
        errlog( ERR_CRITICAL, "json_server_build_response\n" );
        return json_object_get( _globals.internal_error );
    }

    struct json_object* config_json = NULL;
    if (( config_json = cpd_config_to_json( &config )) == NULL ) {
        json_object_put( response );
        errlog( ERR_CRITICAL, "cpd_config_to_json\n" );
        return json_object_get( _globals.internal_error );
    }
    
    json_object_object_add( response, "config", config_json );

    return response;
}

static struct json_object *_set_config( struct json_object* request )
{
    struct json_object* config_json = NULL;
    struct json_object* new_config_json = NULL;

    cpd_config_t config;
    
    cpd_config_init( &config );

    int status = STATUS_ERR;

    int _critical_section( char* message, int message_size ) {
        if (( config_json = json_object_object_get( request, "config" )) == NULL ) {
            strncpy( message, "Missing config.", message_size );
            return 0;
        }

        if ( cpd_config_load_json( &config, config_json ) < 0 ) {
            errlog( ERR_CRITICAL, "cpd_config_load_json\n" );
            strncpy( message, "Unable to load json configuration.", message_size );
            return 0;
        }

        if ( cpd_functions_load_config( &config ) < 0 ) {
            errlog( ERR_CRITICAL, "cpd_functions_load_config\n" );
            strncpy( message, "Unable to load json configuration.", message_size );
            return 0;
        }
        
        if ( cpd_manager_get_config( &config ) < 0 ) {
            errlog( ERR_CRITICAL, "cpd_manager_get_config\n" );
            strncpy( message, "Unable to get config for reserialization.", message_size );
            return 0;
        }

        if (( new_config_json = cpd_config_to_json( &config )) == NULL ) {
            errlog( ERR_CRITICAL, "cpd_config_to_json\n" );
            strncpy( message, "Unable to serializer json configuration.", message_size );
            return 0;
        }
        
        if (( _globals.config_file != NULL ) &&
            ( json_object_get_boolean( json_object_object_get( request, "write_config" )) == TRUE )) {
            debug( 10, "FUNCTIONS: Writing config back to the file '%s'\n.", _globals.config_file );
            if ( json_object_to_file( _globals.config_file, new_config_json ) < 0 ) {
                strncpy( message, "Unable to save config file.", message_size );
                return 0;
            }
        }
        
        strncpy( message, "Successfully loaded the configuration.",  message_size );
        status = STATUS_OK;

        return 0;
    }

    char response_message[128] = "An unexpected error occurred.";

    if ( _critical_section( response_message, sizeof( response_message )) < 0 ) {
        json_object_put( new_config_json );
        return errlog_null( ERR_CRITICAL, "_critical_section\n" );
    }

    struct json_object* response = NULL;

    if (( response = json_server_build_response( status, 0, response_message )) == NULL ) {
        return errlog_null( ERR_CRITICAL, "json_server_build_response\n" );
    }

    if (( new_config_json != NULL ) && 
        ( json_object_utils_add( response, "config", new_config_json ) < 0 )) {
        json_object_put( new_config_json );
        json_object_put( response );
        return errlog_null( ERR_CRITICAL, "json_object_utils_add\n" );
    }

    return response;
}

static struct json_object *_set_debug_level( struct json_object* request )
{
    int debug_level = 0;
    
    struct json_object* response = NULL;

    struct json_object* temp = NULL;
    if (( temp = json_object_object_get( request, "level" )) != NULL ) {
        debug_level = json_object_get_int( temp );
    } else {
        if (( response = json_server_build_response( STATUS_ERR, 0, "Missing level" )) == NULL ) {
            return errlog_null( ERR_CRITICAL, "json_server_build_response\n" );
        }
        return response;
    }
    
    /* Configure the debug level */
    debug_set_mylevel( debug_level );

    if (( response = json_server_build_response( STATUS_OK, 0, "Set debug level to %d", debug_level )) 
        == NULL ) {
        return errlog_null( ERR_CRITICAL, "json_server_build_response\n" );
    }

    return response;
}

static struct json_object *_replace_host( struct json_object* request )
{
    int status = STATUS_ERR;

    int _critical_section( char* message, int message_size )
    {
        char *username_str;
        cpd_host_database_username_t username;
        char *hw_addr_str;
        struct ether_addr hw_addr;
        struct ether_addr *hw_addr_ptr = NULL;
        char *ipv4_addr_str;
        struct in_addr ipv4_addr;
        int update_session_start = 0;
        struct json_object* temp;
        
        if (( username_str = json_object_utils_get_string( request, "username" )) == NULL ) {
            strncpy( message, "Missing username", message_size );
            return 0;
        }
        strncpy( username.u, username_str, sizeof( username.u ));

        /* Doesn't matter if it is null */
        hw_addr_str = json_object_utils_get_string( request, "hw_addr" );
        
        /* Try to parse it */
        if ( hw_addr_str != NULL ) {
            if ( ether_aton_r( hw_addr_str, &hw_addr ) == NULL ) {
                snprintf( message, message_size, "Invalid ethernet address: '%s'", hw_addr_str );
                return 0;
            }
            hw_addr_ptr = &hw_addr;
        }

        if (( ipv4_addr_str = json_object_utils_get_string( request, "ipv4_addr" )) == NULL ) {
            strncpy( message, "Missing ipv4 address", message_size );
            return 0;
        }
        
        if ( inet_aton( ipv4_addr_str, &ipv4_addr ) == 0 ) {
            snprintf( message, message_size, "Invalid IPv4 address: '%s'", ipv4_addr_str );
            return 0;
        }

        if (( temp = json_object_object_get( request, "update_session_start" )) != NULL ) {
            update_session_start = json_object_get_boolean( temp );
        }

        if ( cpd_manager_replace_host( &username, hw_addr_ptr, &ipv4_addr, update_session_start ) < 0 ) {
            return errlog( ERR_CRITICAL, "cpd_manager_replace_host\n" );
        }
        
        snprintf( message, message_size, "Successfully replaced host %s -> (%s,%s).", 
                  username.u, hw_addr_str == NULL ? "no hw addr" : hw_addr_str, ipv4_addr_str );

        status = STATUS_OK;

        return 0;
    }

    char response_message[128] = "An unexpected error occurred.";

    if ( _critical_section( response_message, sizeof( response_message )) < 0 ) {
        return errlog_null( ERR_CRITICAL, "_critical_section\n" );
    }

    struct json_object* response = NULL;

    if (( response = json_server_build_response( status, 0, response_message )) == NULL ) {
        return errlog_null( ERR_CRITICAL, "json_server_build_response\n" );
    }

    return response;
}

static struct json_object *_remove_ipv4_addr( struct json_object* request )
{
    int status = STATUS_ERR;

    int _critical_section( char* message, int message_size )
    {
        char *ipv4_addr_str;
        struct in_addr ipv4_addr;

        if (( ipv4_addr_str = json_object_utils_get_string( request, "ipv4_addr" )) == NULL ) {
            strncpy( message, "Missing ipv4 address", message_size );
            return 0;
        }
        
        if ( inet_aton( ipv4_addr_str, &ipv4_addr ) == 0 ) {
            snprintf( message, message_size, "Invalid IPv4 address: '%s'", ipv4_addr_str );
            return 0;
        }

        int num_entries = 0;
        if (( num_entries = cpd_manager_remove_ipv4_addr( &ipv4_addr )) < 0 ) {
            return errlog( ERR_CRITICAL, "cpd_manager_remove_ipv4_addr\n" );
        }
        
        snprintf( message, message_size, "Successfully removed host %s, removed %d entries.", ipv4_addr_str, num_entries );
        status = STATUS_OK;

        return 0;
    }

    char response_message[128] = "An unexpected error occurred.";

    if ( _critical_section( response_message, sizeof( response_message )) < 0 ) {
        return errlog_null( ERR_CRITICAL, "_critical_section\n" );
    }

    struct json_object* response = NULL;

    if (( response = json_server_build_response( status, 0, response_message )) == NULL ) {
        return errlog_null( ERR_CRITICAL, "json_server_build_response\n" );
    }

    return response;    
}

static struct json_object *_remove_hw_addr( struct json_object* request )
{
    int status = STATUS_ERR;

    int _critical_section( char* message, int message_size )
    {
        char *hw_addr_str;
        struct ether_addr hw_addr;
        struct ether_addr *hw_addr_ptr = NULL;

        /* Doesn't matter if it is null */
        hw_addr_str = json_object_utils_get_string( request, "hw_addr" );
        
        /* Try to parse it */
        if ( hw_addr_str != NULL ) {
            if ( ether_aton_r( hw_addr_str, &hw_addr ) == NULL ) {
                snprintf( message, message_size, "Invalid ethernet address: '%s'", hw_addr_str );
                return 0;
            }
            hw_addr_ptr = &hw_addr;
        }
        
        int num_entries = 0;
        if (( num_entries = cpd_manager_remove_hw_addr( hw_addr_ptr )) < 0 ) {
            return errlog( ERR_CRITICAL, "cpd_manager_remove_hw_addr\n" );
        }
        
        snprintf( message, message_size, "Successfully removed hw address %s, remove %d entries", 
                  hw_addr_str, num_entries );
        status = STATUS_OK;

        return 0;
    }

    char response_message[128] = "An unexpected error occurred.";

    if ( _critical_section( response_message, sizeof( response_message )) < 0 ) {
        return errlog_null( ERR_CRITICAL, "_critical_section\n" );
    }

    struct json_object* response = NULL;

    if (( response = json_server_build_response( status, 0, response_message )) == NULL ) {
        return errlog_null( ERR_CRITICAL, "json_server_build_response\n" );
    }

    return response;    
}

static struct json_object *_clear_host_database( struct json_object* request )
{
    int status = STATUS_ERR;

    int _critical_section( char* message, int message_size )
    {        
        int num_entries = 0;
        if (( num_entries = cpd_manager_clear_host_database()) < 0 ) {
            return errlog( ERR_CRITICAL, "cpd_manager_remove_hw_addr\n" );
        }
        
        snprintf( message, message_size, "Successfully reset the host database, remove %d entries", 
                  num_entries );
        status = STATUS_OK;

        return 0;
    }

    char response_message[128] = "An unexpected error occurred.";

    if ( _critical_section( response_message, sizeof( response_message )) < 0 ) {
        return errlog_null( ERR_CRITICAL, "_critical_section\n" );
    }

    struct json_object* response = NULL;

    if (( response = json_server_build_response( status, 0, response_message )) == NULL ) {
        return errlog_null( ERR_CRITICAL, "json_server_build_response\n" );
    }

    return response;    
}


static struct json_object *_get_ipv4_addr( struct json_object* request )
{
}

static struct json_object *_get_hw_addr( struct json_object* request )
{
}

static struct json_object *_list_functions( struct json_object* request )
{
    struct json_object* response= NULL;
    struct json_object* functions = NULL;

    int _critical_section() {
        int c = 0;
        for ( c = 0 ; ; c++ ) {
            if (( _globals.function_table[c].name == NULL ) ||
                ( _globals.function_table[c].function == NULL )) break;

            if ( json_object_utils_array_add_string( functions, _globals.function_table[c].name ) < 0 ) {
                return errlog( ERR_CRITICAL, "json_object_utils_array_add_string\n" );
            }
        }

        if (( response = json_server_build_response( STATUS_OK, 0, "Listed functions" )) == NULL ) {
            return errlog( ERR_CRITICAL, "json_server_build_response\n" );
        }

        json_object_object_add( response, "functions", functions );

        functions = NULL;
        
        return 0;
    }

    if (( functions = json_object_new_array()) == NULL ) {
        errlog( ERR_CRITICAL, "json_object_new_array\n" );
        return json_object_get( _globals.internal_error );
    }

    if ( _critical_section() < 0 ) {
        if ( functions != NULL ) json_object_put( functions );
        if ( response != NULL ) json_object_put( response );
        errlog( ERR_CRITICAL, "_critical_section\n" );
        return json_object_get( _globals.internal_error );
    }

    return response;    
}

static struct json_object *_get_status( struct json_object* request )
{
    cpd_status_t status;

    if ( cpd_status_init( &status ) < 0 ) {
        errlog( ERR_CRITICAL, "cpd_status_init\n" );
        return json_object_get( _globals.internal_error );        
    }

    struct json_object* response = NULL;
    struct json_object* status_json = NULL;
    struct json_object* temp = NULL;

    int _critical_section()
    {
        int clear_last_fail = 0;
        if (( temp = json_object_object_get( request, "clear_last_fail" )) != NULL ) {
            clear_last_fail = json_object_get_boolean( temp );
        }
        
        if ( cpd_manager_get_status( &status ) < 0 ) {
            return errlog( ERR_CRITICAL, "cpd_manager_get_status\n" );
        }
        
        if (( response = json_server_build_response( STATUS_OK, 0, "Retrieved settings" )) == NULL ) {
            return errlog( ERR_CRITICAL, "json_server_build_response\n" );
        }
        
        
        if (( status_json = cpd_status_to_json( &status )) == NULL ) {
            return errlog( ERR_CRITICAL, "cpd_status_to_json\n" );
        }
        json_object_object_add( response, "cpd_status", status_json );
        status_json = NULL;
       
        json_object_object_add( response, "startup_time", json_object_get( _globals.startup_time_json ));

        return 0;
    } 

    int ret = _critical_section();

    cpd_status_destroy( &status );

    if ( ret < 0 ) {
        if ( response != NULL ) json_object_put( response );
        if ( status_json != NULL ) json_object_put( status_json );
        return json_object_get( _globals.internal_error );
    }

    return response;
}

static struct json_object *_shutdown( struct json_object* request )
{
    cpd_main_shutdown();

    struct json_object* response = NULL;
    if (( response = json_server_build_response( STATUS_OK, 0, "Shutdown signal sent" )) == NULL ) {
        return errlog_null( ERR_CRITICAL, "json_server_build_response\n" );
    }

    return response;
}
