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

#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>


#include <libmvutil.h>

#include <mvutil/debug.h>
#include <mvutil/errlog.h>
#include <mvutil/uthread.h>

#include <microhttpd.h>

#include "bouncer/logs.h"
#include "bouncer/reader.h"
#include "bouncer/shield.h"

#include "utils/sched.h"
#include "net/nfqueue.h"

#include "json/server.h"

#define DEFAULT_CONFIG_FILE  "/var/lib/barfight.js"
#define ENV_DEBUG_LEVEL "UNTANGLE_DEBUG_LEVEL"
#define DEFAULT_DEBUG_LEVEL  "14"

#define ENV_QUEUE_NUM "UNTANGLE_BARFIGHT_QUEUE_NUM"
#define DEFAULT_QUEUE_NUM "12"

/* Using 24, to capture about 2 minutes of logs if they rotate every 5 seconds */
#define _CIRCULAR_LOG_SIZE  24

#define FLAG_ALIVE      0x543D00D

static struct
{
    int is_running;
    pthread_t scheduler_thread;
    json_server_t json_server;
    struct MHD_Daemon *daemon;
    barfight_net_nfqueue_t nfqueue;
    barfight_bouncer_reader_t reader;
    barfight_bouncer_logs_t logs;
} _globals = {
    .is_running = 0,
    .scheduler_thread = 0,
    .daemon = NULL,
};

static int _usage( char *name );
static int _init( int argc, char** argv );
static void _destroy( void );

static void _signal_term( int sig );
static int _set_signals( void );

/* This is defined inside of functions.c */
extern int barfight_functions_init( barfight_bouncer_logs_t* logs );
extern json_server_function_entry_t *barfight_functions_get_json_table( void );

static int _usage( char *name )
{
    fprintf( stderr, "Usage: %s <json-port> [<config-file>]\n", name );
    fprintf( stderr, "\tjson-port is the port to run the JSON server on.\n" );
    fprintf( stderr, "\tconfig-file defaults to '" DEFAULT_CONFIG_FILE  "'\n" );
    return -1;
}

/**
 * Simple little test binary, it just queues the packet, adds it to a
 * counter, and then reads it
 */
int main( int argc, char** argv )
{
    if (( argc < 2 ) || ( argc > 3 )) return _usage( argv[0] );

    if ( _init( argc, argv ) < 0 ) {
        _destroy();
        return errlog( ERR_CRITICAL, "_init\n" );
    }

    _globals.is_running = FLAG_ALIVE;
    
    debug( 1, "MAIN: Setting up signal handlers.\n" );
    _set_signals();

    /* An awesome way to wait for a shutdown signal. */
    while ( _globals.is_running == FLAG_ALIVE ) sleep( 1 );

    /* Destroy the shield */
    _destroy();
    
    return 0;
}

