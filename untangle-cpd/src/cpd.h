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
#define CPD_MAX_CAPTURE_RULES 2048
#define CPD_MAX_CLIENT_LENGTH  1024

typedef struct
{
    /* Non-zero if this capture rule is enabled. */
    int is_enabled;
    
    int capture;

    char client_address[CPD_MAX_CLIENT_LENGTH];
    char server_address[CPD_MAX_CLIENT_LENGTH];
    
    /* -1 for any interface, 0 - 7 otherwise */
    int client_interface;
    
    /* each day is 3 characters */
    char days[40];

    /* hh:mm */
    char start_time[10];
    char end_time[10];
} cpd_capture_rule_t;

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

    /* Capture Bypassed traffic */
    int capture_bypassed;

    /* Redirect https traffic */
    int redirect_https_enabled;

    /* Send them to the HTTPS page.*/
    int use_https_page;

    int capture_rules_length;

    cpd_capture_rule_t capture_rules[CPD_MAX_CAPTURE_RULES];
} cpd_config_t;

typedef struct
{
    /* This is the time that this status was reported. */
    struct timeval time;
    
    /* This is the number of hosts that are being tracked. */
    int num_hosts;
} cpd_status_t;


typedef struct
{
    char u[CPD_MAX_USERNAME_LENGTH];
} cpd_host_database_username_t;

/* Initialize a configuration object */
cpd_config_t* cpd_config_malloc( void );
int cpd_config_init( cpd_config_t* config );
cpd_config_t* cpd_config_create( void );

/* Load a configuration */
int cpd_config_load_json( cpd_config_t* config, struct json_object* json_config );

/* Serialize back to JSON */
struct json_object* cpd_config_to_json( cpd_config_t* config );

#endif // __CPD_H_
