/*
 * $HeadURL: svn://chef/work/src/libnetcap/src/barfight_trie_level.c $
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

#include <stdlib.h>

#include <mvutil/debug.h>
#include <mvutil/errlog.h>

#include "trie/trie.h"
#include "trie/internal.h"

 
barfight_trie_level_t* barfight_trie_level_malloc     ( barfight_trie_t* trie )
{
    barfight_trie_level_t* level;

    if ( (level = calloc(1,sizeof(barfight_trie_level_t))) == NULL ) return errlogmalloc_null();

    return level;
}

int                  barfight_trie_level_init       ( barfight_trie_t* trie, barfight_trie_level_t* level, 
                                                    barfight_trie_level_t* parent, u_char pos, u_char depth )
{
    if ( level == NULL || trie == NULL ) return errlogargs();
    
    bzero( level, sizeof(barfight_trie_level_t) );
    
    /* Redundant due to bzero */
    level->num_children = 0;
    
    /* Initialize the base */
    if ( barfight_trie_base_init( trie, &level->base, parent, NC_TRIE_BASE_LEVEL, pos, depth ) < 0 ) {
        return errlog(ERR_CRITICAL, "barfight_trie_base_init\n");
    }
   
    level->count = 0;
    
    return 0;
}

barfight_trie_level_t* barfight_trie_level_create     ( barfight_trie_t* trie, barfight_trie_level_t* parent,
                                                    u_char pos, u_char depth )
{
    barfight_trie_level_t* level;

    if ( ( level = barfight_trie_level_malloc( trie ) ) == NULL ) {
        return errlog_null(ERR_CRITICAL,"barfight_trie_level_malloc");
    }
    
    if ( barfight_trie_level_init( trie, level, parent, pos, depth ) < 0 ) {
        return errlog_null(ERR_CRITICAL,"barfight_trie_level_init");
    }
    
    return level;
}
 
void                 barfight_trie_level_free       ( barfight_trie_t* trie, barfight_trie_level_t* level )
{
    if ( trie == NULL || level == NULL ) return (void)errlogargs();

    if ( level->base.type != NC_TRIE_BASE_LEVEL ) {
        return (void)errlog(ERR_CRITICAL,"TRIE: Freeing a non-level as an item\n");
    }

    
    free( level );
}

void                 barfight_trie_level_destroy    ( barfight_trie_t* trie, barfight_trie_level_t* level )
{
    if ( trie == NULL || level == NULL ) return (void)errlogargs();

    if ( level->base.type != NC_TRIE_BASE_LEVEL ) {
        return (void)errlog(ERR_CRITICAL,"TRIE: Destroying a non-level as a level\n");
    }

    level->base.parent = NULL;

    /* It is assumed that all of the items have already been removed */
    // barfight_trie_level_remove_all ( trie, level );
    
    /* Destroy the base */
    barfight_trie_base_destroy ( trie, &level->base );
}

void                 barfight_trie_level_raze       ( barfight_trie_t* trie, barfight_trie_level_t* level )
{
    if ( trie == NULL || level == NULL ) return (void)errlogargs();

    if ( level->base.type != NC_TRIE_BASE_LEVEL ) {
        return (void)errlog(ERR_CRITICAL,"TRIE: Razing a non-level as a level\n");
    }

    barfight_trie_level_destroy ( trie, level );

    barfight_trie_level_free( trie, level );
}

int                  barfight_trie_level_insert     ( barfight_trie_t* trie, barfight_trie_level_t* level, 
                                                    barfight_trie_element_t element, u_char pos )
{
    int ret = 0;
    
    if ( trie == NULL || level == NULL || element.base == NULL ) return errlogargs();

    if ( level->base.type != NC_TRIE_BASE_LEVEL ) {
        return errlog( ERR_CRITICAL, "TRIE: Inserting an item into a non-level\n");
    }

    if ( level->r[pos].base == NULL ) {
        if ( level->count >= NC_TRIE_ROW_SIZE ) {
            errlog(ERR_CRITICAL,"TRIE: invalid level count\n");
        } else {
            ret = 1;
            level->count++;
        }

        barfight_trie_internal_insert ( trie, element );
    } else {
        barfight_trie_element_raze ( trie, level->r[pos] );
    }
    
    level->r[pos] = element;
    return ret;
}

int                  barfight_trie_level_remove     ( barfight_trie_t* trie, barfight_trie_level_t* level,
                                                    u_char pos )
{
    if ( trie == NULL || level == NULL ) return errlogargs();

    if ( level->base.type != NC_TRIE_BASE_LEVEL ) {
        return errlog( ERR_CRITICAL, "TRIE: Unable to remove an item from a non-level\n");
    }
    
    if ( level->r[pos].base == NULL ) {
        return errlog(ERR_WARNING, "TRIE: element at position %d does not exist\n",pos);
    } else {
        barfight_trie_internal_remove ( trie, level->r[pos] );
        
        barfight_trie_element_raze( trie, level->r[pos] );

        level->r[pos].base = NULL;
        if ( level->count < 0 ) {
            errlog( ERR_WARNING, "TRIE: invalid level count\n");
            level->count = 0;
        } else level->count--;
    }
    
    return 0;
}

int                  barfight_trie_level_remove_all ( barfight_trie_t* trie, barfight_trie_level_t* level )
{
    int c;
    int ret = 0;

    if ( trie == NULL || level == NULL ) return errlogargs();
    
    /* Remove all of the children */
    for ( c = NC_TRIE_ROW_SIZE ; ( c-- > 0) && ( level->count > 0 ) ; ) {
        if (( level->r[c].base != NULL ) && ( barfight_trie_level_remove ( trie, level, c ) < 0 )) {
            ret -= errlog(ERR_CRITICAL,"barfight_trie_level_remove\n");
        }
    }

    return ret;
}


