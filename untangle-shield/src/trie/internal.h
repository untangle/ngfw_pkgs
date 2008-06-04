/*
 * $HeadURL: svn://chef/work/src/libnetcap/src/barfight_trie_support.h $
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

#ifndef __NETCAP_TRIE_SUPPORT_H_
#define __NETCAP_TRIE_SUPPORT_H_

#include "trie/trie.h"

#define MAX(a,b) ((a) > (b)) ? (a) : (b)
#define MIN(a,b) ((a) < (b)) ? (a) : (b)
     
int barfight_trie_internal_insert     ( barfight_trie_t* trie, barfight_trie_element_t element );

int barfight_trie_internal_remove     ( barfight_trie_t* trie, barfight_trie_element_t element );

static __inline__ void _data_destroy ( barfight_trie_t* trie, barfight_trie_element_t element )
{
    if  ( element.base->data != NULL ) { 
        if ( trie->destroy != NULL ) trie->destroy ( element.item );
        if ( trie->flags & NC_TRIE_FREE ) free ( element.base->data );
        element.base->data = NULL;
    }
}

/* Item */
barfight_trie_item_t*  barfight_trie_item_malloc   ( barfight_trie_t* trie );

int                  barfight_trie_item_init     ( barfight_trie_t* trie, barfight_trie_item_t* item,
                                                 barfight_trie_level_t* parent, u_char pos, u_char depth );

barfight_trie_item_t*  barfight_trie_item_create   ( barfight_trie_t* trie, barfight_trie_level_t* parent,
                                                 u_char pos, u_char depth );

void                 barfight_trie_item_free     ( barfight_trie_t* trie, barfight_trie_item_t* item );

void                 barfight_trie_item_destroy  ( barfight_trie_t* trie, barfight_trie_item_t* item );

void                 barfight_trie_item_raze     ( barfight_trie_t* trie, barfight_trie_item_t* item );

/* This copies the data itself, not a barfight_trie_item */
int                  barfight_trie_init_data     ( barfight_trie_t* trie, barfight_trie_base_t* dest, void* src, 
                                                 struct in_addr* ip, int depth );

barfight_trie_level_t* barfight_trie_level_malloc     ( barfight_trie_t* trie );

int                  barfight_trie_level_init       ( barfight_trie_t* trie, barfight_trie_level_t* level, 
                                                    barfight_trie_level_t* parent, u_char pos, u_char depth );

barfight_trie_level_t* barfight_trie_level_create     ( barfight_trie_t* trie, barfight_trie_level_t* parent,
                                                    u_char pos, u_char depth );
 
void                 barfight_trie_level_free       ( barfight_trie_t* trie, barfight_trie_level_t* level );

void                 barfight_trie_level_destroy    ( barfight_trie_t* trie, barfight_trie_level_t* level );

void                 barfight_trie_level_raze       ( barfight_trie_t* trie, barfight_trie_level_t* level );

int                  barfight_trie_level_insert     ( barfight_trie_t* trie, barfight_trie_level_t* level, 
                                                    barfight_trie_element_t element, u_char pos );

int                  barfight_trie_level_remove     ( barfight_trie_t* trie, barfight_trie_level_t* level, 
                                                    u_char pos );

int                  barfight_trie_level_remove_all ( barfight_trie_t* trie, barfight_trie_level_t* level );

/* Base */
int                  barfight_trie_base_init     ( barfight_trie_t* trie, barfight_trie_base_t* base, 
                                                 barfight_trie_level_t* parent, u_char if_level, 
                                                 u_char pos, u_char depth );

void                 barfight_trie_base_destroy  ( barfight_trie_t* trie, barfight_trie_base_t* base );

/* Elements */
void                 barfight_trie_element_destroy ( barfight_trie_t* trie, barfight_trie_element_t element );

void                 barfight_trie_element_raze    ( barfight_trie_t* trie, barfight_trie_element_t element );

/**
 * Returns the number of children that an item has (1 for terminal nodes),      *
 * this doesn't use the mutex and the value may not be "correct", but it should *
 * be within one of the value.                                                  *
 **/
int                  barfight_trie_element_children( barfight_trie_element_t element );


/* LRU */
int barfight_trie_lru_add   ( barfight_trie_t* trie, barfight_trie_element_t element );

int barfight_trie_lru_del   ( barfight_trie_t* trie, barfight_trie_element_t element );

int barfight_trie_lru_front ( barfight_trie_t* trie, barfight_trie_element_t element );

int barfight_trie_lru_trash ( barfight_trie_t* trie, barfight_trie_element_t trash );

/* put all of the nodes into the trash, and then wait for the trash to be emptied */
int barfight_trie_lru_clean ( barfight_trie_t* trie );

#endif // #ifndef __NETCAP_TRIE_SUPPORT_H_
