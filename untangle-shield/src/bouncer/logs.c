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

#include  <net/if.h>

#include <mvutil/debug.h>
#include <mvutil/errlog.h>
#include <mvutil/unet.h>
#include <mvutil/utime.h>

#include "bouncer/logs.h"
#include "bouncer/shield.h"

#include "utils/sched.h"

#include "json/object_utils.h"

/* Default timeout for logs if they are scheduled to automatically advance */
#define _DEFAULT_ADVANCE_TIMEOUT 10000

#define _USER_HASH_SIZE 727

/* No need for locks, this is locked outside */
#define _USER_HASH_FLAGS HASH_FLAG_FREE_CONTENTS | HASH_FLAG_KEEP_LIST | HASH_FLAG_NO_LOCKS

static char *_json_action_keys[] = {
    "identifier", "resets", "drop", "limited", "accepted", "errors", ""
};

static char *unknown_interface = "unknown";

static int _user_log_event( barfight_bouncer_logs_user_stats_t *user_stats, 
                            barfight_shield_response_t* response, char* if_name );

static int _global_log_event( barfight_bouncer_logs_global_stats_t *global_stats, 
                              barfight_shield_ans_t action, u_int8_t protocol );

static int _logs_action_counters_add( barfight_bouncer_logs_action_counters_t *counter, 
                                      barfight_shield_ans_t action );

static barfight_bouncer_logs_iteration_t* _get_current_iteration( barfight_bouncer_logs_t* logs );

static struct json_object* _build_json_key( void );
static struct json_object* _build_json_iteration( barfight_bouncer_logs_iteration_t* iteration,
                                                  int ignore_accept_only );

static struct json_object* _build_json_iteration_globals( barfight_bouncer_logs_iteration_t* iteration );
static struct json_object* _build_json_iteration_mode( barfight_bouncer_logs_iteration_t* iteration );
static struct json_object* _build_json_iteration_user( barfight_bouncer_logs_iteration_t* iteration,
                                                       int ignore_accept_only );

static int _build_json_action_counters( struct json_object* counters_json,
                                        barfight_bouncer_logs_action_counters_t *counters );

/**
 * Allocate memory to store a logs structure.
 */
barfight_bouncer_logs_t* barfight_bouncer_logs_malloc( void )
{
    barfight_bouncer_logs_t* logs = NULL;
    
    if (( logs = calloc( 1, sizeof( barfight_bouncer_logs_t ))) == NULL ) return errlogmalloc_null();
    
    return logs;
}

/**
 * @param size Initial size of the circular buffer for the logs.
 */
int barfight_bouncer_logs_init( barfight_bouncer_logs_t* logs, int size )
{
    if ( logs == NULL ) return errlogargs();
    if ( size <= 2 ) return errlogargs();

    bzero( logs, sizeof( logs ));

    if ( pthread_mutex_init( &logs->mutex, NULL ) < 0 ) return perrlog( "pthread_mutex_init" );
    
    if ( list_init( &logs->logs, LIST_FLAG_CIRCULAR ) < 0 ) return errlog( ERR_CRITICAL, "list_init\n" );

    logs->advance_timeout = _DEFAULT_ADVANCE_TIMEOUT;
    
    int c = 0;
    barfight_bouncer_logs_iteration_t *log_iteration = NULL;

    for ( c =0 ; c < size ; c++ ) {
        if (( log_iteration = calloc( 1, sizeof( barfight_bouncer_logs_iteration_t ))) == NULL ) {
            return errlogmalloc();
        }
        
        if ( pthread_mutex_init( &log_iteration->mutex, NULL ) < 0 ) {
            return perrlog( "pthread_mutex_init" );
        }

        if ( ht_init( &log_iteration->user, _USER_HASH_SIZE, int_hash_func, int_equ_func, _USER_HASH_FLAGS ) < 0 ) {
            free( log_iteration );
            return errlog( ERR_CRITICAL, "ht_init\n" );
        }
        
        if ( list_add_tail( &logs->logs, log_iteration ) < 0 ) {
            free( log_iteration );
            return errlog( ERR_CRITICAL, "list_add_tail\n" );
        }
    }
    
    if ( barfight_bouncer_logs_advance( logs ) < 0 ) {
        return errlog( ERR_CRITICAL, "barfight_bouncer_logs_advance\n" );
    }
    return 0;
}

