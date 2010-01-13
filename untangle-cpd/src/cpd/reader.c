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

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <libipulog/libipulog.h>

#include <mvutil/errlog.h>
#include <mvutil/debug.h>

#include "cpd/reader.h"

#define DEFAULT_RCVBUF_SIZE 131071

static int _handle_read_event( cpd_reader_t* reader, unsigned char* buffer, ssize_t buffer_size );

static char shutdown_message[] = "shutdown";

cpd_reader_t* cpd_reader_malloc( void )
{
    cpd_reader_t* reader = NULL;

    if (( reader = calloc( 1, sizeof( cpd_reader_t ))) == NULL ) {
        return errlogmalloc_null();
    }

    return reader;
}

int cpd_reader_init( cpd_reader_t* reader, int group )
{
    if ( reader == NULL ) {
        return errlogargs();
    }

    if ( reader->handle != NULL ) {
        return errlogargs();
    }

    bzero( reader, sizeof( cpd_reader_t ));
    
    if ( mailbox_init( &reader->mailbox ) < 0 ) {
        return errlog( ERR_CRITICAL, "mailbox_init\n" );
    }

    if (( reader->handle = ipulog_create_handle( ipulog_group2gmask( group ), DEFAULT_RCVBUF_SIZE )) == NULL ) {
        return errlog( ERR_CRITICAL, "ipulog_create_handle: '%s'\n", ipulog_strerror( ipulog_errno ));
    }
    reader->group = group;
    return 0;
}

cpd_reader_t* cpd_reader_create( int group )
{
    cpd_reader_t* reader = NULL;

    if (( reader = cpd_reader_malloc()) == NULL ) {
        return errlog_null( ERR_CRITICAL, "cpd_reader_malloc\n" );
    }

    if ( cpd_reader_init( reader, group ) < 0 ) {
        return errlog_null( ERR_CRITICAL, "cpd_reader_init\n" );
    }

    return reader;
}

void cpd_reader_free( cpd_reader_t* reader )
{
    if ( reader == NULL ) {
        errlogargs();
        return;
    }

    free( reader );
}

void cpd_reader_destroy( cpd_reader_t* reader )
{
    if ( reader == NULL ) {
        errlogargs();
        return;
    }

    if  ( reader->handle != NULL ) {
        ipulog_destroy_handle( reader->handle );
    }

    mailbox_destroy( &reader->mailbox );
    
    bzero( reader, sizeof( cpd_reader_t ));
}

void cpd_reader_raze( cpd_reader_t* reader )
{
    cpd_reader_destroy( reader );
    cpd_reader_free( reader );
}

void* cpd_reader_donate_thread( void* arg )
{
    cpd_reader_t* reader = (cpd_reader_t*)arg;
    if ( reader == NULL ) {
        return errlogargs_null();
    }

    unsigned char* buffer = NULL;
    int buffer_len = 150000;
    if (( buffer = calloc( 1, buffer_len )) == NULL ) {
        return errlogmalloc_null();
    }
    
    /* The message to stop is sent by changing the value of the thread */
    fd_set rfds;
    int mailbox_fd;
    int nflog_fd;
    int nfds;
    int ret;
    struct timeval tv;

    if (( mailbox_fd = mailbox_get_pollable_event( &reader->mailbox )) < 0 ) {
        return errlog_null( ERR_CRITICAL, "mailbox_get_pollable_event\n" );
    }
    
    if (( nflog_fd = ipulog_get_fd( reader->handle )) < 0 ) {
        return errlog_null( ERR_CRITICAL, "ipulog_get_fd\n" );
    }
    
    nfds = (( mailbox_fd > nflog_fd ) ? mailbox_fd : nflog_fd ) + 1;
    
    reader->is_running = 1;
    
    while( reader->is_running ) {
        FD_ZERO(&rfds);
        FD_SET(mailbox_fd, &rfds);
        FD_SET(nflog_fd, &rfds);
        
        tv.tv_sec = 2;
        tv.tv_usec = 0;
        
        debug( 11, "Starting select\n" );
        if (( ret = select( nfds, &rfds, NULL, NULL, &tv )) < 0 ) {
            perrlog("select, sleeping 1 second to avoid spinning.");
            sleep( 1 );
        } else if ( ret > 0 ) {
            if ( FD_ISSET(mailbox_fd, &rfds )) {
                /* Received a message, exiting */
                debug( 10, "Received a shutdown message, exiting.\n" );
                reader->is_running = 0;
                break;
            }
            if ( FD_ISSET(nflog_fd, &rfds )) {
                debug( 11, "nflog fd is ready to read.\n" );
                if ( _handle_read_event( reader, buffer, buffer_len ) < 0 ) {
                    errlog( ERR_CRITICAL, "_handle_read_event(sleeping 1)\n" );
                    sleep( 1 );
                }
            }
        } else {
            debug( 11, "No packets after select\n" );
            /* Nothing to do */
        }
    }        

    return NULL;
}

int cpd_reader_exit( cpd_reader_t* reader, int timeout )
{
    if ( reader == NULL ) {
        return errlogargs();
    }

    if ( timeout <= 0 ) {
        return errlogargs();
    }

    /* No longer running, nothing to do. */
    if ( reader->is_running == 0 ) {
        return 1;
    }
    
    debug( 9, "Sent reader a shutdown message\n" );

    if ( mailbox_put( &reader->mailbox, shutdown_message ) < 0 ) {
        return errlog( ERR_CRITICAL, "mailbox_put\n" );
    }

    debug( 9, "Waiting %d seconds for shutdown\n", timeout );

    for ( int c = 0 ; c < timeout ; c++ ) {
        if ( reader->is_running ) {
            sleep( 1 );
        } else {
            break;
        }
    }
    
    return reader->is_running;
}


static int _handle_read_event( cpd_reader_t* reader, unsigned char* buffer, ssize_t buffer_size )
{
    int read_size = 0;
    ulog_packet_msg_t *packet_msg = NULL;

    if (( read_size = ipulog_read( reader->handle, buffer, 150000, 1 )) <= 0 ) {
        return errlog( ERR_CRITICAL, "ipulog_read\n" );
    }

    while (( packet_msg = ipulog_get_packet( reader->handle, buffer, read_size )) != NULL ) {
        debug( 10, "Read a packet. %#010x\n", packet_msg->timestamp_sec );
    }

    return 0;
}
