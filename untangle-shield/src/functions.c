/*
 * $HeadURL: svn://chef/work/src/libnetcap/src/netcap_shield.c $
 * Copyright (c) 2003-2008 Untangle, Inc. 
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License, version 2,
 * as published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but
 * AS-IS and WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE, TITLE, or
 * NONINFRINGEMENT.  See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA.
 */

#include <stdlib.h>

#include <microhttpd.h>

#include <mvutil/debug.h>
#include <mvutil/errlog.h>

#include "json/object_utils.h"
#include "json/server.h"

#include "bouncer/logs.h"
#include "bouncer/shield.h"

/* ten-4 */
#define STATUS_OK 104
#define STATUS_ERR 99

static struct json_object *_hello_world( struct json_object* request );

static struct json_object* _advance_logs( struct json_object* request );

static struct json_object* _get_logs( struct json_object* request );

static struct json_object* _get_config( struct json_object* request );

static struct json_object* _set_config( struct json_object* request );

static struct json_object* _bless_users( struct json_object* request );

static struct json_object* _dump_shield( struct json_object* request );

static int _dump_element( barfight_trie_element_t element, void *arg );

static struct
{
    barfight_bouncer_logs_t* logs;
    char *config_file;
    char *bless_filename;
    json_server_function_entry_t function_table[];
} _globals = {
    .logs = NULL,
    .config_file = NULL,
    .bless_filename = NULL,
    .function_table = {
        { .name = "hello_world", .function = _hello_world },
        { .name = "advance_logs", .function = _advance_logs },
        { .name = "get_logs", .function = _get_logs },
        { .name = "get_config", .function = _get_config },
        { .name = "set_config", .function = _set_config },
        { .name = "bless_users", .function = _bless_users },
        { .name = "dump_shield", .function = _dump_shield },
        { .name = NULL, .function = NULL }
    }
};

int barfight_functions_init( barfight_bouncer_logs_t* logs, char* config_file, char* bless_filename )
{
    if ( logs == NULL ) return errlogargs();
    _globals.logs = logs;
    _globals.config_file = config_file;
    _globals.bless_filename = bless_filename;
    return 0;
}

json_server_function_entry_t *barfight_functions_get_json_table()
{
    return _globals.function_table;
}

int barfight_functions_load_config( bouncer_shield_config_t* config )
{
    if ( config == NULL ) return errlogargs();
    
    if ( barfight_shield_set_config( config ) < 0 ) {
        return errlog( ERR_CRITICAL, "barfight_shield_set_config\n" );
    }
    
    /* Update the logs */
    if ( _globals.logs != NULL ) {
        /* Update the timeout */
        if ( barfight_bouncer_logs_set_rotate_delay( _globals.logs, config->log_rotate_delay_ms ) < 0 ) {
            errlog( ERR_CRITICAL, "barfight_bouncer_logs_set_rotate_delay\n" );
        }
        
        if ( barfight_bouncer_logs_advance( _globals.logs ) < 0 ) {
            return errlog( ERR_CRITICAL, "barfight_bouncer_logs_advance\n" );
        }
    }
    
    if ( barfight_shield_bless_users( &config->bless_array ) < 0 ) {
        return errlog( ERR_CRITICAL, "barfight_shield_bless_users\n" );
    }

    return 0;
}

static struct json_object* _hello_world( struct json_object* request )
{
    struct json_object* response = NULL;
    if (( response = json_server_build_response( STATUS_OK, 0, "Hello from barfight" )) == NULL ) {
        return errlog_null( ERR_CRITICAL, "json_server_build_response\n" );
    }
    return response;
}

static struct json_object* _advance_logs( struct json_object* request )
{
    struct json_object* response = NULL;
    
    barfight_bouncer_logs_t* logs = _globals.logs;
    if ( logs == NULL ) {
        if (( response = json_server_build_response( STATUS_ERR, 0, "Logs aren't initialized." )) == NULL ) {
            return errlog_null( ERR_CRITICAL, "json_server_build_response\n" );
        }
        
        return response;
    }

    if ( barfight_bouncer_logs_advance( logs ) < 0 ) {
        if (( response = json_server_build_response( STATUS_ERR, 0, "Unable to advance logs." )) == NULL ) {
            return errlog_null( ERR_CRITICAL, "json_server_build_response\n" );
        }
        
        return response;
    }

    if (( response = json_server_build_response( STATUS_OK, 0, "Advanced Logs." )) == NULL ) {
        return errlog_null( ERR_CRITICAL, "json_server_build_response\n" );
    }
    
    return response;
}

static struct json_object* _get_logs( struct json_object* request )
{
    struct json_object* response = NULL;
    
