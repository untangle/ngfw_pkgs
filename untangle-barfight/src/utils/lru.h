/*
 * $HeadURL: svn://chef/work/src/libnetcap/src/barfight_lru.h $
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

#ifndef _NETCAP_LRU_H_
#define _NETCAP_LRU_H_

#include <mvutil/list.h>

#define NC_LRU_DONT_DELETE 0x202A5D72

typedef int  (barfight_lru_check_t)  ( void* data );
typedef int  (barfight_lru_remove_t) ( void* data );

typedef struct
{
    /* Length of the LRU */
    int length;

    /* List for the LRU */
    list_t lru_list;
    
    /* List of nodes that are permanently non-deletable */
    list_t permanent_list;

    /* High water for the LRU */
    int high_water;

    /* Low water for the LRU */
    int low_water;

    /* Number of the items to search for one deletable item */
    int sieve_size;
    
    /* A function that determines whether or not an item is deletable */
    barfight_lru_check_t* is_deletable;

    /* A function to call !before removing the node from the LRU */
    barfight_lru_remove_t* remove;
} barfight_lru_t;

typedef struct
{
    /* Position of the node inside of the LRU */
    list_node_t* list_node;
    
    /* Must have the lock in order to change the state */
    enum
    {
        _LRU_READY     =  0x7E5873CB,  /* Node can be moved to the front of the LRU */
        _LRU_REMOVED   =  0x5D436B9B,  /* Once a node is removed, it cannot be put back onto the LRU */
        _LRU_PERMANENT =  0x769A1D28   /* Node is on the permanent LRU */
    } state;

    /* Data associated with this node */
    void* data;
} barfight_lru_node_t;

int barfight_lru_init( barfight_lru_t* lru, int high_water, int low_water, int sieve_size, 
                     barfight_lru_check_t* is_deletable, barfight_lru_remove_t* remove );

int barfight_lru_config( barfight_lru_t* lru, int high_water, int low_water, int sieve_size, 
                       pthread_mutex_t* mutex );

/* Add a node to the front of the LRU, node is updated to contain the necessary information for the LRU */
int barfight_lru_add( barfight_lru_t* lru, barfight_lru_node_t* node, void* data, pthread_mutex_t* mutex );

/* Add a node to the permanent list, if node */
int barfight_lru_permanent_add   ( barfight_lru_t* lru, barfight_lru_node_t* node, void* data,
                                 pthread_mutex_t* mutex );

/* Remove all of the nodes on the permanent list and add them to the LRU */
int barfight_lru_permanent_clear ( barfight_lru_t* lru, pthread_mutex_t* mutex );

/* Move a node to the front of the LRU, node should be a value returned from a previous
 * execution of lru_add */
int barfight_lru_move_front( barfight_lru_t* lru, barfight_lru_node_t* node, pthread_mutex_t* mutex );

/* Cut any excessive nodes, and place the results into the node_array if it is not null */
int barfight_lru_cut( barfight_lru_t* lru, barfight_lru_node_t** node_array, int node_array_size, 
                    pthread_mutex_t* mutex );

#endif // _NETCAP_LRU_H_
