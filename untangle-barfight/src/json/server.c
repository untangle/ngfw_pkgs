/*
 * $HeadURL: svn://chef/work/src/libnetcap/src/netcap_shield.c $
 * Copyright (c) 2003-2007 Untangle, Inc. 
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

#include <unistd.h>
#include <strings.h>

#include <stdarg.h>
#include <stdlib.h>

#include <microhttpd.h>

#include <pthread.h>

#include <mvutil/debug.h>
#include <mvutil/errlog.h>

#include "json/server.h"
#include "json/object_utils.h"

#define POST_PROCESS_SIZE 2048
#define JSON_REQUEST_PARAM "json_request"
#define JSON_REQUEST_FUNCTION "function"

#define DEFAULT_RESPONSE_BUFFER_SIZE 1024

typedef struct 
{
    struct MHD_PostProcessor *post_processor;
    struct json_tokener* tokener;
    /* This is the object that was requested. */
    struct json_object* request;
    json_server_t* json_server;
} _session_data_t;

static int _handler ( void *arg, struct MHD_Connection *connection,
                      const char *url, const char *method, const char *version,
                      const char *upload_data, unsigned int *upload_data_size, void **ptr );

static int _post_data_iterator( void *arg, enum MHD_ValueKind kind,
                                const char *key, const char *filename,
                                const char *content_type, const char *transfer_encoding,
                                const char *data, size_t off, size_t size );

static _session_data_t* _session_data_create( struct MHD_Connection *connection, 
                                              json_server_t* json_server );
static int _session_data_raze( _session_data_t* session_data );

/* This is the default error message builder */
static int _default_send_error( struct json_server*, struct MHD_Connection *connection, const char *url,
                                const char *method, const char *version, char* error_msg );

/* Retrieve the json_server that corresponds to this connection, and
 * make sure that it is actually a json_server pointer */
static json_server_t* _get_json_server( void* arg );

/** Execute a JSON request, returning the desired JSON object. */
static struct json_object* _execute_request( struct json_server* json_server, 
                                             struct json_object* request );

/** Given a JSON object, create response for microhttpd */
static struct MHD_Response* _build_response( struct json_object* response );

json_server_t* json_server_malloc( void )
{
    json_server_t* json_server = malloc( sizeof( json_server_t ));

    if ( json_server == NULL ) {
        errno = ENOMEM;
        return errlogmalloc_null ();
    }

    return json_server;
}

int            json_server_init( json_server_t* json_server, json_server_function_entry_t* call_table )
{
    int call_table_size = 0;
    int c = 0;

    if ( json_server == NULL || call_table == NULL ) return errlogargs();

    bzero( json_server, sizeof( json_server_t ));
    
    json_server->handler = _handler;

    while ( call_table[call_table_size].name != NULL ) call_table_size++;
    
    /* Initialize the hash table */
    if ( ht_init( &json_server->call_table, call_table_size, string_hash_func, string_equ_func, HASH_FLAG_FREE_KEY | HASH_FLAG_FREE_CONTENTS ) < 0 ) {
        return errlog( ERR_CRITICAL, "ht_init\n" );
    }

    /* Iterate each entry in the call table and add it to the hash */
    for ( c = 0 ; c < call_table_size ; c++ ) {
        /* Create a copy in case the entrie were created on a stack. */
        json_server_function_entry_t* entry = malloc( sizeof( json_server_function_entry_t ));
        if ( entry == NULL ) return errlogmalloc();
        entry->name = strdup( call_table[c].name ); 
        entry->function = call_table[c].function;

        if ( ht_add( &json_server->call_table, entry->name, entry ) < 0 ) {
            return errlog( ERR_CRITICAL, "ht_add %s\n", call_table[c].name );
        }
    }

    json_server->send_error = _default_send_error;
    
    return 0;
}

