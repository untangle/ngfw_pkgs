/*
 * $HeadURL: svn://chef/work/src/libnetcap/src/barfight_shield.h $
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

#ifndef __BARFIGHT_BOUNCER_SHIELD_H_
#define __BARFIGHT_BOUNCER_SHIELD_H_

#include <netinet/in.h>
#include <pthread.h>

#include "utils/lru.h"

#include "bouncer/config.h"
#include "bouncer/debug.h"
#include "bouncer/load.h"


#define NC_SHIELD_DEBUG_LOW   7
#define NC_SHIELD_DEBUG_HIGH 11

// This is the maximum value for the divider, 200.1, to allow for 200.0
#define NC_SHIELD_DIVIDER_MAX  ( 200.1 )

// This is the minimum value for the divider.
#define NC_SHIELD_DIVIDER_MIN  ( 1.0 / 50.0 )

enum {
    NC_SHIELD_ERR_1 = 5,
    NC_SHIELD_ERR_2 = 15,
    NC_SHIELD_ERR_3 = 45,
    NC_SHIELD_ERR_4 = 80
};

typedef enum  {
    NC_SHIELD_MODE_RELAXED,
    NC_SHIELD_MODE_LAX,
    NC_SHIELD_MODE_TIGHT,
    NC_SHIELD_MODE_CLOSED
} barfight_shield_mode_t;

#define NC_SHIELD_MODE_MAX NC_SHIELD_MODE_CLOSED

int barfight_shield_init( void );

int barfight_shield_destroy( void );

typedef enum {
    NC_SHIELD_RESET,    /* Do not let them in, and reset their connection */
    NC_SHIELD_DROP,     /* Do not let them in, but drop their connection (For now always use DROP mode) */
    NC_SHIELD_LIMITED,  /* Let them in, with "limited" access */
    NC_SHIELD_YES       /* Let them in. */
} barfight_shield_ans_t;

typedef struct {
    u_char ans;
    double reputation;
} barfight_shield_response_t;

typedef struct
{
    pthread_mutex_t mutex;
    
    /* Node to track this item inside of the LRU */
    barfight_lru_node_t lru_node;

    /* This is the debug count, used to dump all of the nodes */
    u_int32_t debug_id;

    /* Configuration data */
    double divider;

    /* Allows the host to do whatever they want. */
    int pass_all;

    struct in_addr ip;

    int             active_sessions;
        
    nc_shield_score_t score;         /* The current score for the IP */
    barfight_load_t   evil_load;     /* Evil events per second */
    barfight_load_t   request_load;  /* Number of request this IP makes */
    barfight_load_t   accept_load;   /* Number of accepted requests */
    
    barfight_load_t   session_load;  /* Active number of sessions used */
    barfight_load_t   srv_conn_load; /* Server connections load */
    barfight_load_t   srv_fail_load; /* Load of failed connection attempts */
    barfight_load_t   tcp_chk_load;  /* TCP chunk load */
    barfight_load_t   udp_chk_load;  /* UDP chunk load */
    barfight_load_t   icmp_chk_load; /* ICMP chunk load */
    barfight_load_t   byte_load;     /* Byte load */
    barfight_load_t   print_load;    /* Printing rate, limited to x per second */
    barfight_load_t   lru_load;      /* LRU rate, limited to x per second */
} nc_shield_reputation_t;

/* Indicate if an IP should allowed in */
int barfight_shield_rep_check ( barfight_shield_response_t* response, struct in_addr* ip, int protocol );

int barfight_shield_rep_add_request  ( struct in_addr* ip );

int barfight_shield_rep_add_accept   ( struct in_addr* ip );

int barfight_shield_rep_add_session  ( struct in_addr* ip );

int barfight_shield_rep_add_srv_conn ( struct in_addr* ip );

int barfight_shield_rep_add_srv_fail ( struct in_addr* ip );

int barfight_shield_rep_blame        ( struct in_addr* ip, int amount );

/* Local utility functions that should only used internally by the shield */

/* Donate a thread to update the mode */
int nc_shield_mode_init( bouncer_shield_config_t* config, nc_shield_reputation_t* root_rep, 
                         barfight_shield_mode_t* mode, nc_shield_fence_t** fence );

/* Tell the mode thread to exit */
int nc_shield_mode_destroy( void );

/* Update the loads for a reputation */
int nc_shield_reputation_update( nc_shield_reputation_t* reputation );

/**
 * Reconfigure all of the node settings 
 */
int barfight_shield_bless_users( barfight_shield_bless_array_t* nodes );

/**
 * barfight_shield_rep_add_chunk: Add a chunk to the reputation of ip.
 *  ip: The IP to add the chunk against.
 *  protocol: Either IPPROTO_UDP, IPPROTO_ICMP or IPPROTO_TCP.
 *  size: Size of the chunk in bytes.
 */
int   barfight_shield_rep_add_chunk      ( struct in_addr* ip, int protocol, u_short size );

/**
 * barfight_shield_rep_end_session: Inform the shield that IP has ended a session.
 */
int   barfight_shield_rep_end_session    ( struct in_addr* ip );

/* Load in a new shield configuration */
int   barfight_shield_set_config         ( bouncer_shield_config_t* config );

/* Get the current shield configuration. */
int   barfight_shield_get_config         ( bouncer_shield_config_t* config );

/* Dump out the current shield configuration */
int barfight_bouncer_shield_debug( barfight_bouncer_debug_print_t* print, void* arg );

#endif /* __BARFIGHT_SHIELD_H_ */
