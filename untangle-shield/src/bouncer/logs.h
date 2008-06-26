/*
 * $HeadURL: svn://chef/work/src/libnetcap/src/barfight_sched.h $
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

#ifndef __BARFIGHT_BOUNCER_LOGS_H_
#define __BARFIGHT_BOUNCER_LOGS_H_

#include <pthread.h>

#include <net/if.h>

#include <mvutil/hash.h>
#include <mvutil/list.h>

#include "bouncer/shield.h"
#include "json/object_utils.h"

/* This is the number of interfaces to track for an individual IP,
 * typically they shouldn't jump around that much. */
#define BARFIGHT_BOUNCER_LOGS_INTERFACE_COUNT 3

#define BARFIGHT_BOUNCER_LOGS_PROTOCOL_COUNT 256

typedef struct
{
    int resets;       /* Total number of resets in this time period */
    int dropped;      /* Total number of dropped requests in this time period */    
    int limited;      /* Total number of requests given limited access */
    int accepted;     /* Total number of accepted requests given limited access */
    int errors;       /* Total number of accepted requests given limited access */
    int totals;       /* Totals */
} barfight_bouncer_logs_action_counters_t;

typedef struct
{
    /* This is the highest reputation over the period. */
    double max_reputation;
    char if_names[BARFIGHT_BOUNCER_LOGS_INTERFACE_COUNT][IF_NAMESIZE];
    barfight_bouncer_logs_action_counters_t counters[BARFIGHT_BOUNCER_LOGS_INTERFACE_COUNT];
} barfight_bouncer_logs_user_stats_t;

typedef struct
{
    /* wasteful, but not really that big a deal. */
    barfight_bouncer_logs_action_counters_t protocol_counters[BARFIGHT_BOUNCER_LOGS_PROTOCOL_COUNT];
} barfight_bouncer_logs_global_stats_t;

typedef struct
{
    /* Unique identifier, not really all that useful */
    int id;

    /* Grab this mutex to prevent overwriting or deleting stats that are being accessed. */
    pthread_mutex_t mutex;

    /* when these starts started logging. */
    struct timeval start_time;

    /* when these starts stopped logging. */
    struct timeval end_time;

    /* all of the aggregate stats by protocol */
    barfight_bouncer_logs_global_stats_t global;

    struct {
        int relaxed;
        int lax;
        int tight;
        int closed;
    } mode_counters;

    /* Hash mapping an IP to user stats */
    ht_t user;
} barfight_bouncer_logs_iteration_t;

typedef struct
{
    /* Grab this mutex in order to advance to the next mutex. */
    pthread_mutex_t mutex;

    /* The amount of time in milliseconds to wait in milliseconds */
    int advance_timeout;

    /* logs are a circular array, which can be advanced.  this is the
     * index of the current log */
    list_node_t* current_item;
        
    /* Use a linked list to represent the circular logs */
    list_t logs;
} barfight_bouncer_logs_t;


/**
 * Allocate memory to store a logs structure.
 */
barfight_bouncer_logs_t* barfight_bouncer_logs_malloc( void );

/**
 * @param size Initial size of the circular buffer for the logs.
 */
int barfight_bouncer_logs_init( barfight_bouncer_logs_t* logs, int size );

/**
 * @param size Initial size of the circular buffer for the logs.
 */
barfight_bouncer_logs_t* barfight_bouncer_logs_create( int size );

void barfight_bouncer_logs_raze( barfight_bouncer_logs_t* logs );
void barfight_bouncer_logs_destroy( barfight_bouncer_logs_t* logs );
void barfight_bouncer_logs_free( barfight_bouncer_logs_t* logs );

/**
 * Log an event.
 * @param client The client this event is for.
 * @param if_name The interface the event occurred on.
 * @param protocol The protocol of the event.
 * @param action The action taken against the client.
 * @param reputation The current reputation of the user, the max is kept.
 */
int barfight_bouncer_logs_add( barfight_bouncer_logs_t* logs, struct in_addr client, char* if_name,
                               u_int8_t protocol, barfight_shield_response_t *response );

int barfight_bouncer_logs_add_mode( barfight_bouncer_logs_t* logs, barfight_shield_mode_t mode );

/**
 * Advance the circular buffer to the next iteration.
 */
int barfight_bouncer_logs_advance( barfight_bouncer_logs_t* logs );

/**
 * Task to automatically advance the log pointer, and then reschedule itself.
 * @param logs Logs to advance, passed in as a void* so it can used
 * directly in the scheduler.
 */
void barfight_bouncer_logs_sched_advance( void* arg );

int barfight_bouncer_logs_set_rotate_delay( barfight_bouncer_logs_t* logs, int timeout );

/**
 * Convert from logs to JSON.
 * @param logs log object.
 * @param start_time, if non-null only present logs after start_time.
 * @param ignore_accept_only if non-zero, do not add entries for IPs that only have accept events.
 */
struct json_object* barfight_bouncer_logs_to_json( barfight_bouncer_logs_t* logs, 
                                                   struct timeval* start_time, int ignore_accept_only );

#endif // __BARFIGHT_BOUNCER_LOGS_H_
