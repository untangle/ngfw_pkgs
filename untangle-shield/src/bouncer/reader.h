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

#ifndef __BARFIGHT_BOUNCER_READER_H_
#define __BARFIGHT_BOUNCER_READER_H_

#include <pthread.h>

#include "bouncer/logs.h"
#include "net/nfqueue.h"

typedef struct
{
    /* This is the queue to read from */
    barfight_net_nfqueue_t* nfqueue;

    /* This is where to report the logs to. */
    barfight_bouncer_logs_t* logs;

    /* Pipe used to tell the queue to shutdown */
    int shutdown_pipe[2];

    /* The thread that is running this reader. */
    pthread_t thread;

    /* Mutex for startup and shutdown */
    pthread_mutex_t mutex;
} barfight_bouncer_reader_t;

/**
 * Allocate memory to store a reader structure.
 */
barfight_bouncer_reader_t* barfight_bouncer_reader_malloc( void );

/**
 * @param nfqueue The queue to read from.
 */
int barfight_bouncer_reader_init( barfight_bouncer_reader_t* reader, barfight_net_nfqueue_t* nfqueue,
                                  barfight_bouncer_logs_t* logs );

/**
 * @param nfqueue The queue to read from.
 */
barfight_bouncer_reader_t* barfight_bouncer_reader_create( barfight_net_nfqueue_t* nfqueue,
                                                           barfight_bouncer_logs_t* logs );

void barfight_bouncer_reader_raze( barfight_bouncer_reader_t* reader );
void barfight_bouncer_reader_destroy( barfight_bouncer_reader_t* reader );
void barfight_bouncer_reader_free( barfight_bouncer_reader_t* reader );

/* Donate a thread for the reader (pass the reader in as the argument to pthread_create) */
void *barfight_bouncer_reader_donate( void* reader );

/* Stop a running thread for a reader */
int barfight_bouncer_reader_stop( barfight_bouncer_reader_t* reader );

#endif // #ifndef __BARFIGHT_BOUNCER_READER_H_

