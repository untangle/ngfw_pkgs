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

#ifndef __JSON_SERVER_H
#define __JSON_SERVER_H

#include <mvutil/hash.h>
#include <json/json.h>

/* A mapping between a function name and the function to call */
typedef struct
{
    char* name;
    /* A function should take an object and then return a new json
     * object as the response.  The response and request is
     * automatically freed at the end of the session, and the function
     * should never hold onto a reference to it. */
    struct json_object* (*function)( struct json_object* request );
} json_server_function_entry_t;

typedef struct json_server
{
    /* Register this as the handler when starting the microhttpd server (do not modify this value) */
    int (*handler)( void *cls, struct MHD_Connection *connection,
                    const char *url, const char *method, const char *version,
                    const char *upload_data, unsigned int *upload_data_size, void **ptr );
    
    /* This is a hash of the available functions */
    ht_t call_table;

    /* Function to send an error back to the client, this is defaults
     * to one a function that just sends the error back as a
     * string. */
    int (*send_error)( struct json_server*, struct MHD_Connection *connection, 
                       const char *url, const char *method, const char *version, char* error_msg );

    /* Generic pointer to be customized by the application.  This is
     * shared between all sessions */
    void *app_data;
} json_server_t;

json_server_t* json_server_malloc( void );
int            json_server_init( json_server_t* json_server, json_server_function_entry_t* call_table );
json_server_t* json_server_create( json_server_function_entry_t* call_table );

void           json_server_free( json_server_t* json_server );
void           json_server_destroy( json_server_t* json_server );
void           json_server_raze( json_server_t* json_server );

struct json_object* json_server_build_response( int status, size_t buffer_size, char* fmt, ... );

#endif // #ifndef __JSON_SERVER_H
