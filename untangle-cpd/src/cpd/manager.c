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

#include <pthread.h>

#include <stdlib.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <unistd.h>

#include <net/if.h>

#include <mvutil/debug.h>
#include <mvutil/errlog.h>
#include <mvutil/unet.h>
#include <mvutil/utime.h>

#include "cpd.h"
#include "cpd/manager.h"
#include "status.h"

#define _MAX_SHUTDOWN_TIMEOUT     10

/* This is the file that should contain the routing table */
#define _ROUTE_FILE              "/proc/net/route"
/* For simplicity the route table is divided into 128 byte chunks */
#define _ROUTE_READ_SIZE         0x80

static struct
{
    pthread_mutex_t mutex;
    cpd_config_t config;

    int init;

    /* The next time wake up to cleanup expired hosts. */
    struct timespec next_update;
} _globals = {
    .init = 0,
    .mutex = PTHREAD_RECURSIVE_MUTEX_INITIALIZER_NP,
};

int cpd_manager_init( cpd_config_t* config )
{
    if ( _globals.init != 0 ) {
        return errlog( ERR_CRITICAL, "cpd_manager_init was called twice.\n" );
    }

    if ( config == NULL ) {
        return errlogargs();
    }

    _globals.init = 1;

    if ( cpd_manager_set_config( config ) < 0 ) {
        return errlog( ERR_CRITICAL, "cpd_manager_set_config\n" );
    }
    
    clock_gettime( CLOCK_MONOTONIC, &_globals.next_update );

    return 0;
}

void cpd_manager_destroy( void )
{
    _globals.init = -1;
}

/**
 * Copies in the config to the global config
 */
int cpd_manager_set_config( cpd_config_t* config )
{
    if ( config == NULL ) {
        return errlogargs();
    }
    
    int _critical_section() {
        debug( 9, "Loading new config\n" );
        
        memcpy( &_globals.config, config, sizeof( _globals.config ));
        
        return 0;
    }

    if ( pthread_mutex_lock( &_globals.mutex ) != 0 ) return perrlog( "pthread_mutex_lock" );
    int ret = _critical_section();
    if ( pthread_mutex_unlock( &_globals.mutex ) != 0 ) return perrlog( "pthread_mutex_unlock" );
    
    if ( ret < 0 ) return errlog( ERR_CRITICAL, "_critical_section\n" );
    
    return 0;
}

/**
 * Gets the config
 */
int cpd_manager_get_config( cpd_config_t* config )
{
    if ( config == NULL ) return errlogargs();
    
    int _critical_section() {
        debug( 9, "Copying out config\n" );
        memcpy( config, &_globals.config, sizeof( _globals.config ));
        return 0;
    }

    if ( pthread_mutex_lock( &_globals.mutex ) != 0 ) return perrlog( "pthread_mutex_lock" );
    int ret = _critical_section();
    if ( pthread_mutex_unlock( &_globals.mutex ) != 0 ) return perrlog( "pthread_mutex_unlock" );
    
    if ( ret < 0 ) return errlog( ERR_CRITICAL, "_critical_section\n" );
    
    return 0;
}

/**
 * Retrieve the status of all of the interfaces.
 */
int cpd_manager_get_status( cpd_status_t* status )
{
    if ( status == NULL ) {
        return errlogargs();
    }

    int _critical_section()
    {
        return errlog( ERR_WARNING, "Implement me\n" );
    }

    if ( pthread_mutex_lock( &_globals.mutex ) != 0 ) return perrlog( "pthread_mutex_lock" );
    int ret = _critical_section();
    if ( pthread_mutex_unlock( &_globals.mutex ) != 0 ) return perrlog( "pthread_mutex_unlock" );

    if ( ret < 0 ) return errlog( ERR_CRITICAL, "_critical_section\n" );

    return 0;
}

/**
 * Insert a Host / MAC Address
 */
int cpd_manager_add_host( struct ether_addr hw_addr, struct in_addr* addr, char* username )
{
    
}