/**
 * @param size Initial size of the circular buffer for the logs.
 */
barfight_bouncer_logs_t* barfight_bouncer_logs_create( int size )
{
    barfight_bouncer_logs_t* logs = NULL;
        
    if (( logs = barfight_bouncer_logs_malloc()) == NULL ) {
        return errlog_null( ERR_CRITICAL, "barfight_bouncer_logs_malloc\n" );
    }

    if ( barfight_bouncer_logs_init( logs, size ) < 0 ) {
        barfight_bouncer_logs_raze( logs );
        return errlog_null( ERR_CRITICAL, "barfight_bouncer_logs_init\n" );
    }
    
    return logs;
}
   

void barfight_bouncer_logs_raze( barfight_bouncer_logs_t* logs )
{
    barfight_bouncer_logs_destroy( logs );
    barfight_bouncer_logs_free( logs );
}

void barfight_bouncer_logs_destroy( barfight_bouncer_logs_t* logs )
{
    if ( logs == NULL ) {
        errlogargs();
        return;
    }
    
    if ( pthread_mutex_destroy( &logs->mutex ) < 0 ) perrlog( "pthread_mutex_destroy" );

    barfight_bouncer_logs_iteration_t *log_iteration = NULL;
    
    int size = list_length( &logs->logs );
    int c = 0;
    for ( c = 0 ; c < size ;  c++ ) {
        log_iteration = NULL;
        if ( list_pop_head( &logs->logs, (void**)&log_iteration ) < 0 ) {
            errlog( ERR_CRITICAL, "list_pop_tail\n" );
            break;
        }

        if ( log_iteration == NULL ) {
            errlog( ERR_WARNING, "No more item after at %d only removing %d items.\n", c, size );
            break;
        }

        if ( ht_destroy( &log_iteration->user ) < 0 ) perrlog( "ht_destroy" );

        bzero( log_iteration, sizeof( barfight_bouncer_logs_iteration_t ));
        free( log_iteration );
    }

    bzero( logs, sizeof( barfight_bouncer_logs_t ));
}

void barfight_bouncer_logs_free( barfight_bouncer_logs_t* logs )
{
    if ( logs == NULL ) {
        errlogargs();
        return;
    }

    free( logs );
}

int barfight_bouncer_logs_add( barfight_bouncer_logs_t* logs, struct in_addr client, char* if_name,
                               u_int8_t protocol, barfight_shield_response_t *response )
{
    if ( logs == NULL ) return errlogargs();
    if ( response == NULL ) return errlogargs();

    barfight_bouncer_logs_iteration_t* iteration = _get_current_iteration( logs );
    
    if ( iteration == NULL ) return errlog( ERR_CRITICAL, "_get_current_logs\n" );

    if ( if_name == NULL ) if_name = unknown_interface;
    if ( if_name[0] == '\0' ) if_name = unknown_interface;

    int _critical_section() {
        /* Lookup the client in the hash */
        barfight_bouncer_logs_user_stats_t* user_stats = NULL;
        if (( user_stats = ht_lookup( &iteration->user, (void*)client.s_addr )) == NULL ) {
            if (( user_stats = calloc( 1, sizeof( barfight_bouncer_logs_user_stats_t ))) == NULL ) {
                return errlogmalloc();
            }

            if ( ht_add( &iteration->user, (void*)client.s_addr, user_stats ) < 0 ) {
                free( user_stats );
                return errlog( ERR_CRITICAL, "ht_add" );
            }
        }

        if ( _user_log_event( user_stats, response, if_name ) < 0 ) {
            return errlog( ERR_CRITICAL, "_user_log_event\n" );
        }

        if ( _global_log_event( &iteration->global, response->ans, protocol ) < 0 ) {
            return errlog( ERR_CRITICAL, "_global_log_event\n" );
        }

        return 0;
    }
    
    int ret = 0;
    if ( pthread_mutex_lock( &iteration->mutex ) < 0 ) return perrlog( "pthread_mutex_lock" );
    ret = _critical_section();
    if ( pthread_mutex_unlock( &iteration->mutex ) < 0 ) {
        return perrlog( "pthread_mutex_unlock" );
    }

    if ( ret < 0 ) return errlog( ERR_CRITICAL, "_critical_section\n" );
    
    return 0;
}