json_server_t* json_server_create( json_server_function_entry_t* call_table )
{
    if ( call_table == NULL ) return errlogargs_null();
    
    json_server_t* json_server;

    if (( json_server = json_server_malloc()) == NULL ) {
        return errlog_null( ERR_CRITICAL, "json_server_malloc\n" );
    }

    if ( json_server_init( json_server, call_table ) < 0 ) {
        return errlog_null( ERR_CRITICAL, "json_server_init\n" );
    }

    return json_server;
}

void           json_server_free( json_server_t* json_server )
{
    if ( json_server == NULL ) {
        errlogargs();
        return;
    }
    
    free( json_server );
}


void           json_server_destroy( json_server_t* json_server )
{
    if ( json_server == NULL ) {
        errlogargs();
        return;
    }

    ht_destroy( &json_server->call_table );

    bzero( json_server, sizeof( json_server_t ));    
}

void           json_server_raze( json_server_t* json_server )
{
    json_server_destroy( json_server );
    json_server_free( json_server );
}

struct json_object* json_server_build_response( int status, size_t buffer_size, char* fmt, ... )
{
    if ( buffer_size == 0 ) buffer_size = DEFAULT_RESPONSE_BUFFER_SIZE;

    if ( fmt == NULL ) return errlogargs_null();

    /* amazed this works. */
    char buffer[buffer_size];
    
    va_list argptr;
    
    va_start( argptr, fmt );
    vsnprintf( buffer, buffer_size, fmt, argptr );
    va_end( argptr );

    struct json_object* response = json_object_new_object();
    if ( response == NULL ) return errlog_null( ERR_CRITICAL, "json_object_new_object\n" );

    
    if ( json_object_utils_add( response, "status", json_object_new_int( status )) < 0 ) {
        return errlog_null( ERR_CRITICAL, "json_object_utils_add\n" );
    }
    
    if ( json_object_utils_add( response, "message", json_object_new_string( buffer )) < 0 ) {
        return errlog_null( ERR_CRITICAL, "json_object_utils_add\n" );
    }

    return response;
}

static int _handler ( void *arg, struct MHD_Connection *connection,
                      const char *url, const char *method, const char *version,
                      const char *upload_data, unsigned int *upload_data_size, void **ptr )
{
    _session_data_t *sd;

    int ret;

    json_server_t* json_server;

    if (( json_server = _get_json_server( arg )) == NULL ) {
        errlog( ERR_CRITICAL, "_get_json_server\n" );
        return MHD_NO;
    }

    /* Have to specify the request as a POST */
    if ( 0 != strncmp( method, MHD_HTTP_METHOD_POST, sizeof( MHD_HTTP_METHOD_POST ))) return MHD_NO;

    if (( sd = *ptr ) == NULL ) {
        if (( sd = _session_data_create( connection, json_server )) == NULL ) {
            errlog( ERR_CRITICAL, "_session_data_create\n" );
            return MHD_NO;
        }
        
        *ptr = sd;
        return MHD_YES;
    }
    
    if ( MHD_post_process( sd->post_processor, upload_data, *upload_data_size ) != MHD_YES ) {
        errlog( ERR_CRITICAL, "MHD_post_process\n" );
        _session_data_raze( sd );
        *ptr = NULL;
        return MHD_NO;
    }
    
    /* Check to see if there is more data to process. */
    if ( *upload_data_size != 0 ) {
        *upload_data_size = 0;
        return MHD_YES;
    }

    /* Call the function in order to generate the request */
    if ( sd->request == NULL ) {
        _session_data_raze( sd );
        return json_server->send_error( json_server, connection, url, method, version, 
                                        "Missing request parameter." );
    }

    struct json_object* json_response;
    struct MHD_Response *response;

    if (( json_response = _execute_request( json_server, sd->request )) == NULL ) {
        _session_data_raze( sd );
        return json_server->send_error( json_server, connection, url, method, version,
                                        "_execute_request" );
    }

    /* No longer need the session data */
    _session_data_raze( sd );

    /* convert the json object to a string and build a response from it. */
    if (( response = _build_response( json_response)) == NULL ) {
        /* Destroy the response object */
        json_object_put( json_response );

        return json_server->send_error( json_server, connection, url, method, version,
                                        "_build_response" ); 
    }

    /* done processing the data */
    ret = MHD_queue_response( connection, MHD_HTTP_OK, response );
    MHD_destroy_response( response );

    /* Destroy the response object */
    json_object_put( json_response );

    return ret;
}