static int _init( int argc, char** argv )
{
    if ( libmvutil_init() < 0 ) {
        fprintf( stderr, "Unable to initialize libmvutil\n" );
        return -1;
    }
    
    /* Configure the debug level */
    char* debug_level = getenv( ENV_DEBUG_LEVEL );
    if ( debug_level == NULL ) debug_level = DEFAULT_DEBUG_LEVEL;
    debug_set_mylevel( atoi( debug_level ));
    
    /* Initialize the scheduler. */
    if ( barfight_sched_init() < 0 ) return errlog( ERR_CRITICAL, "barfight_sched_init\n" );

    /* Donate a thread to start the scheduler. */
    if ( pthread_create( &_globals.scheduler_thread, &uthread_attr.other.medium,
                         barfight_sched_donate, NULL )) {
        return perrlog( "pthread_create" );
    }

    /* Initialize the logs (hardcoded, this should be adjustable) */
    if ( barfight_bouncer_logs_init( &_globals.logs, _CIRCULAR_LOG_SIZE ) < 0 ) {
        return errlog( ERR_CRITICAL, "barfight_bouncer_logs_init\n" );
    }

    errlog( ERR_WARNING, "Use the scheduler to automatically move the logs forward.\n" );
    
    /* Initialize the shield */
    if ( barfight_shield_init() < 0 ) return errlog( ERR_CRITICAL, "barfight_shield_init\n" );

    /* Create a JSON server */
    if ( barfight_functions_init( &_globals.logs ) < 0 ) {
        return errlog( ERR_CRITICAL, "barfight_functions_init\n" );
    }

    json_server_function_entry_t* function_table = barfight_functions_get_json_table();
    
    if ( json_server_init( &_globals.json_server, function_table ) < 0 ) {
        return errlog( ERR_CRITICAL, "json_server_init\n" );
    }

    _globals.daemon = MHD_start_daemon( MHD_USE_THREAD_PER_CONNECTION | MHD_USE_DEBUG,
                                        atoi( argv[1] ), NULL, NULL, _globals.json_server.handler, 
                                        &_globals.json_server, MHD_OPTION_END );

    if ( _globals.daemon == NULL ) return errlog( ERR_CRITICAL, "MHD_start_daemon\n" );
    
    if ( barfight_net_nfqueue_global_init() < 0 ) {
        return errlog( ERR_CRITICAL, "barfight_net_nfqueue_global_init\n" );
    }

    char* queue_num = getenv( ENV_QUEUE_NUM );
    if ( queue_num == NULL ) queue_num = DEFAULT_QUEUE_NUM;
    if ( barfight_net_nfqueue_init( &_globals.nfqueue, atoi( queue_num ),
                                    NFQNL_COPY_PACKET | NFQNL_COPY_UNTANGLE_MODE, 0xFFFF ) < 0 ) {
        return errlog( ERR_CRITICAL, "barfight_net_nfqueue_init\n" );
    }

    if ( barfight_bouncer_reader_init( &_globals.reader, &_globals.nfqueue, &_globals.logs ) < 0 ) {
        return errlog( ERR_CRITICAL, "barfight_bouncer_reader_init\n" );
    }

    pthread_t thread;
    if ( pthread_create( &thread, &uthread_attr.other.medium,
                         barfight_bouncer_reader_donate, &_globals.reader )) {
        return perrlog( "pthread_create" );
    }

    return 0;
}

static void _destroy( void )
{
    /* Stop the reader */
    if ( barfight_bouncer_reader_stop(  &_globals.reader ) < 0 ) {
        errlog( ERR_CRITICAL, "barfight_bouncer_reader_stop\n" );
    }

    barfight_bouncer_reader_destroy( &_globals.reader );
    
    /* Cleanup the queue */
    barfight_net_nfqueue_destroy( &_globals.nfqueue );

    barfight_net_nfqueue_global_destroy();
    
    if ( barfight_shield_destroy() < 0 ) errlog( ERR_CRITICAL, "barfight_shield_destroy\n" );
    
    if ( barfight_sched_cleanup_z( NULL ) < 0 ) errlog( ERR_CRITICAL, "barfight_sched_cleanup_z\n" );
    
    MHD_stop_daemon( _globals.daemon );
    
    json_server_destroy( &_globals.json_server );

    barfight_bouncer_logs_destroy( &_globals.logs );

    libmvutil_cleanup();
}

static void _signal_term( int sig )
{
    _globals.is_running = 0;
}

static int _set_signals( void )
{
    struct sigaction signal_action;
    
    memset( &signal_action, 0, sizeof( signal_action ));
    signal_action.sa_flags = SA_NOCLDSTOP;
    signal_action.sa_handler = _signal_term;
    sigaction( SIGINT,  &signal_action, NULL );
    
    signal_action.sa_handler = SIG_IGN;
    sigaction( SIGCHLD, &signal_action, NULL );
    sigaction( SIGPIPE, &signal_action, NULL );
    
    return 0;
}