int barfight_bouncer_logs_add_mode( barfight_bouncer_logs_t* logs, barfight_shield_mode_t mode )
{
    barfight_bouncer_logs_iteration_t* iteration = _get_current_iteration( logs );
    
    if ( iteration == NULL ) return errlog( ERR_CRITICAL, "_get_current_logs\n" );
    
    int _critical_section() {
        switch ( mode ) {
        case NC_SHIELD_MODE_RELAXED:
            iteration->mode_counters.relaxed++;
            break;

        case NC_SHIELD_MODE_LAX:
            iteration->mode_counters.lax++;
            break;
            
        case NC_SHIELD_MODE_TIGHT:
            iteration->mode_counters.tight++;
            break;

        case NC_SHIELD_MODE_CLOSED:
            iteration->mode_counters.closed++;
            break;

        default:
            errlog( ERR_CRITICAL, "Invalid mode [%d]\n", mode );
        }
        
        return 0;
    }

    int ret = 0;
    if ( pthread_mutex_lock( &iteration->mutex ) < 0 ) return perrlog( "pthread_mutex_lock" );
    ret = _critical_section();
    if ( pthread_mutex_unlock( &iteration->mutex ) < 0 ) {
        return perrlog( "pthread_mutex_unlock" );
    }

    if ( ret < 0 ) return errlog( ERR_CRITICAL, "_critical_section\n" );
    
    return 0;
}


/**
 * Advance the circular buffer to the next iteration.
 */
int barfight_bouncer_logs_advance( barfight_bouncer_logs_t* logs )
{
    if ( logs == NULL ) return errlogargs();
    list_t* user_list = NULL;
    
    barfight_bouncer_logs_iteration_t *log_iteration = NULL;
    int _critical_section() {
        if ( logs->current_item == NULL ) {
            /* Use the tail, becaues advance is going to go to the next
             * item which in a ciruclar list will be the head. */
            if (( logs->current_item = list_tail( &logs->logs )) == NULL ) {
                return errlog( ERR_CRITICAL, "list_tail\n" );
            }
        }

        list_node_t* current_item = logs->current_item;

        /* Get the next item */
        list_node_t* next_item = NULL;
        if (( next_item = list_node_next( current_item )) == NULL ) {
            return errlog( ERR_CRITICAL, "list_node_next\n" );
        }
        
        if (( log_iteration = list_node_val( current_item )) == NULL ) {
            return errlog( ERR_CRITICAL, "list_node_val\n" );
        }
        
        if ( pthread_mutex_lock( &log_iteration->mutex ) < 0 ) return perrlog( "pthread_mutex_lock" );
        if ( gettimeofday( &log_iteration->end_time, NULL ) < 0 ) return perrlog( "gettimeofday" );
        if ( pthread_mutex_unlock( &log_iteration->mutex ) < 0 ) {
            return perrlog( "pthread_mutex_unlock" );
        }
        
        if (( log_iteration = list_node_val( next_item )) == NULL ) {
            return errlog( ERR_CRITICAL, "list_node_val\n" );
        }
        
        if ( pthread_mutex_lock( &log_iteration->mutex ) < 0 ) return perrlog( "pthread_mutex_lock" );
        
        /* clean it out */
        bzero( &log_iteration->global, sizeof( barfight_bouncer_logs_global_stats_t ));
        bzero( &log_iteration->mode_counters, sizeof( log_iteration->mode_counters ));
        bzero( &log_iteration->end_time, sizeof( struct timeval ));
        if ( gettimeofday( &log_iteration->start_time, NULL ) < 0 ) return perrlog( "gettimeofday" );
        
        if (( user_list = ht_get_key_list( &log_iteration->user )) == NULL ) {
            return errlog( ERR_CRITICAL, "ht_get_key_list\n" );
        }
        
        int length = list_length( user_list );
        in_addr_t ip;
        int c;
        for ( c = 0 ; c < length ; c++ ) {
            if ( list_pop_head( user_list, (void**)&ip ) < 0 ) {
                return errlog( ERR_CRITICAL, "list_pop_head\n" );
            }

            if ( ht_remove( &log_iteration->user, (void*)ip ) < 0 ) {
                return errlog( ERR_CRITICAL, "ht_remove\n" );
            }
        }

        logs->current_item = next_item;

        return 0;
    }
    
    int ret = -1;
    if ( pthread_mutex_lock( &logs->mutex ) < 0 ) return perrlog( "pthread_mutex_lock" );
    ret = _critical_section();
    if (( log_iteration != NULL ) && ( pthread_mutex_unlock( &log_iteration->mutex ) < 0 )) {
        perrlog( "pthread_mutex_unlock" );
    }
    if ( pthread_mutex_unlock( &logs->mutex ) < 0 ) return perrlog( "pthread_mutex_unlock" );
    
    if ( user_list != NULL ) {
        list_destroy( user_list );
        list_free( user_list );
    }
                                                        
    if ( ret < 0 ) return errlog( ERR_CRITICAL, "_critical_section\n" );
    return 0;
}

