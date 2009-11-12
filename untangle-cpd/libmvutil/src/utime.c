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

#include <sys/types.h>
#include <unistd.h>
#include "mvutil/errlog.h"

#include "mvutil/utime.h"

unsigned long utime_usec_diff (struct timeval* earlier, struct timeval* later)
{
    u_long usec_diff = 0;

    if (!earlier || !later) return 0;

    usec_diff  = (later->tv_sec - earlier->tv_sec)*1000000;
    usec_diff += (later->tv_usec) - (earlier->tv_usec);

    return usec_diff;
}

unsigned long utime_usec_diff_now (struct timeval* earlier)
{
    struct timeval tv;

    if ( gettimeofday( &tv, NULL ) < 0 )
        return 0;

    return utime_usec_diff(earlier,&tv);
}

int utime_usec_add (struct timeval* tv, long microsec )
{
    if ( tv == NULL ) return -1;

    tv->tv_sec  += USEC_TO_SEC( microsec );
    tv->tv_usec += microsec % U_SEC;

    /* Handle overflow from adding */
    if ( tv->tv_usec >= U_SEC ) {
        tv->tv_sec  += USEC_TO_SEC( tv->tv_usec );
        tv->tv_usec  = tv->tv_usec % U_SEC;
    } else if ( tv->tv_usec < 0 ) {
        /* just in case?*/
        tv->tv_usec = 0;
    }

    return 0;
}

int utime_usec_add_now( struct timeval* tv, long microsec )
{
    if ( tv == NULL )
        return errlogargs();

    if ( gettimeofday( tv, NULL ) < 0 )
        return perrlog( "gettimeofday" );

    return utime_usec_add( tv, microsec );
}

int utime_msec_add ( struct timeval* tv, long millisec )
{
    return utime_usec_add( tv, MSEC_TO_USEC( millisec ));
}

int utime_msec_add_now( struct timeval* tv, long millisec )
{
    return utime_usec_add_now( tv, MSEC_TO_USEC( millisec ));
}

void*         utime_timer_start_sem(void* utime_timer_struct)
{
    struct utime_timer* t = (struct utime_timer*) utime_timer_struct;

    usleep(t->usec);
    sem_post(t->sem_to_post);
    return NULL;
}

/**
 * Return the number of nanoseconds between time_1 and time_2
 */
int64_t utime_timespec_diff( struct timespec* time_1, struct timespec* time_2 )
{
    int64_t diff = 0;

    if ( time_1 == NULL ) return errlogargs();
    if ( time_2 == NULL ) return errlogargs();
    
    diff = (int64_t)SEC_TO_NSEC((int64_t)time_1->tv_sec - (int64_t)time_2->tv_sec );
    diff += (int64_t)time_1->tv_nsec - (int64_t)time_2->tv_nsec;

    return diff;
}

/**
 * Add nanoseconds to a timespec (dest can equal time_1)
 */
int utime_timespec_add( struct timespec* dest, struct timespec* time_1, int64_t nsecs )
{
    if ( dest == NULL ) return errlogargs();
    if ( time_1 == NULL ) return errlogargs();
    
    struct timespec time_2;
    time_2.tv_sec = NSEC_TO_SEC( nsecs );
    time_2.tv_nsec = nsecs % N_SEC;
    
    if ( utime_timespec_add_timespec( dest, time_1, &time_2 ) < 0 ) {
        return errlog( ERR_CRITICAL, "utime_timespec_diff_add_timespec\n" );
    }

    return 0;
}

/**
 * Add two timespecs together (dest can equal time_1 or time_2)
 */
int utime_timespec_add_timespec( struct timespec* dest, struct timespec* time_1, 
                                      struct timespec* time_2 )
{
    if ( dest == NULL ) return errlogargs();
    if ( time_1 == NULL ) return errlogargs();
    if ( time_2 == NULL ) return errlogargs();

    struct timespec temp_time_1;
    struct timespec temp_time_2;
    
    temp_time_1.tv_sec = time_1->tv_sec;
    temp_time_1.tv_nsec = time_1->tv_nsec;
    temp_time_2.tv_sec = time_2->tv_sec;
    temp_time_2.tv_nsec = time_2->tv_nsec;

    dest->tv_sec = temp_time_1.tv_sec + temp_time_2.tv_sec;
    dest->tv_nsec = temp_time_1.tv_nsec + temp_time_2.tv_nsec;
    
    if ( dest->tv_nsec >= N_SEC ) {
        dest->tv_sec  += NSEC_TO_SEC( dest->tv_nsec );
        dest->tv_nsec  = dest->tv_nsec % N_SEC;
    } else if ( dest->tv_nsec < 0 ) {
        /* This should never happen */
        dest->tv_nsec = 0;
    }

    return 0;
}

