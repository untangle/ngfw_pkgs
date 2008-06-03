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
#include <fcntl.h>

#include <sys/types.h>
#include <sys/stat.h>

#include <syslog.h>

#include <libmvutil.h>

#include <mvutil/debug.h>
#include <mvutil/errlog.h>
#include <mvutil/uthread.h>
#include <mvutil/utime.h>

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
    char *config_file;
    char *std_out_filename;
    int std_out;
    char *std_err_filename;
    int std_err;
    int port;
    int daemonize;
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
    .config_file = NULL,
    .port = -1,
    .daemonize = 0,
    .std_err_filename = NULL,
    .std_err = -1,
    .std_out_filename = NULL,
    .std_out = -1
};

static int _parse_args( int argc, char** argv );
static int _usage( char *name );
static int _init( int argc, char** argv );
static void _destroy( void );
static int _setup_output( void );

static void _signal_term( int sig );
static int _set_signals( void );

/* This is defined inside of functions.c */
extern int barfight_functions_init( barfight_bouncer_logs_t* logs, char *config_file );
extern json_server_function_entry_t *barfight_functions_get_json_table( void );
extern int barfight_functions_load_config( bouncer_shield_config_t* config );

/**
 * Simple little test binary, it just queues the packet, adds it to a
 * counter, and then reads it
 */
