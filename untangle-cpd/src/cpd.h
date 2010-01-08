/*
 * Copyright (c) 2003-2009 Untangle, Inc.
 * All rights reserved.
 *
 * This software is the confidential and proprietary information of
 * Untangle, Inc. ("Confidential Information"). You shall
 * not disclose such Confidential Information.
 *
 * $Id$
 */

#ifndef __CPD_H_
#define __CPD_H_


#include <arpa/inet.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <netinet/in.h>
#include <net/if.h>
#include <json/json.h>
#include <netinet/ether.h>

#define CPD_MAX_USERNAME_LENGTH  255

typedef struct
{
    /* Non-zero if the CPD is enabled. */
    int is_enabled;

    /* Non zero if concurrent logins are allowed. */
    int concurrent_logins;

    /* IDLE Timeout (after this many seconds without traffic an IP / MAC combination is removed */
    int idle_timeout_s;

    /* Maximum Session length.  After this many seconds, the IP / MAC combination is removed,
     * regardless of whether or not it has been idle. */
    int max_session_length_s;

    /* How often to expire old sessions in seconds. */
    int expiration_frequency_s;
} cpd_config_t;

typedef struct
{
    /* This is the time that this status was reported. */
    struct timeval time;
    
    /* This is the number of hosts that are being tracked. */
    int num_hosts;
} cpd_status_t;

/* Initialize a configuration object */
cpd_config_t* cpd_config_malloc( void );
int cpd_config_init( cpd_config_t* config );
cpd_config_t* cpd_config_create( void );

/* Load a configuration */
int cpd_config_load_json( cpd_config_t* config, struct json_object* json_config );

/* Serialize back to JSON */
struct json_object* cpd_config_to_json( cpd_config_t* config );

#endif // __CPD_H_
