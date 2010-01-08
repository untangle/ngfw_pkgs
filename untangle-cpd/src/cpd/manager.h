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


#include "cpd.h"
#include "cpd/host_database.h"


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

int cpd_manager_init( cpd_config_t* config, char* sqlite_file, char* lua_script );

void cpd_manager_destroy( void );

/**
 * Copies in the config to the global config
 */
int cpd_manager_set_config( cpd_config_t* config );

/**
 * Gets the config
 */
int cpd_manager_get_config( cpd_config_t* config );

/**
 * Retrieve the status of the CPD daemon
 */
int cpd_manager_get_status( cpd_status_t* status );

int cpd_manager_replace_host( cpd_host_database_username_t* username, 
                              struct ether_addr* hw_addr, struct in_addr* addr, 
                              int update_session_start );

int cpd_manager_remove_ipv4_addr( struct in_addr* ipv4_addr );

int cpd_manager_remove_hw_addr( struct ether_addr* hw_addr );

/**
 * Remove all of the entries in the host database.
 * @return The number of entries that were removed.
 */
int cpd_manager_clear_host_database( void );

/**
 * Remove all of the expired entries.
 * @return The number of entries that were removed.
 */
int cpd_manager_expire_sessions( void );



#endif // #ifndef __CPD_MANAGER_H_