void barfight_bouncer_logs_sched_advance( void* arg )
{
    if ( arg == NULL ) {
        errlogargs();
        return;
    }

    barfight_bouncer_logs_t* logs = (barfight_bouncer_logs_t*)arg;
    
    debug( 10, "LOGS: Automatically advancing logs.\n" );
    
    if ( barfight_bouncer_logs_advance( logs ) < 0 ) {
        errlog( ERR_CRITICAL, "barfight_bouncer_logs_advance\n" );
        return;
    }

    if (( logs->advance_timeout > 0 ) && 
        ( barfight_sched_event( barfight_bouncer_logs_sched_advance, arg, 
                                MSEC_TO_USEC( logs->advance_timeout )) < 0 )) {
        errlog( ERR_CRITICAL, "barfight_sched_event\n" );
        return;
    }
}

/**
 * Change the delay for automatic log advancing.
 */
int barfight_bouncer_logs_set_rotate_delay( barfight_bouncer_logs_t* logs, int timeout )
{
    if ( logs == NULL ) return errlogargs();

    debug( 10, "LOGS: Setting log rotate delay to %d\n", timeout );
    
    logs->advance_timeout = timeout;
    
    return 0;
}

struct json_object* barfight_bouncer_logs_to_json( barfight_bouncer_logs_t* logs, 
                                                   struct timeval* start_time, int ignore_accept_only )
{
    if ( logs == NULL ) return errlogargs_null();
    
    struct json_object* json_logs = NULL;

