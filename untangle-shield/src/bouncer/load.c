/*
 * $HeadURL: svn://chef/work/src/libnetcap/src/barfight_load.c $
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

#include <pthread.h>
#include <sys/time.h>
#include <time.h>
#include <stdlib.h>
#include <math.h>

#include <mvutil/debug.h>
#include <mvutil/errlog.h>
#include <mvutil/utime.h>

#include "bouncer/load.h"

#define _LOAD_MIN            .000001

#define abs(x)    (((x)>0) ? (x) : (-x))

typedef struct timeval timeval_t;

static int _load_update ( barfight_load_t* load, int count, barfight_load_val_t val, timeval_t* current_time );

int               barfight_load_update  ( barfight_load_t* load, int count, barfight_load_val_t val )
{
    timeval_t time;
    
    if ( load == NULL ) return errlogargs();

    if ( gettimeofday( &time, NULL ) < 0 ) return perrlog("gettimeofday");

    if ( _load_update( load, count, val, &time ) < 0 ) {
        return errlog( ERR_CRITICAL, "_load_update\n" );
    }

    return 0;
}

barfight_load_val_t barfight_load_get     ( barfight_load_t* load )
{
    timeval_t         time;

    if ( load == NULL ) return errlogargs();
    
    if ( gettimeofday( &time, NULL ) < 0 ) return (barfight_load_val_t)perrlog( "gettimeofday" );

    if ( _load_update( load, 0, 0, &time ) < 0 ) {
        return errlog(ERR_CRITICAL, "_load_update\n");
    }
   
    return load->load;
}

barfight_load_t*    barfight_load_malloc  ( void )
{
    barfight_load_t* load;
    
    if ( ( load = malloc(sizeof(barfight_load_t))) == NULL ) return errlogmalloc_null();
    
    return load;
}

int               barfight_load_init    ( barfight_load_t* load, 
                                        barfight_load_val_t interval, int if_init_time )
{
    if ( load == NULL ) return errlogargs();
    
    /* Set the interval */
    load->interval = interval;
    
    /* Reset the total */
    load->total = 0;
    
    /* Set the last update */
    /* If reseting the time, reset the load also */
    if ( if_init_time == 1 ) {
        if (gettimeofday (&load->last_update, NULL) < 0) {
            return perrlog("gettimeofday");
        }
        load->load = 0;
    }
    
    return 0;
}

barfight_load_t*    barfight_load_create  ( barfight_load_val_t interval, int if_init_time )
{
    barfight_load_t* load;

    if ((load = barfight_load_malloc()) == NULL ) {
        return errlog_null(ERR_CRITICAL, "barfight_load_create\n");
    }
    
    if (barfight_load_init(load,interval, if_init_time ) < 0 ) {
        return errlog_null(ERR_CRITICAL, "barfight_load_init\n");
    }

    return 0;
}

void              barfight_load_free    ( barfight_load_t* load )
{
    if ( load == NULL ) {
        errlogargs();
        return;
    }
        
    /* Free the load */
    free(load);
}

void              barfight_load_destroy ( barfight_load_t* load )
{
    if ( load == NULL ) {
        errlogargs();
        return;
    }    
}

void              barfight_load_raze    ( barfight_load_t* load )
{
    if ( load == NULL ) {
        errlogargs();
        return;
    }

    barfight_load_destroy(load);

    barfight_load_free( load);
}

static int _load_update ( barfight_load_t* load, int count, barfight_load_val_t val, timeval_t* current_time )
{
    barfight_load_val_t duration, last_update, current, x;
    double e;

    /* Increment the count */
    load->total += count;
    
    /* Multiply by 1,000,000 to convert seconds to microseconds */
    current = ((barfight_load_val_t)current_time->tv_sec * U_SEC ) + current_time->tv_usec;
    last_update = ((barfight_load_val_t)load->last_update.tv_sec * U_SEC ) + load->last_update.tv_usec;

    duration = current - last_update;

    if ( duration < 0 ) {
        debug( 8, "LOAD: Current time before last update: duration - %lg\n"
               "LOAD: Current:     %08d.%08d\nLast Update: %08d.%08d\n", 
               duration, current_time->tv_sec, current_time->tv_usec,
               load->last_update.tv_sec, load->last_update.tv_usec );
        /* Just use 100 micro-seconds */
        duration = 100;
    } else if ( duration == 0 ) {
        /* Just use 100 micro-seconds*/
        duration = 100;
    }
    
    e = exp(-duration/load->interval );

    if ( count == 0 ) {
        load->load = (e*load->load);
    } else {
        /* Calculate the number of events per second */
        x = val * ((barfight_load_val_t)U_SEC) / ( duration );
        load->load = (e*load->load + (1-e)*x);
    }

    if ( abs( load->load ) < _LOAD_MIN ) load->load = 0;

    memcpy( &load->last_update, current_time, sizeof( timeval_t ));

    return 0;
}


