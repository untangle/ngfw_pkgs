/*
 * $HeadURL: svn://chef/work/src/libnetcap/src/barfight_shield_cfg.h $
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

#ifndef __BARFIGHT_BOUNCER_CONFIG_H_
#define __BARFIGHT_BOUNCER_CONFIG_H_

/* A limit check to make sure it doesn't go into a long loop */
#define BLESS_COUNT_MAX        128

#include <netinet/in.h>

#include <json/json.h>


typedef double nc_shield_score_t;

typedef struct {
    double lax;
    double tight;
    double closed;
} nc_shield_limit_t;

typedef struct {
    /* Probability the fence post is used, if it isn't the level below is used */
    double          prob;
    nc_shield_score_t post;
} nc_shield_post_t;

typedef struct {
    /* Percent to inhert at each node */
    double           inheritance;
    /* IP access should be limited */
    nc_shield_post_t limited;
    /* IP should not be given access */
    nc_shield_post_t closed;
    /* IP is using an excessive amount of resources and may be notified */
    nc_shield_post_t error;
} nc_shield_fence_t;

typedef struct
{
    double divider;
    struct in_addr address;
    struct in_addr netmask;
} barfight_shield_bless_t;

typedef struct {
    int count;
    barfight_shield_bless_t* d;
} barfight_shield_bless_array_t;

typedef struct {
    struct {
        nc_shield_limit_t cpu_load;
        nc_shield_limit_t sessions;
        nc_shield_limit_t request_load;
        nc_shield_limit_t session_load;
        nc_shield_limit_t tcp_chk_load;
        nc_shield_limit_t udp_chk_load;
        nc_shield_limit_t icmp_chk_load;
        nc_shield_limit_t evil_load;
    } limit;
    
    struct {
        double request_load;
        double session_load;
        double evil_load;
        double tcp_chk_load;
        double udp_chk_load;
        double icmp_chk_load;
        double active_sess;
    } mult;

    struct {
        int low_water;
        int high_water;

        /** Parameters to control the removal of "dead" nodes */
        /** Number of items to look through at the end of the LRU for inactive nodes */
        int sieve_size;
    
        /** Rate at which active nodes should be moved to the front of the LRU */
        double ip_rate;
    } lru;
        
    struct {
        nc_shield_fence_t relaxed;
        nc_shield_fence_t lax;
        nc_shield_fence_t tight;
        nc_shield_fence_t closed;
    } fence;

    /* Used to track how often to print reputation debugging */
    int print_delay;

    /** If a reputation exceeds this threshold, debugging messages are
     * printed out for a reputation. */
    double rep_threshold;

    /* This is number of milliseconds before rotating the circular logs. */
    int log_rotate_delay_ms;

    /* This is the number of items that are inside of logs */
    int log_size;

    barfight_shield_bless_t bless_data[128];
    barfight_shield_bless_array_t bless_array;    
} bouncer_shield_config_t;

/* Load the default shield configuration */
int bouncer_shield_config_default( bouncer_shield_config_t* config );

/* This parser buffer as a JSON object and loads it */
int bouncer_shield_config_load( bouncer_shield_config_t* config, char* buffer, int buffer_len );

int bouncer_shield_config_load_json( bouncer_shield_config_t* config, struct json_object* object );

/* Convert the current configuration to a JSON string */
struct json_object* bouncer_shield_config_to_json( bouncer_shield_config_t* config );

/* Convert an array of JSON user and fill in a bless array */
int bouncer_shield_config_load_bless_json( barfight_shield_bless_array_t* bless_array,
                                           struct json_object* bless_array_json );

#endif // __BARFIGHT_BOUNCER_CONFIG_H_