    barfight_bouncer_logs_t* logs = _globals.logs;
    if ( logs == NULL ) {
        if (( response = json_server_build_response( STATUS_ERR, 0, "Logs aren't initialized." )) == NULL ) {
            return errlog_null( ERR_CRITICAL, "json_server_build_response\n" );
        }
        
        return response;
    }
    
    struct json_object* json_logs = NULL;
    
    int ignore_accept_only = 0;
    
    struct json_object* temp = NULL;
    if (( temp = json_object_object_get( request, "ignore_accept_only" )) != NULL ) {
        ignore_accept_only = json_object_get_int( temp );
    }

    struct timeval start_time;
    struct timeval* start_time_ptr = NULL;

    if (( temp = json_object_object_get( request, "start_time" )) != NULL ) {
        if ( json_object_utils_parse_timeval( temp, &start_time ) < 0 ) {
            debug( 10, "FUNCTIONS: Ignoring invalid start time object.\n" );
            start_time_ptr = NULL;
        } else {
            start_time_ptr = &start_time;
        }
    } else {
        debug( 10, "FUNCTIONS: start time is not specified.\n" );
        start_time_ptr = NULL;
    }

    if (( json_logs = barfight_bouncer_logs_to_json( logs, start_time_ptr,
                                                     ignore_accept_only )) == NULL ) {
        if (( response = json_server_build_response( STATUS_ERR, 0, "Unable to convert logs to JSON." )) == NULL ) {
            return errlog_null( ERR_CRITICAL, "json_server_build_response\n" );
        }
        
        return response;
    }
    
    if (( response = json_server_build_response( STATUS_OK, 0, "Retrieved Logs." )) == NULL ) {
        json_object_put( json_logs );
        return errlog_null( ERR_CRITICAL, "json_server_build_response\n" );
    }

    if ( json_object_utils_add( response, "logs", json_logs ) < 0 ) {
        json_object_put( json_logs );
        json_object_put( response );
        return errlog_null( ERR_CRITICAL, "json_object_utils_add\n" );
    }
    
    return response;
}

static struct json_object* _get_config( struct json_object* request )
{
    bouncer_shield_config_t config;
    
    if ( barfight_shield_get_config( &config )) {
        return errlog_null( ERR_CRITICAL, "bouncer_shield_get_config\n" );
    }

    struct json_object* config_json = NULL;
    struct json_object* response = NULL;

    if (( config_json = bouncer_shield_config_to_json( &config )) == NULL ) {
        errlog( ERR_CRITICAL, "bouncer_shield_config_to_json\n" );
        
        if (( response = json_server_build_response( STATUS_ERR, 0, "Unable to convert logs to JSON." )) == NULL ) {
            return errlog_null( ERR_CRITICAL, "json_server_build_response\n" );
        }
        
        return response;
    }

    if (( response = json_server_build_response( STATUS_OK, 0, "Retrieved Config." )) == NULL ) {
        json_object_put( config_json );
        return errlog_null( ERR_CRITICAL, "json_server_build_response\n" );
    }

    if ( json_object_utils_add( response, "config", config_json ) < 0 ) {
        json_object_put( config_json );
        json_object_put( response );
        return errlog_null( ERR_CRITICAL, "json_object_utils_add\n" );
    }
    
    return response;
}

static struct json_object* _set_config( struct json_object* request )
{
    struct json_object* config_json = NULL;
    struct json_object* new_config_json = NULL;

    bouncer_shield_config_t config;

    int status = STATUS_ERR;

