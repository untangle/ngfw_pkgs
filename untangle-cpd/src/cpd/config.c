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

static json_serializer_string_t _client_address_string = {
    .offset = offsetof( cpd_capture_rule_t, client_address ),
    .len = sizeof((( cpd_capture_rule_t *)0)->client_address )
};

static json_serializer_string_t _server_address_string = {
    .offset = offsetof( cpd_capture_rule_t, server_address ),
    .len = sizeof((( cpd_capture_rule_t *)0)->server_address )
};

static json_serializer_string_t _days_string = {
    .offset = offsetof( cpd_capture_rule_t, days ),
    .len = sizeof((( cpd_capture_rule_t *)0)->days )
};

static json_serializer_string_t _start_time_string = {
    .offset = offsetof( cpd_capture_rule_t, start_time ),
    .len = sizeof((( cpd_capture_rule_t *)0)->start_time )
};

static json_serializer_string_t _end_time_string = {
    .offset = offsetof( cpd_capture_rule_t, end_time ),
    .len = sizeof((( cpd_capture_rule_t *)0)->end_time )
};



static json_serializer_t _capture_rule_serializer = {
    .name = "config",
    .fields = {{
            .name = "enabled",
            .fetch_arg = 1,
            .if_empty = JSON_SERIALIZER_FIELD_EMPTY_ERROR,
            .to_c = json_serializer_to_c_boolean,
            .to_json = json_serializer_to_json_boolean,
            .arg = (void*)offsetof( cpd_capture_rule_t, is_enabled )
        },{
            .name = "capture",
            .fetch_arg = 1,
            .if_empty = JSON_SERIALIZER_FIELD_EMPTY_ERROR,
            .to_c = json_serializer_to_c_boolean,
            .to_json = json_serializer_to_json_boolean,
            .arg = (void*)offsetof( cpd_capture_rule_t, capture )
        },{
            .name = "client_address",
            .fetch_arg = 1,
            .if_empty = JSON_SERIALIZER_FIELD_EMPTY_ERROR,
            .to_c = json_serializer_to_c_string,
            .to_json = json_serializer_to_json_string,
            .arg = &_client_address_string
        },{
            .name = "server_address",
            .fetch_arg = 1,
            .if_empty = JSON_SERIALIZER_FIELD_EMPTY_ERROR,
            .to_c = json_serializer_to_c_string,
            .to_json = json_serializer_to_json_string,
            .arg = &_server_address_string
        },{
            .name = "client_interface",
            .fetch_arg = 1,
            .if_empty = JSON_SERIALIZER_FIELD_EMPTY_ERROR,
            .to_c = json_serializer_to_c_int,
            .to_json = json_serializer_to_json_int,
            .arg = (void*)offsetof( cpd_capture_rule_t, client_interface)
        },{
            .name = "days",
            .fetch_arg = 1,
            .if_empty = JSON_SERIALIZER_FIELD_EMPTY_ERROR,
            .to_c = json_serializer_to_c_string,
            .to_json = json_serializer_to_json_string,
            .arg = &_days_string
        },{
            .name = "start_time",
            .fetch_arg = 1,
            .if_empty = JSON_SERIALIZER_FIELD_EMPTY_ERROR,
            .to_c = json_serializer_to_c_string,
            .to_json = json_serializer_to_json_string,
            .arg = &_start_time_string
        },{
            .name = "end_time",
            .fetch_arg = 1,
            .if_empty = JSON_SERIALIZER_FIELD_EMPTY_ERROR,
            .to_c = json_serializer_to_c_string,
            .to_json = json_serializer_to_json_string,
            .arg = &_end_time_string
        }, JSON_SERIALIZER_FIELD_TERM}
};

static int _capture_rules_array_get_size( void *c_array );

static json_serializer_array_t _capture_rules_array_arg =
{
    .max_length = CPD_MAX_CAPTURE_RULES,
    .data_offset = offsetof( cpd_config_t, capture_rules ),
    .length_offset = offsetof( cpd_config_t, capture_rules_length ),
    .get_size = _capture_rules_array_get_size,
    .default_value = NULL,
    .serializer = &_capture_rule_serializer,
    .item_size = sizeof( cpd_capture_rule_t ),
    .is_pointers = 0
};

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
            .name = "redirect_https_enabled",
            .fetch_arg = 1,
            .if_empty = JSON_SERIALIZER_FIELD_EMPTY_ERROR,
            .to_c = json_serializer_to_c_boolean,
            .to_json = json_serializer_to_json_boolean,
            .arg = (void*)offsetof( cpd_config_t, redirect_https_enabled )
        },{
            .name = "use_https_page",
            .fetch_arg = 1,
            .if_empty = JSON_SERIALIZER_FIELD_EMPTY_ERROR,
            .to_c = json_serializer_to_c_boolean,
            .to_json = json_serializer_to_json_boolean,
            .arg = (void*)offsetof( cpd_config_t, use_https_page )
        },{
            .name = "capture_bypassed_traffic",
            .fetch_arg = 1,
            .if_empty = JSON_SERIALIZER_FIELD_EMPTY_ERROR,
            .to_c = json_serializer_to_c_boolean,
            .to_json = json_serializer_to_json_boolean,
            .arg = (void*)offsetof( cpd_config_t, capture_bypassed )
        },{
            .name = "idle_timeout_s",
            .fetch_arg = 1,
            .if_empty = JSON_SERIALIZER_FIELD_EMPTY_ERROR,
            .to_c = json_serializer_to_c_int,
            .to_json = json_serializer_to_json_int,
            .arg = (void*)offsetof( cpd_config_t, idle_timeout_s )
        },{
            .name = "timeout_s",
            .fetch_arg = 1,
            .if_empty = JSON_SERIALIZER_FIELD_EMPTY_ERROR,
            .to_c = json_serializer_to_c_int,
            .to_json = json_serializer_to_json_int,
            .arg = (void*)offsetof( cpd_config_t, max_session_length_s )
        },{
            .name = "expiration_frequency_s",
            .fetch_arg = 1,
            .if_empty = JSON_SERIALIZER_FIELD_EMPTY_ERROR,
            .to_c = json_serializer_to_c_int,
            .to_json = json_serializer_to_json_int,
            .arg = (void*)offsetof( cpd_config_t, expiration_frequency_s )
        },{
            .name = "capture_rules",
            .fetch_arg = 1,
            .if_empty = JSON_SERIALIZER_FIELD_EMPTY_ERROR,
            .to_c = json_serializer_to_c_array,
            .to_json = json_serializer_to_json_array,
            .arg = &_capture_rules_array_arg
        }, JSON_SERIALIZER_FIELD_TERM}
};

static cpd_config_t _default_config = 
{
    .is_enabled = 0,

    .concurrent_logins = 1,
    /* 10 minute timeout by default */
    .idle_timeout_s = 10 * 60,

    /* 60 minute session timeout by default */
    .max_session_length_s = 60 * 60,

    /* Expire sessions once a minute */
    .expiration_frequency_s = 60,
    
    .capture_rules_length = 0    
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

    memcpy( config, &_default_config, sizeof( _default_config ));

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

static int _capture_rules_array_get_size( void *c_array )
{
    return sizeof((( cpd_config_t *)0)->capture_rules );
}