    int _critical_section() {
        /* This is the array of results */
        struct json_object* json_logs_data = NULL;

        struct json_object* temp = NULL;
        
        list_node_t* list_node = logs->current_item;
        
        if ( list_node == NULL ) return errlog( ERR_CRITICAL, "The log list is not initialized.\n" );

        if (( json_logs_data = json_object_new_array()) == NULL ) {
            return errlog( ERR_CRITICAL, "json_object_new_array\n" );
        }
        
        if ( json_object_utils_add_object( json_logs, "data", json_logs_data ) < 0 ) {
            return errlog( ERR_CRITICAL, "json_object_utils_add_object\n" );
        }

        if (( temp = _build_json_key()) == NULL ) return errlog( ERR_CRITICAL, "_build_json_key\n" );
        if ( json_object_utils_add_object( json_logs, "key", temp ) < 0 ) {
            return errlog( ERR_CRITICAL, "json_object_utils_add_object\n" );
        }

        int length = list_length( &logs->logs );
        int c;
        barfight_bouncer_logs_iteration_t *log_iteration = NULL;
    
        for ( c = 0 ; c < length ; c++ ) {
            /* Start with the current node and move backwards */
            if (( log_iteration = list_node_val( list_node )) == NULL ) {
                return errlog( ERR_CRITICAL, "list_node_val\n" );
            }
            
            if ( log_iteration->start_time.tv_sec == 0 ) {
                debug( 10, "LOGS: Only %d entries are in the current logs.\n", c );
                break;
            }
            
            if ( start_time != NULL ) {
                debug( 10, "LOGS: Checking start_time %d > %d\n",
                       start_time->tv_sec, log_iteration->start_time.tv_sec );
                if ( start_time->tv_sec > log_iteration->start_time.tv_sec ) break;
                if (( start_time->tv_sec == log_iteration->start_time.tv_sec ) &&
                    ( start_time->tv_usec >= log_iteration->start_time.tv_usec )) break;
            }

            if (( temp = _build_json_iteration( log_iteration, ignore_accept_only )) == NULL ) {
                return errlog( ERR_CRITICAL, "_build_json_iteration\n" );
            }
            
            if ( json_object_array_add( json_logs_data, temp ) < 0 ) {
                return errlog( ERR_CRITICAL, "json_object_array\n" );
            }

            if (( list_node = list_node_prev( list_node )) == NULL ) {
                return errlog( ERR_CRITICAL, "list_node_prev\n" );
            }
        }

        return 0;
    }
    
    if (( json_logs = json_object_new_object()) == NULL ) {
        return errlog_null( ERR_CRITICAL, "json_object_new_object\n" );
    }

    if ( _critical_section() < 0 ) {
        json_object_put( json_logs );
        return errlog_null( ERR_CRITICAL, "_critical_section\n" );
    }
    
    return json_logs;
}

static int _user_log_event( barfight_bouncer_logs_user_stats_t *user_stats, 
                            barfight_shield_response_t* response, char* if_name  )
{
    barfight_bouncer_logs_action_counters_t* interface_counters = NULL;
    
    int c;
    for ( c = 0 ; c < BARFIGHT_BOUNCER_LOGS_INTERFACE_COUNT ; c++ ) {
        if ( user_stats->if_names[c][0] == '\0' ) break;
        if ( strncmp( user_stats->if_names[c], if_name, IF_NAMESIZE ) == 0 ) {
            interface_counters = &user_stats->counters[c];
            break;
        }
    }

    if ( interface_counters == NULL ) {
        if ( c == BARFIGHT_BOUNCER_LOGS_INTERFACE_COUNT ) {
            return errlog( ERR_WARNING, "IP address has appeared on more than %d interfaces.\n", c );
        }
        
        /* Create a new set of stats for this interface. */
        strncpy( user_stats->if_names[c], if_name, sizeof( user_stats->if_names[c] ));
        interface_counters = &user_stats->counters[c];
    }
    
    if ( user_stats->max_reputation < response->reputation ) {
        user_stats->max_reputation = response->reputation;
    }

    if ( _logs_action_counters_add( interface_counters, response->ans ) < 0 ) {
        return errlog( ERR_CRITICAL, "_logs_action_counters_add\n" );
    }
    
    return 0;
    
}

static int _global_log_event( barfight_bouncer_logs_global_stats_t *global_stats, 
                              barfight_shield_ans_t action, u_int8_t protocol )
{
    barfight_bouncer_logs_action_counters_t* interface_counters = NULL;
    
    interface_counters = &global_stats->protocol_counters[protocol];

    if ( _logs_action_counters_add( interface_counters, action ) < 0 ) {
        return errlog( ERR_CRITICAL, "_logs_action_counters_add\n" );
    }    

    return 0;
}


static int _logs_action_counters_add( barfight_bouncer_logs_action_counters_t *counter, 
                                      barfight_shield_ans_t action )
{
    switch ( action ) {
    case NC_SHIELD_RESET: counter->resets++; break;
    case NC_SHIELD_DROP: counter->dropped++; break;
    case NC_SHIELD_LIMITED: counter->limited++; break;
    case NC_SHIELD_YES: counter->accepted++; break;
    default:
        counter->errors++; break;
    }

    counter->totals++;
    
    return 0;
}

