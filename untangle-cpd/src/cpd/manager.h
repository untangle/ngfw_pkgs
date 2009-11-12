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

#ifndef __CPD_MANAGER_H_
#define __CPD_MANAGER_H_

#include <netinet/ip.h>
#include <netinet/ether.h>
#include <cpd.h>


typedef struct
{
    /* This is the current username for this host. */
    char username[CPD_MAX_USERNAME_LENGTH];
    
    /* This is the MAC Address for this IP, this can be all zeros if the host is routed. */
    struct ether_addr hw_addr;
    
    /* This is the IPV4 Address for this host entry */
    struct in_addr ipv4_addr;

    /* This is the last time a packet was seen. (MONOTONIC time). */
    struct timespec last_session;

    /* This is when the session started */
    struct timespec session_start_time;
} cpd_manager_host_entry_t;

int cpd_manager_init( cpd_config_t* config );

void cpd_manager_destroy( void );

/**
 * Copies in the config to the global config
 */
int cpd_manager_set_config( cpd_config_t* config );

/**
 * Gets the config
 */
int cpd_manager_get_config( cpd_config_t* config );

#endif // #ifndef __CPD_MANAGER_H_
