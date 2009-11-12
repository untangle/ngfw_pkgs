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

#include <stdio.h>
#include <stdlib.h>
#include <stddef.h>

#include <mvutil/debug.h>
#include <mvutil/errlog.h>

#include "json/object_utils.h"
#include "json/serializer.h"

#include "cpd.h"
#include "cpd/status.h"

static json_serializer_t _status_serializer = {
    .name = "status",
    .fields = {{
            .name = "time",
            .fetch_arg = 1,
            .if_empty = JSON_SERIALIZER_FIELD_EMPTY_ERROR,
            .to_c = json_serializer_to_c_timeval,
            .to_json = json_serializer_to_json_timeval,
            .arg = (void*)offsetof( cpd_status_t, time )
        },{
            .name = "num_hosts",
            .fetch_arg = 1,
            .if_empty = JSON_SERIALIZER_FIELD_EMPTY_ERROR,
            .to_c = json_serializer_to_c_int,
            .to_json = json_serializer_to_json_int,
            .arg = (void*)offsetof( cpd_status_t, num_hosts )
        }, JSON_SERIALIZER_FIELD_TERM }
};

cpd_status_t* cpd_status_malloc( void )
{
    cpd_status_t* status = NULL;
    if (( status = calloc( 1, sizeof( cpd_status_t ))) == NULL ) {
        return errlogmalloc_null();
    }

    return status;
}

int cpd_status_init( cpd_status_t* status )
{
    if ( status == NULL ) return errlogargs();

    bzero( status, sizeof( cpd_status_t ));
    
    return 0;
}

cpd_status_t* cpd_status_create( void )
{
    cpd_status_t* status = NULL;
    
    if (( status = cpd_status_malloc()) == NULL ) {
        return errlog_null( ERR_CRITICAL, "cpd_status_malloc\n" );
    }

    if ( cpd_status_init( status ) < 0 ) {
        free( status );
        return errlog_null( ERR_CRITICAL, "cpd_status_init\n" );
    }

    return status;
}

int cpd_status_free( cpd_status_t* status )
{
    if ( status == NULL ) return errlogargs();
    free( status );
    return 0;
}

int cpd_status_destroy( cpd_status_t* status )
{
    if ( status == NULL ) return errlogargs();

    bzero( status, sizeof( cpd_status_t ));

    return 0;
}

int cpd_status_raze( cpd_status_t* status )
{
    cpd_status_destroy( status );
    cpd_status_free( status );

    return 0;
}

int cpd_status_load_json( cpd_status_t* status,
                                   struct json_object* json_status )
{
    if ( status == NULL ) return errlogargs();
    if ( json_status == NULL ) return errlogargs();

    if ( json_serializer_to_c( &_status_serializer, json_status, status ) < 0 ) {
        return errlog( ERR_CRITICAL, "json_serializer_to_c\n" );
    }

    return 0;
}

struct json_object* cpd_status_to_json( cpd_status_t* status )
{
    if ( status == NULL ) return errlogargs_null();
    
    struct json_object* json_object = NULL;
    if (( json_object = json_serializer_to_json( &_status_serializer, status )) == NULL ) {
        return errlog_null( ERR_CRITICAL, "json_serializer_to_json\n" );
    }

    return json_object;
}