static barfight_bouncer_logs_iteration_t* _get_current_iteration( barfight_bouncer_logs_t* logs )
{
    if ( logs == NULL ) return errlogargs_null();

    list_node_t* current_item = logs->current_item;
    if ( current_item == NULL ) return errlog_null( ERR_CRITICAL, "The current item is NULL\n" );

    barfight_bouncer_logs_iteration_t* log_iteration = NULL;
    if (( log_iteration = list_node_val( current_item )) == NULL ) {
        return errlog_null( ERR_CRITICAL, "list_node_val\n" );
    }

    return log_iteration;
}

static struct json_object* _build_json_key( void )
{
    struct json_object* key = NULL;

    int _critical_section() {
        int c =0;
        for ( c = 0 ; c < 16 ; c++ ) {
            if( strnlen( _json_action_keys[c], 4 ) == 0 ) break;
            
            if ( json_object_utils_add_int( key, _json_action_keys[c], c ) < 0 ) {
                return errlog( ERR_CRITICAL, "json_object_utils_add_int\n" );
            }
        }
        
        return 0;
    }

    if (( key = json_object_new_object()) == NULL ) {
        return errlog_null( ERR_CRITICAL, "json_object_new_object\n" );
    }
    
    if ( _critical_section() < 0 ) {
        json_object_put( key );
        return errlog_null( ERR_CRITICAL, "_critical_section\n" );
    }
    
    return key;
}

static struct json_object* _build_json_iteration( barfight_bouncer_logs_iteration_t* iteration,
                                                  int ignore_accept_only )
{
    if ( iteration == NULL ) return errlogargs_null();

    struct json_object* iteration_json = NULL;
    
    int _critical_section() {
        struct json_object* temp;
        if (( temp = _build_json_iteration_globals( iteration )) == NULL ) {
            return errlog( ERR_CRITICAL, "_build_json_iteration_globals\n" );
        }

        if ( json_object_utils_add_object( iteration_json, "globals", temp ) < 0 ) {
            return errlog( ERR_CRITICAL, "json_object_utils_add_object\n" );
        }

        if (( temp = _build_json_iteration_mode( iteration )) == NULL ) {
            return errlog( ERR_CRITICAL, "_build_json_iteration_mode\n" );
        }

        if ( json_object_utils_add_object( iteration_json, "mode", temp ) < 0 ) {
            return errlog( ERR_CRITICAL, "json_object_utils_add_object\n" );
        }

        if (( temp = _build_json_iteration_user( iteration, ignore_accept_only )) == NULL ) {
            return errlog( ERR_CRITICAL, "_build_json_iteration_user\n" );
        }

        if ( json_object_utils_add_object( iteration_json, "user", temp ) < 0 ) {
            return errlog( ERR_CRITICAL, "json_object_utils_add_object\n" );
        }
        
        if ( json_object_utils_add_int( iteration_json, "id", iteration->id ) < 0 ) {
            return errlog( ERR_CRITICAL, "json_object_utils_add_int\n" );
        }

        if (( temp = json_object_utils_create_timeval( &iteration->start_time )) == NULL ) {
            return errlog( ERR_CRITICAL, "json_object_utils_create_timeval\n" );
        }

        if ( json_object_utils_add_object( iteration_json, "start_time", temp ) < 0 ) {
            return errlog( ERR_CRITICAL, "json_object_utils_add_object\n" );
        }

        
        if ( iteration->end_time.tv_sec > 0) {
            if (( temp = json_object_utils_create_timeval( &iteration->end_time )) == NULL ) {
                return errlog( ERR_CRITICAL, "json_object_utils_create_timeval\n" );
            }
            
            if ( json_object_utils_add_object( iteration_json, "end_time", temp ) < 0 ) {
                return errlog( ERR_CRITICAL, "json_object_utils_add_object\n" );
            }
        }

        return 0;
    }

    if (( iteration_json = json_object_new_object()) == NULL ) {
        return errlog_null( ERR_CRITICAL, "json_object_new_object\n" );
    }

    if ( _critical_section() < 0 ) {
        json_object_put( iteration_json );
        return errlog_null( ERR_CRITICAL, "_critical_section\n" );
    }

    return iteration_json;
}

