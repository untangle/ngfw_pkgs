/*
 * $HeadURL: svn://chef/work/src/libnetcap/src/barfight_shield_mode.c $
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

#include <netinet/in.h>
#include <arpa/inet.h>
#include <stdlib.h>

#include <mvutil/debug.h>
#include <mvutil/errlog.h>
#include <mvutil/utime.h>

#include "utils/sched.h"

#include "bouncer/logs.h"
#include "bouncer/load.h"
#include "bouncer/shield.h"
#include "bouncer/config.h"

/* Flag to indicate that the shield mode updates are alive */
#define _NC_SHIELD_MODE_IS_ALIVE 0xA3D00DAD
#define _NC_SHIELD_MODE_IS_DEAD  0xDEADD00D

/* Perform a shield update every 50 milliseconds */
#define _NC_SHIELD_UPD_INTVL_USEC MSEC_TO_USEC( 50 )

#define _EXCEED_MODE( MODE ) (( cpu_load      > cfg->limit.cpu_load. MODE )    || \
                              ( num_sessions  > cfg->limit.sessions.  MODE )     || \
                              ( request_load  > cfg->limit.request_load.  MODE ) || \
                              ( session_load  > cfg->limit.session_load.  MODE ) || \
                              ( tcp_chk_load  > cfg->limit.tcp_chk_load.  MODE ) || \
                              ( udp_chk_load  > cfg->limit.udp_chk_load.  MODE ) || \
                              ( icmp_chk_load > cfg->limit.icmp_chk_load. MODE ) || \
                              ( evil_load     > cfg->limit.evil_load.     MODE ))

static struct
{
    int is_alive;
    bouncer_shield_config_t* cfg;
    nc_shield_reputation_t* root_rep;
    barfight_shield_mode_t* mode;
    nc_shield_fence_t** fence;        
} _shield_mode = {
    .is_alive = 0,
    .cfg      = NULL,
    .root_rep = NULL,
    .mode     = NULL,
    .mode     = NULL,
    .fence    = NULL,
};

static int  _update( bouncer_shield_config_t* cfg, nc_shield_reputation_t* root_rep, 
                     barfight_shield_mode_t* mode, nc_shield_fence_t** fence );

static void _scheduler_event( void );

static __inline__ int _is_alive( void )
{
    return ( _shield_mode.is_alive == _NC_SHIELD_MODE_IS_ALIVE );
}

extern barfight_bouncer_logs_t* _barfight_logs( void );

int nc_shield_mode_init( bouncer_shield_config_t* cfg, nc_shield_reputation_t* root_rep, 
                         barfight_shield_mode_t* mode, nc_shield_fence_t** fence )
{
    if ( cfg == NULL || root_rep == NULL || mode == NULL || fence == NULL ) {
        return errlogargs();
    }

    _shield_mode.cfg      = cfg;
    _shield_mode.root_rep = root_rep;
    _shield_mode.mode     = mode;
    _shield_mode.fence    = fence;
    
    debug( NC_SHIELD_DEBUG_LOW, "SHIELD: Shield monitor starting\n" );

    if ( barfight_sched_event_z( _scheduler_event, _NC_SHIELD_UPD_INTVL_USEC ) < 0 ) {
        return errlog( ERR_CRITICAL, "barfight_sched_event\n" );
    }

    _shield_mode.is_alive = _NC_SHIELD_MODE_IS_ALIVE;
    
    return 0;
}

int nc_shield_mode_destroy( void )
{    
    if ( !_is_alive()) return 0;
    
    /* Indicate that the mode manager is no longer alive */
    _shield_mode.is_alive = _NC_SHIELD_MODE_IS_DEAD;
        
    return 0;
}

static int _update( bouncer_shield_config_t* cfg, nc_shield_reputation_t* root_rep, 
                    barfight_shield_mode_t* mode, nc_shield_fence_t** fence )
{
    int num_sessions;
    double num_clients;

    double cpu_load;
    
    barfight_load_val_t request_load;
    barfight_load_val_t session_load;
    barfight_load_val_t tcp_chk_load;
    barfight_load_val_t udp_chk_load;
    barfight_load_val_t icmp_chk_load;
    barfight_load_val_t evil_load;
    
    if ( cfg == NULL || root_rep == NULL || mode == NULL || fence == NULL ) return errlogargs();

    if ( getloadavg( &cpu_load, 1 ) < 1 ) {
        perrlog ( "getloadavg" );

        /* No reason to make this fatal, it is mostly ignored */
        cpu_load = 0.5;
    }

    /* Update the root reputation */
    if ( nc_shield_reputation_update( root_rep ) < 0 ) {
        return errlog( ERR_CRITICAL, "nc_shield_reputation_update\n" );
    }
    
    num_sessions = root_rep->active_sessions;

    // Need to determine a way to calculate better averages, right now using the sum
    // Could turn the number of clients into a load that gets calculated over time
    num_clients = 1.0;
    
    request_load  = root_rep->request_load.load  * num_clients;
    session_load  = root_rep->session_load.load  * num_clients;
    tcp_chk_load  = root_rep->tcp_chk_load.load  * num_clients;
    udp_chk_load  = root_rep->udp_chk_load.load  * num_clients;
    icmp_chk_load = root_rep->icmp_chk_load.load * num_clients;
    evil_load     = root_rep->evil_load.load     * num_clients;

    if ( _EXCEED_MODE( closed )) {
        *mode = NC_SHIELD_MODE_CLOSED;
        *fence = &cfg->fence.closed;
    } 
    else if ( _EXCEED_MODE( tight )) {
        *mode = NC_SHIELD_MODE_TIGHT;
        *fence = &cfg->fence.tight;
    } 
    else if ( _EXCEED_MODE( lax )) {
        *mode = NC_SHIELD_MODE_LAX;
        *fence = &cfg->fence.lax;
    } else {
        *mode = NC_SHIELD_MODE_RELAXED;
        *fence = &cfg->fence.relaxed;
    }
    
    if ( barfight_bouncer_logs_add_mode( _barfight_logs(), *mode ) < 0 ) {
        errlog( ERR_WARNING, "barfight_bouncer_logs_add_mode\n" );
    }
    return 0;
}

static void _scheduler_event( void )
{
    int _critical_section( void ) {
        _update( _shield_mode.cfg, _shield_mode.root_rep, _shield_mode.mode, _shield_mode.fence );
        return 0;
    }

    if ( !_is_alive()) {
        debug( NC_SHIELD_DEBUG_LOW, "SHIELD: Shield monitor is no longer alive\n" );
        return;
    }
    
    if ( _critical_section() < 0 ) errlog( ERR_CRITICAL, "Error updating the shield mode\n" );
    
    /* Always make sure to schedule the event again, if the shield is alive */
    if ( _is_alive()) {
        if ( barfight_sched_event_z( _scheduler_event, _NC_SHIELD_UPD_INTVL_USEC ) < 0 ) {
            errlog( ERR_FATAL, "barfight_sched_event_z\n" );
        }
    }
}
