/*
 * $HeadURL: svn://chef/work/src/libnetcap/src/barfight_trie.h $
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

#ifndef __NETCAP_TRIE_H_
#define __NETCAP_TRIE_H_

#include <netinet/in.h>
#include <time.h>

#include <mvutil/list.h>
#include <mvutil/mailbox.h>
#include <mvutil/hash.h>

#define NC_TRIE_DEPTH_TOTAL 4
#define NC_TRIE_LINE_COUNT_MAX ( NC_TRIE_DEPTH_TOTAL + 1 )
#define NC_TRIE_DEBUG_LOW   7
#define NC_TRIE_DEBUG_HIGH  11
#define NC_TRIE_ROW_SIZE    256

/* Just some random values to make it a little harder to accidentally free a random block of memory */
#define NC_TRIE_BASE_LEVEL  0xCB
#define NC_TRIE_BASE_ITEM   0xAC

/* This assumes all IPs are in Network Byte order */

typedef enum {
    NC_TRIE_INHERIT = 1,  /* Inherit the data from parents to children. */
    NC_TRIE_COPY    = 2,  /* Make a copy of the data when inheriting from parents to children */
    NC_TRIE_FREE    = 4   /* Free any data allocated, this is not done in remove, but in line_raze */
} barfight_trie_flags_t;

/* The items marked with !!! should only be modified when you have the mutex */
typedef struct {
    /* These are all bytes so they get packed into one word */
    /* 1 - This is a level, 0 - This is an item */
    u_char type;

    /* Depth of this trie/item, the root is at 0 */
    u_char depth;
    
    /* Position of this trie/item inside of its parent */
    u_char pos;

    /* An item at each level */
    void* data;

    struct barfight_trie_level* parent;
} barfight_trie_base_t;

typedef barfight_trie_base_t barfight_trie_item_t;

typedef union {
    barfight_trie_base_t*       base;
    struct barfight_trie_level* level;
    barfight_trie_item_t*       item;
} barfight_trie_element_t;

typedef struct barfight_trie_level {
    barfight_trie_base_t base;

    /* Number of direct descendents */
    int count;
    
    /* estimated total number of terminal child nodes for this node */
    int num_children;

    barfight_trie_element_t r[NC_TRIE_ROW_SIZE];
} barfight_trie_level_t;

typedef int  (barfight_trie_init_t)    ( barfight_trie_item_t* item, struct in_addr* ip );
typedef void (barfight_trie_destroy_t) ( barfight_trie_item_t* item );

/* The new functions */
typedef struct
{
    /* 1 if this line starts at the bottom, 0 otherwise */
    unsigned char is_bottom_up;

    /* Number of nodes the in this line */
    unsigned char count;
    
    /* Up to depth total + 1 for the root. items */
    barfight_trie_element_t d[NC_TRIE_DEPTH_TOTAL + 1];
} barfight_trie_line_t;

typedef struct {
    int   mem;        /* Total amount of memory used by this trie */
    int   flags;
    int   item_count; /* Total number of items in the trie */

    barfight_trie_level_t root;

    /* When using the NC_TRIE_COPY flag, all items must be this size */
    int   item_size;

    /* An init function, called on the item, after each new item is created */
    barfight_trie_init_t* init;
    
    /* Destroy function, called on the item, before being destroyed */
    barfight_trie_destroy_t* destroy;

    /* Hash (ip->item) of all of the terminal nodes */
    ht_t   ip_element_table;
} barfight_trie_t;

barfight_trie_t* barfight_trie_malloc  ( void );


int            barfight_trie_init    ( barfight_trie_t* trie, int flags, void* item, int item_size, 
                                     barfight_trie_init_t* init, barfight_trie_destroy_t* destroy );

barfight_trie_t* barfight_trie_create  ( int flags, void* item, int item_size, 
                                     barfight_trie_init_t* init, barfight_trie_destroy_t* destroy );

void           barfight_trie_free    ( barfight_trie_t* trie );

void           barfight_trie_destroy ( barfight_trie_t* trie );

void           barfight_trie_raze    ( barfight_trie_t* trie );

void*          barfight_trie_data    ( barfight_trie_t* trie );

void*          barfight_trie_item_data ( barfight_trie_item_t* item );

/* For all of these functions mutex is passed in, if it is non-null it is used, otherwise it is not */
/* Get the closest item to ip, this never creates a new item, never blocks */
int barfight_trie_get            ( barfight_trie_t* trie, struct in_addr* ip, barfight_trie_line_t* line );

/* Insert an item into at ip, and the fill the line with item, if the
 * item is already in the trie, this just returns its line. may use mutex. */
int barfight_trie_insert_and_get ( barfight_trie_t* trie, struct in_addr* ip, pthread_mutex_t* mutex,
                                     barfight_trie_line_t* line );

/* Remove an item from the trie and return the memory it used in <line>.
 *   Depending on the application, this memory shouldn't be freed immediately
 *   as it may be used by other threads. always grabs mutex.
 */
int barfight_trie_remove         ( barfight_trie_t* trie, struct in_addr* ip, pthread_mutex_t* mutex,
                                     barfight_trie_line_t* line );

/**
 * Remove all of the items from the trie.
 */
int barfight_trie_remove_all          ( barfight_trie_t* trie );

/* Raze a line that has been removed from the trie */
int barfight_trie_line_free      ( barfight_trie_line_t* line );
int barfight_trie_line_destroy   ( barfight_trie_t* trie, barfight_trie_line_t* line );
int barfight_trie_line_raze      ( barfight_trie_t* trie, barfight_trie_line_t* line );

#endif /* __NETCAP_TRIE_H_ */
