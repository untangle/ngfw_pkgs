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

#ifndef __CPD_READER_H_
#define __CPD_READER_H_

#include <pthread.h>
#include <libipulog/libipulog.h>

#include <mvutil/mailbox.h>

typedef struct 
{
    int group;
    struct ipulog_handle* handle;
    volatile int is_running;
    mailbox_t mailbox;
    pthread_mutex_t* mutex;
} cpd_reader_t;

cpd_reader_t* cpd_reader_malloc( void );

int cpd_reader_init( cpd_reader_t* reader, int group );

cpd_reader_t* cpd_reader_create( int group );

void cpd_reader_free( cpd_reader_t* reader );

void cpd_reader_destroy( cpd_reader_t* reader );

void cpd_reader_raze( cpd_reader_t* reader );

void* cpd_reader_donate_thread( void* arg );

int cpd_reader_exit( cpd_reader_t* reader, int timeout );

#endif // #ifndef __CPD_READER_H_