static int _post_data_iterator( void *arg, enum MHD_ValueKind kind,
                                const char *key, const char *filename,
                                const char *content_type, const char *transfer_encoding,
                                const char *data, size_t off, size_t size )
{
    json_server_t* json_server;
    _session_data_t* sd;

    if (( sd = arg ) == NULL ) {
        errlogargs();
        return MHD_NO;
    }

    if (( json_server = _get_json_server( sd->json_server )) == NULL ) {
        errlog( ERR_CRITICAL, "_get_json_server\n" );
        return MHD_NO;
    }

    /* Ignoring all of the parameters besides the request parameter */
    if (( strncmp( JSON_REQUEST_PARAM, key, sizeof( JSON_REQUEST_PARAM ))) != 0 ) return MHD_YES;

    if ( sd->request != NULL ) {
        errlog( ERR_CRITICAL, "JSON Request object has already been parsed, ignoring second pass\n" );
        return MHD_YES;
    }

    /* If necessary build a tokenizer */
    if ( sd->tokener == NULL ) {
        if (( sd->tokener = json_tokener_new()) == NULL ) {
            errlog( ERR_CRITICAL, "json_tokener_new\n" );
            return MHD_NO;
        }
    }

    struct json_object* json;

    /* Parse the remaining data. */
    if (( json = json_tokener_parse_ex( sd->tokener, (char*)data, size )) == NULL ) {
        /* More data to parse, wait to read more */
        if ( sd->tokener->err == json_tokener_continue ) return MHD_YES;

        /* There was an error of some kind, discontinue processing. */
        errlog( ERR_WARNING, "Unable to parse the data [%d]\n", sd->tokener->err );
        return MHD_NO;
    }
    
    sd->request = json;
    
    debug( 7, "JSON_SERVER: key[%s] filename[%s] offset[%d] size[%d]\n", key, filename, off, size );    

    // errlog( ERR_WARNING, "data:\n----------------------\n%s----------------------\n", data );
    return MHD_YES;
}

static int _default_send_error( struct json_server* json_server, struct MHD_Connection *connection,
                                const char *url, const char *method, const char *version, 
                                char* error_msg )
{
    if ( error_msg == NULL ) {
        errlogargs();
        return MHD_NO;
    }

    struct MHD_Response* response;
    int ret;

    response = MHD_create_response_from_data( strlen( error_msg ), (void *)error_msg, MHD_NO, MHD_YES );
                                              
    if ( response == NULL ) {
        errlog( ERR_CRITICAL, "MHD_create_response_from_data\n" );
        return MHD_NO;
    }
    ret = MHD_queue_response ( connection, MHD_HTTP_BAD_REQUEST, response );
    MHD_destroy_response (response);
    
    return MHD_YES;
}

static _session_data_t* _session_data_create( struct MHD_Connection *connection, 
                                              json_server_t* json_server )
{
    _session_data_t* sd = NULL;

    if (( sd = calloc( 1, sizeof( _session_data_t ))) == NULL ) return errlogmalloc_null();
    sd->post_processor = MHD_create_post_processor( connection, POST_PROCESS_SIZE, 
                                                    _post_data_iterator, sd );

    if ( sd->post_processor == NULL ) {
        free( sd );
        sd = NULL;
        return errlog_null( ERR_CRITICAL, "MHD_create_post_processor\n" );
    }
    
    sd->json_server = json_server;
    
    return sd;
}

