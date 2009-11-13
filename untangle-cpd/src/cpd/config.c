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

#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>

#include <mvutil/debug.h>
#include <mvutil/errlog.h>

#include "json/object_utils.h"
#include "json/serializer.h"

#include "cpd.h"

static int _verify_config( cpd_config_t* config );

static json_serializer_t _config_serializer = {
    .name = "config",
    .fields = {{
            .name = "enabled",
            .fetch_arg = 1,
            .if_empty = JSON_SERIALIZER_FIELD_EMPTY_ERROR,
            .to_c = json_serializer_to_c_boolean,
            .to_json = json_serializer_to_json_boolean,
            .arg = (void*)offsetof( cpd_config_t, is_enabled )
        },{
            .name = "concurrent_logins",
            .fetch_arg = 1,
            .if_empty = JSON_SERIALIZER_FIELD_EMPTY_ERROR,
            .to_c = json_serializer_to_c_boolean,
            .to_json = json_serializer_to_json_boolean,
            .arg = (void*)offsetof( cpd_config_t, concurrent_logins )
        },{
            .name = "idle_timeout",
            .fetch_arg = 1,
            .if_empty = JSON_SERIALIZER_FIELD_EMPTY_ERROR,
            .to_c = json_serializer_to_c_int,
            .to_json = json_serializer_to_json_int,
            .arg = (void*)offsetof( cpd_config_t, idle_timeout )
        },{
            .name = "max_session_length",
            .fetch_arg = 1,
            .if_empty = JSON_SERIALIZER_FIELD_EMPTY_ERROR,
            .to_c = json_serializer_to_c_int,
            .to_json = json_serializer_to_json_int,
            .arg = (void*)offsetof( cpd_config_t, max_session_length )
        }, JSON_SERIALIZER_FIELD_TERM}
};

cpd_config_t* cpd_config_malloc( void )
{
    cpd_config_t* config = NULL;

    if (( config = calloc( 1, sizeof( cpd_config_t ))) == NULL ) return errlogmalloc_null();

    return config;
}

int cpd_config_init( cpd_config_t* config )
{
    if ( config == NULL ) return errlogargs();

    bzero( config, sizeof( cpd_config_t ));
    
    return 0;
}

cpd_config_t* cpd_config_create()
{
    cpd_config_t* config = NULL;
    
    if (( config = cpd_config_malloc()) == NULL ) {
        return errlog_null( ERR_CRITICAL, "cpd_config_malloc\n" );
    }

    if ( cpd_config_init( config ) < 0 ) {
        return errlog_null( ERR_CRITICAL, "cpd_config_init\n" );
    }

    return config;
}

int cpd_config_load_json( cpd_config_t* config, struct json_object* json_config )
{
    if ( config == NULL ) return errlogargs();
    if ( json_config == NULL ) return errlogargs();

    bzero( config, sizeof( cpd_config_t ));

    if ( json_serializer_to_c( &_config_serializer, json_config, config ) < 0 ) {
        return errlog( ERR_CRITICAL, "json_serializer_to_c\n" );
    }

    return 0;
}

struct json_object* cpd_config_to_json( cpd_config_t* config )
{
    if ( config == NULL ) return errlogargs_null();
    
    struct json_object* json_object = NULL;
    if (( json_object = json_serializer_to_json( &_config_serializer, config )) == NULL ) {
        return errlog_null( ERR_CRITICAL, "json_serializer_to_json\n" );
    }

    return json_object;
}


