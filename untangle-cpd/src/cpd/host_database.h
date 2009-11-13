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

#ifndef __CPD_HOST_DATABASE_H_
#define __CPD_HOST_DATABASE_H_

#include <netinet/ip.h>
#include <netinet/ether.h>

#include <mvutil/hash.h>

#include "cpd.h"


typedef struct
{
    char u[CPD_MAX_USERNAME_LENGTH];
} cpd_host_database_username_t;

typedef struct
{
    /* This is the current username for this host. */
    cpd_host_database_username_t username;
    
    /* Indicates whether the entry has a unique MAC Address.  For
     * instance, if the item was routed to the host through a gateway,
     * there is no unique mac address */
    int has_hw_addr;

    /* This is the MAC Address for this IP, this can be all zeros if the host is routed. */
    struct ether_addr hw_addr;
    
    /* This is the IPV4 Address for this host entry */
    struct in_addr ipv4_addr;

    /* This is the last time a packet was seen. (MONOTONIC time). */
    struct timespec last_session;

    /* This is when the session started */
    struct timespec session_start_time;

    /* The node in the linked list that contains the memory. */
    struct list_node* list_node;
} cpd_host_database_entry_t;

typedef struct
{
    /* Hash from a mac address to a host entry. */
    ht_t* hw_addr_to_entry;
    
    /* Hash from an IP Address to a host entry */
    ht_t* ipv4_addr_to_entry;

    /* Linked list of all of the host entries */
    list_t* entry_list;
} cpd_host_database_t;

cpd_host_database_t* cpd_host_database_malloc( void );
int cpd_host_database_init( cpd_host_database_t* );
cpd_host_database_t* cpd_host_database_create( void );

void cpd_host_database_free( cpd_host_database_t* host_database );
void cpd_host_database_destroy( cpd_host_database_t* host_database );
void cpd_host_database_raze( cpd_host_database_t* host_database );

int cpd_host_database_replace( cpd_host_database_t* host_database, cpd_host_database_username_t* username,
                               struct ether_addr* hw_addr, struct in_addr* ipv4_addr );


/* This returns a copy of the host entry with the list node set to null. */
int cpd_host_database_get_ipv4_addr( cpd_host_database_t* host_database, 
                                     struct in_addr* ipv4_addr, cpd_host_database_entry_t* entry );

int cpd_host_database_remove_ipv4_addr( cpd_host_database_t* host_database, 
                                        struct in_addr* ipv4_addr, cpd_host_database_entry_t* entry );

/* This returns a copy of the host entry with the list node set to null. */
int cpd_host_database_get_hw_addr( cpd_host_database_t* host_database, 
                                   struct ether_addr* hw_addr, cpd_host_database_entry_t* entry );

int cpd_host_database_remove_hw_addr( cpd_host_database_t* host_database, 
                                      struct ether_addr* hw_addr, cpd_host_database_entry_t* entry );


#endif // #ifndef __CPD_HOST_DATABASE_H_