static int _session_data_raze( _session_data_t* session_data )
{
    if ( session_data == NULL ) return errlogargs();

    if ( session_data->post_processor != NULL ) {
        MHD_destroy_post_processor ( session_data->post_processor );
        session_data->post_processor = NULL;
    }

    /* Get rid of the tokener */
    if ( session_data->tokener != NULL ) {
        json_tokener_free( session_data->tokener );
        session_data->tokener = NULL;
    }

    /* Get rid of the json object */
    if ( session_data->request != NULL ) {
        json_object_put( session_data->request );
        session_data->request = NULL;
    }

    free( session_data );
    
    return 0;
}

static json_server_t* _get_json_server( void* arg )
{
    json_server_t* json_server = NULL;
    
    if (( json_server = (json_server_t*)arg ) == NULL ) {
        return errlog_null( ERR_CRITICAL, "json_server must be specified in start_daemon.\n" );
    }

    /* Just an additional check to make sure the correct object was passed. */
    if ( json_server->handler != _handler ) {
        return errlog_null( ERR_CRITICAL, "A valid json_server must be specified in start_daemon.\n" );
    }

    return json_server;
}

/** Execute a JSON request, returning the desired JSON object. */
static struct json_object* _execute_request( struct json_server* json_server, 
                                             struct json_object* request )
{
    if ( request == NULL ) return errlogargs_null();
    
    struct json_object* response = NULL;

    /* Retrieve the object from the request */
    struct json_object* fn_name = json_object_object_get( request, JSON_REQUEST_FUNCTION );

    if ( fn_name == NULL ) {
        response = json_object_new_object();
        json_object_object_add( response, "status", json_object_new_boolean( 0 ));
        json_object_object_add( response, "message", json_object_new_string( "Missing parameter '" JSON_REQUEST_FUNCTION "'." ));
        return response;
    }

    json_server_function_entry_t* fn_entry = ht_lookup( &json_server->call_table, 
                                                        json_object_get_string( fn_name ));
    if ( fn_entry == NULL ) {
        char buffer[256];
        snprintf( buffer, sizeof( buffer ), "The function '%s' is not available", json_object_get_string( fn_name ));
        response = json_object_new_object();
        json_object_object_add( response, "status", json_object_new_boolean( 0 ));
        json_object_object_add( response, "message", json_object_new_string( buffer ));
        return response;
    }
    
    if ( fn_entry->function == NULL ) {
        char buffer[256];
        snprintf( buffer, sizeof( buffer ), "The function '%s' is invalid", json_object_get_string( fn_name ));
        response = json_object_new_object();
        json_object_object_add( response, "status", json_object_new_boolean( 0 ));
        json_object_object_add( response, "message", json_object_new_string( buffer ));
        return response;
    }
    
    if (( response = fn_entry->function( request )) == NULL ) {
        char buffer[256];
        snprintf( buffer, sizeof( buffer ), "Error executing '%s'.", json_object_get_string( fn_name ));
        response = json_object_new_object();
        json_object_object_add( response, "status", json_object_new_boolean( 0 ));
        json_object_object_add( response, "message", json_object_new_string( buffer ));
        return response;        
    }

    return response;
}

   
/** Given a JSON object, create response for microhttpd */
static struct MHD_Response* _build_response( struct json_object* json )
{
    struct MHD_Response* response = NULL;
    
    if ( json == NULL ) return errlogargs_null();
    char* response_string = json_object_to_json_string( json );
    
    if ( response_string == NULL ) return errlog_null( ERR_CRITICAL, "json_object_to_json_string\n" );
        
    response = MHD_create_response_from_data( strlen( response_string ), (void*)response_string,
                                              MHD_YES, MHD_YES );

    if ( response == NULL ) return errlog_null( ERR_CRITICAL, "MHD_create_response_from_data\n" );
    return response;
}