static struct json_object* _build_json_iteration_globals( barfight_bouncer_logs_iteration_t* iteration )
{
    struct json_object* json_array = NULL;
    
    int _critical_section() {
        int c;
        struct json_object* protocol_array = NULL;

        for ( c = 0 ; c < BARFIGHT_BOUNCER_LOGS_PROTOCOL_COUNT ; c++ ) {
            barfight_bouncer_logs_action_counters_t *counters = &iteration->global.protocol_counters[c];
            
            if ( counters->totals == 0 ) continue;

            if (( protocol_array = json_object_new_array()) == NULL ) {
                return errlog( ERR_CRITICAL, "json_object_new_array\n" );
            }

            if ( json_object_utils_array_add_object( json_array, protocol_array ) < 0 ) {
                return errlog( ERR_CRITICAL, "json_object_utils_array_add_object\n" );
            }
            
            if ( json_object_utils_array_add_int( protocol_array, c ) < 0 ) {
                return errlog( ERR_CRITICAL, "json_object_utils_array_add_int\n" );
            }
            
            if ( _build_json_action_counters( protocol_array, counters ) < 0 ) {
                return errlog( ERR_CRITICAL, "_build_json_action_counters\n" );
            }
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
    return json_array;
}

static struct json_object* _build_json_iteration_mode( barfight_bouncer_logs_iteration_t* iteration )
{
    struct json_object* json_object = NULL;
    
    int _critical_section() {
        if ( json_object_utils_add_int( json_object, "relaxed", iteration->mode_counters.relaxed ) < 0 ) {
            return errlog( ERR_CRITICAL, "json_object_utils_add_int\n" );
        }
        if ( json_object_utils_add_int( json_object, "lax", iteration->mode_counters.lax ) < 0 ) {
            return errlog( ERR_CRITICAL, "json_object_utils_add_int\n" );
        }
        if ( json_object_utils_add_int( json_object, "tight", iteration->mode_counters.tight ) < 0 ) {
            return errlog( ERR_CRITICAL, "json_object_utils_add_int\n" );
        }
        if ( json_object_utils_add_int( json_object, "closed", iteration->mode_counters.closed ) < 0 ) {
            return errlog( ERR_CRITICAL, "json_object_utils_add_int\n" );
        }

        return 0;
    }
    
    if (( json_object = json_object_new_object()) == NULL ) {
        return errlog_null( ERR_CRITICAL, "json_object_new_object\n" );
    }

    if ( _critical_section() < 0 ) {
        json_object_put( json_object );
        return errlog_null( ERR_CRITICAL, "_critical_section\n" );
    }

    return json_object;    
}

static struct json_object* _build_json_iteration_user( barfight_bouncer_logs_iteration_t* iteration,
                                                       int ignore_accept_only )
{
    struct json_object* json_object = NULL;
    list_t* user_list = NULL;
        
    int _critical_section() {
        if (( user_list = ht_get_bucket_list( &iteration->user )) == NULL ) {
            return errlog( ERR_CRITICAL, "ht_get_key_list\n" );
        }

        int length = list_length( user_list );
        bucket_t *bucket;
        int c,d,check_stats;
        struct json_object* interface_array = NULL;
        struct json_object* counters_json = NULL;
        
        barfight_bouncer_logs_user_stats_t* user_stats;
        in_addr_t ip;
        char *ip_string;

        for ( c = 0 ; c < length ; c++ ) {
            counters_json = interface_array = NULL;
            if ( list_pop_head( user_list, (void**)&bucket ) < 0 ) {
                return errlog( ERR_CRITICAL, "list_pop_head\n" );
            }
            
            ip = (in_addr_t)bucket->key;
            user_stats = (barfight_bouncer_logs_user_stats_t*)bucket->contents;
            
            if ( ignore_accept_only != 0 ) {
                check_stats = 0;
                /* Check all of the stats to see if there is anything besides an accept */
                for ( d = 0 ; d < BARFIGHT_BOUNCER_LOGS_INTERFACE_COUNT ; d++ ) {
                    if ( user_stats->if_names[d][0] == '\0' ) break;
                    
                    if ( user_stats->counters[d].totals != user_stats->counters[d].accepted ) {
                        check_stats = 1;
                        break;
                    }
                }

                /* Skip these stats if there is nothing important */
                if ( check_stats == 0 ) continue;
            }

            if (( interface_array = json_object_new_array()) == NULL ) {
                return errlog( ERR_CRITICAL, "json_object_new_array\n" );
            }

            ip_string = unet_next_inet_ntoa( ip );
            if ( json_object_utils_add_object( json_object, ip_string, interface_array ) < 0 ) {
                return errlog( ERR_CRITICAL, "json_object_utils_array_add_object\n" );
            }

            /* This is probably not the best solution, because it is
             * kind of magical.  but it is done this way for
             * efficiency.  Otherwise, each IP would also need a
             * hash */
            if ( json_object_utils_array_add_double( interface_array, user_stats->max_reputation ) < 0 ) {
                return errlog( ERR_CRITICAL, "json_object_utils_array_add\n" );
            };

            for ( d = 0 ; d < BARFIGHT_BOUNCER_LOGS_INTERFACE_COUNT ; d++ ) {
                if ( user_stats->if_names[d][0] == '\0' ) break;
                
                if (( ignore_accept_only != 0 ) && 
                    ( user_stats->counters[d].totals == user_stats->counters[d].accepted )) continue;
                
                if (( counters_json = json_object_new_array()) == NULL ) {
                    return errlog( ERR_CRITICAL, "json_object_new_array\n" );
                }
                
                if ( json_object_utils_array_add_object( interface_array, counters_json ) < 0 ) {
                    return errlog( ERR_CRITICAL, "json_object_utils_array_add\n" );
                }
                
                if ( json_object_utils_array_add_string( counters_json, user_stats->if_names[d] ) < 0 ) {
                    return errlog( ERR_CRITICAL, "json_object_utils_array_add_string\n" );
                }

                if ( _build_json_action_counters( counters_json, &user_stats->counters[d] ) < 0 ) {
                    return errlog( ERR_CRITICAL, "_build_json_action_counters\n" );
                }
            }
        }
        
        return 0;
    }
    
    if (( json_object = json_object_new_object()) == NULL ) {
        return errlog_null( ERR_CRITICAL, "json_object_new_object\n" );
    }

    int ret = _critical_section();
    if ( user_list != NULL ) {
        list_destroy( user_list );
        list_free( user_list );
    }

    if ( ret < 0 ) {
        json_object_put( json_object );
        return errlog_null( ERR_CRITICAL, "_critical_section\n" );
    }
    return json_object;
    
    return json_object_new_object();
}

static int _build_json_action_counters( struct json_object* counters_json,
                                        barfight_bouncer_logs_action_counters_t *counters )
{
    if ( json_object_utils_array_add_int( counters_json, counters->resets ) < 0 ) {
        return errlog( ERR_CRITICAL, "json_object_utils_array_add_int\n" );
    }

    if ( json_object_utils_array_add_int( counters_json, counters->dropped ) < 0 ) {
        return errlog( ERR_CRITICAL, "json_object_utils_array_add_int\n" );
    }

    if ( json_object_utils_array_add_int( counters_json, counters->limited ) < 0 ) {
        return errlog( ERR_CRITICAL, "json_object_utils_array_add_int\n" );
    }
    if ( json_object_utils_array_add_int( counters_json, counters->accepted ) < 0 ) {
        return errlog( ERR_CRITICAL, "json_object_utils_array_add_int\n" );
    }
    if ( json_object_utils_array_add_int( counters_json, counters->errors ) < 0 ) {
        return errlog( ERR_CRITICAL, "json_object_utils_array_add_int\n" );
    }

    return 0;
}