    int _critical_section( char* message, int message_size ) {
        if (( config_json = json_object_object_get( request, "config" )) == NULL ) {
            strncpy( message, "Missing config.", message_size );
            return 0;
        }

        if ( bouncer_shield_config_load_json( &config, config_json ) < 0 ) {
            errlog( ERR_CRITICAL, "bouncer_shield_config_load_json\n" );
            strncpy( message, "Unable to load json configuration.", message_size );
            return 0;
        }
        
        if ( barfight_functions_load_config( &config ) < 0 ) {
            errlog( ERR_CRITICAL, "barfight_functions_load_config\n" );
            strncpy( message, "Unable to set json configuration.", message_size );
            return 0;
        }

        if ( barfight_shield_get_config( &config ) < 0 ) {
            errlog( ERR_CRITICAL, "barfight_shield_get_config\n" );
            strncpy( message, "Unable to verify new shield configuration.", message_size );
            return 0;
        }
        
        if (( new_config_json = bouncer_shield_config_to_json( &config )) == NULL ) {
            errlog( ERR_CRITICAL, "bouncer_shield_config_to_json\n" );
            strncpy( message, "Unable to convert the new configuration to JSON.", message_size );
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

static struct json_object* _bless_users( struct json_object* request )
{
    if ( request == NULL ) return errlogargs_null();

    int status = STATUS_ERR;
    char message[128] = "An unknown error has occurred.";
    struct json_object* new_config_json = NULL;


    int _critical_section() {
        /* Retrieve the list of users to bless and build up an array */
        struct json_object* bless_array_json = NULL;

        barfight_shield_bless_t bless_data[BLESS_COUNT_MAX];
        barfight_shield_bless_array_t bless_array = {
            .d = bless_data
        };
        
        if (( bless_array_json = json_object_object_get( request, "users" )) == NULL ) {
            strncpy( message,  "Missing the field 'users'.", sizeof( message ));
            return 0;
        }

        if ( bouncer_shield_config_load_bless_json( &bless_array, bless_array_json ) < 0 ) {
            strncpy( message,  "Unable to load JSON bless array.", sizeof( message ));
            return 0;
        }
        
        if ( barfight_shield_bless_users( &bless_array ) < 0 ) {
            strncpy( message,  "Unable to load JSON bless array.", sizeof( message ));
            return 0;
        }

        bouncer_shield_config_t config;
        
        if ( barfight_shield_get_config( &config )) {
            return errlog( ERR_CRITICAL, "bouncer_shield_get_config\n" );
        }

        if (( new_config_json = bouncer_shield_config_to_json( &config )) == NULL ) {
            errlog( ERR_CRITICAL, "bouncer_shield_config_to_json\n" );
            strncpy( message, "Unable to convert the new configuration to JSON.", sizeof( message ));
            return 0;
        }

        if (( _globals.config_file != NULL ) &&
            ( json_object_get_boolean( json_object_object_get( request, "write_config" )) == TRUE )) {
            debug( 10, "FUNCTIONS: Writing config back to the file '%s'\n.", _globals.config_file );
            if ( json_object_to_file( _globals.config_file, new_config_json ) < 0 ) {
                strncpy( message, "Unable to save config file.", sizeof( message ));
                return 0;
            }
        }
        
        if (( _globals.bless_filename != NULL ) &&
            ( json_object_get_boolean( json_object_object_get( request, "write_users" )) == TRUE )) {
            debug( 10, "FUNCTIONS: Writing users to the file '%s'\n.", _globals.bless_filename );
            if ( json_object_to_file( _globals.bless_filename, bless_array_json ) < 0 ) {
                strncpy( message, "Unable to save users.", sizeof( message ));
                return 0;
            }
        }

        snprintf( message, sizeof( message ), "Successfully blessed %d users", bless_array.count );

        status = STATUS_OK;
        
        return 0;
    }
    
    int ret = _critical_section();
    
    if ( new_config_json != NULL ) json_object_put( new_config_json );
    
    if ( ret < 0 ) return errlog_null( ERR_CRITICAL, "_critical_section\n" );
    
    struct json_object* response = NULL;

    if (( response = json_server_build_response( status, 0, message )) == NULL ) {
        return errlog_null( ERR_CRITICAL, "json_server_build_response\n" );
    }

    return response;
}

static struct json_object* _dump_shield( struct json_object* request )
{
    struct json_object* json_array = NULL;

    int _critical_section() {
        if ( barfight_bouncer_shield_debug( _dump_element, json_array ) < 0 ) {
            return errlog( ERR_CRITICAL, "barfight_bouncer_shield_debug\n" );
        }

        return 0;
    }

    if (( json_array = json_object_new_array()) == NULL ) {
        return errlog_null( ERR_CRITICAL, "json_object_new_array\n" );
    }

    if ( _critical_section() < 0 ) {
        json_object_put( json_array );
        return errlog_null( ERR_CRITICAL, "_critical_section\n" );
    }
    
    struct json_object* response = NULL;
    
    if (( response = json_server_build_response( STATUS_OK, 0, "dumped shield." )) == NULL ) {
        json_object_put( json_array );
        return errlog_null( ERR_CRITICAL, "json_server_build_response\n" );
    }

    if ( json_object_utils_add( response, "shield", json_array ) < 0 ) {
        json_object_put( json_array );
        json_object_put( response );
        return errlog_null( ERR_CRITICAL, "json_object_utils_add\n" );
    }
    
    return response;
}

/* XXX This is not a good technique XXX */
extern int _update_score( barfight_trie_element_t element );
static int _dump_element( barfight_trie_element_t element, void *arg )
{
    struct json_object* json_array = NULL;
    struct json_object* json_child = NULL;

    if (( json_array = arg ) == NULL ) return errlogargs();
    
    if ( _update_score( element ) < 0 ) return errlog( ERR_CRITICAL, "_update_score\n" );

    if (( json_child = barfight_bouncer_debug_node_to_json( element )) == NULL ) {
        return errlog( ERR_CRITICAL, "barfight_bouncer_debug_node_to_json\n" );
    }
    
    if ( json_object_utils_array_add_object( json_array, json_child ) < 0 ) {
        return errlog( ERR_CRITICAL, "json_object_utils_array_add_object\n" );
    }

    return 0;
}