int main( int argc, char** argv )
{    
    pid_t pid, sid;
    int dev_null_fd;

    if ( _parse_args( argc, argv ) < 0 ) return _usage( argv[0] );

    /* Daemonize if necessary */
    if ( _globals.daemonize != 0 ) {
        pid = fork();
        if ( pid < 0 ){ 
            fprintf( stderr, "Unable to fork daemon process.\n" );
            return -2;
        } else if ( pid > 0 ) {
            return 0;
        }
        
        /* This is just copied from http://www.systhread.net/texts/200508cdaemon2.php ... shameless. */
        umask( 0 );
        if (( sid = setsid()) < 0 ) {
            syslog( LOG_DAEMON | LOG_ERR, "setsid: %s\n", errstr );
            return -5;
        }
        
        if ( chdir( "/" ) < 0 ) {
            syslog( LOG_DAEMON | LOG_ERR, "chrdir: %s\n", errstr );
            return -6;
        }
        
        /* pid is zero, this is the daemon process */
        /* Dupe these to /dev/null until something changes them */
        if (( dev_null_fd = open( "/dev/null", O_WRONLY | O_APPEND )) < 0 ) {
            syslog( LOG_DAEMON | LOG_ERR, "open(/dev/null): %s\n", errstr );
            return -7;
        }
        
        close( STDIN_FILENO );
        close( STDOUT_FILENO );
        close( STDERR_FILENO );
        if ( dup2( dev_null_fd, STDOUT_FILENO ) < 0 ) {
            syslog( LOG_DAEMON | LOG_ERR, "dup2: %s\n", errstr );
            return -7;
        }
        if ( dup2( dev_null_fd, STDERR_FILENO ) < 0 ) {
            syslog( LOG_DAEMON | LOG_ERR, "dup2: %s\n", errstr );
            return -7;
        }
    }
    
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

static int _parse_args( int argc, char** argv )
{
    int c = 0;
    
    while (( c = getopt( argc, argv, "dhp:c:o:e:" ))  != -1 ) {
        switch( c ) {
        case 'd':
            _globals.daemonize = 1;
            break;

        case 'h':
            return -1;
            
        case 'p':
            _globals.port = atoi( optarg );
            break;
            
        case 'c':
            _globals.config_file = optarg;
            break;

        case 'o':
            _globals.std_out_filename = optarg;
            break;

        case 'e':
            _globals.std_err_filename = optarg;

        case '?':
            return -1;
        }
    }
    
    return 0;
}

static int _usage( char *name )
{
    fprintf( stderr, "Usage: %s\n", name );
    fprintf( stderr, "\t-d: daemonize.  Immediately fork on startup.\n" );
    fprintf( stderr, "\t-p <json-port>: The port to bind to for the JSON interface.\n" );
    fprintf( stderr, "\t-c <config-file>: Config file to use.\n" );
    fprintf( stderr, "\t\tThe config-file can be modified through the JSON interface.\n" );
    fprintf( stderr, "\t-h: Halp (show this message)\n" );
    return -1;
}

static int _init( int argc, char** argv )
{
    if ( _setup_output() < 0 ) {
        syslog( LOG_DAEMON | LOG_ERR, "Unable to setup output\n" );
        return -1;
    }

    if ( libmvutil_init() < 0 ) {
        syslog( LOG_DAEMON | LOG_ERR, "Unable to initialize libmvutil\n" );
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
    
    /* Initialize the shield */
    if ( barfight_shield_init() < 0 ) return errlog( ERR_CRITICAL, "barfight_shield_init\n" );

    /* Create a JSON server */
    if ( barfight_functions_init( &_globals.logs, _globals.config_file ) < 0 ) {
        return errlog( ERR_CRITICAL, "barfight_functions_init\n" );
    }

    /* Load the shield configuration (have to do this after initializing functions */
    struct json_object* config_file_json = NULL;
    if ( _globals.config_file != NULL ) {
        if (( config_file_json = json_object_from_file( _globals.config_file )) == NULL ) {
            /* Ignore the error, and just load the defaults */
            errlog( ERR_CRITICAL, "json_object_from_file\n" );
        } else {
            debug( 10, "MAIN: Loading the config file %s\n", _globals.config_file );
            bouncer_shield_config_t config;
            if ( bouncer_shield_config_load_json( &config, config_file_json ) < 0 ) {
                errlog( ERR_CRITICAL, "bouncer_shield_config_load_json\n" );
            } else {
                if ( barfight_functions_load_config( &config ) < 0 ) {
                    errlog( ERR_CRITICAL, "barfight_functions_load_config\n" );
                }
            }
        }
    }

    /* Start the thread to move the circular log buffer (do it after initializing the config
     * because it load the delay from the config */
    if ( barfight_sched_event( barfight_bouncer_logs_sched_advance, &_globals.logs, 
                               MSEC_TO_USEC( _globals.logs.advance_timeout )) < 0 ) {
        return errlog( ERR_CRITICAL, "barfight_sched_event\n" );
    }

    json_server_function_entry_t* function_table = barfight_functions_get_json_table();
    
    if ( json_server_init( &_globals.json_server, function_table ) < 0 ) {
        return errlog( ERR_CRITICAL, "json_server_init\n" );
    }

    _globals.daemon = MHD_start_daemon( MHD_USE_THREAD_PER_CONNECTION | MHD_USE_DEBUG,
                                        _globals.port, NULL, NULL, _globals.json_server.handler, 
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
    /* Disable the log advancing task */
    if ( barfight_bouncer_logs_set_rotate_delay( &_globals.logs, -1 ) < 0 ) {
        errlog( ERR_CRITICAL, "barfight_bouncer_logs_set_rotate_delay\n" );
    }

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

    /* Close the two open file descriptors */
    if ( _globals.std_out > 0 ) close( _globals.std_out );
    if ( _globals.std_err > 0 ) close( _globals.std_err );
    
    _globals.std_out = -1;
    _globals.std_err = -1;
}

static int _setup_output( void )
{
    int err_fd = -1;

    if (( _globals.std_err_filename != NULL ) &&
        ( _globals.std_err = open( _globals.std_err_filename, O_WRONLY | O_APPEND | O_CREAT, 00660 )) < 0 ) {
        syslog( LOG_DAEMON | LOG_ERR, "open(%s): %s\n", _globals.std_err_filename, errstr );
        return -1;
    }
    
    err_fd = _globals.std_err;

    if (( _globals.std_out_filename != NULL ) &&
        ( _globals.std_out = open( _globals.std_out_filename, O_WRONLY | O_APPEND | O_CREAT,  00660 )) < 0 ) {
        syslog( LOG_DAEMON | LOG_ERR, "open(%s): %s\n", _globals.std_out_filename, errstr );
        return -1;
    }
    
    if (( err_fd < 0 ) && ( _globals.std_out > 0 )) err_fd = _globals.std_out;
    
    if ( err_fd > 0 ) {
        close( STDERR_FILENO );
        if ( dup2( err_fd, STDERR_FILENO ) < 0 ) {
            syslog( LOG_DAEMON | LOG_ERR, "dup2: %s\n", errstr );
            return -7;
        }
    }

    if ( _globals.std_out > 0 ) {
        close( STDOUT_FILENO );
        if ( dup2( _globals.std_out, STDOUT_FILENO ) < 0 ) {
            syslog( LOG_DAEMON | LOG_ERR, "dup2: %s\n", errstr );
            return -7;
        }
    }
    
    return 0;
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
