/*
 * $HeadURL$
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

#include <stdlib.h>
#include <pthread.h>

/* including those here, since recent libmicrohttpd-dev in sid doesn't do
   it on its own. -- Seb, Wed, 19 Nov 2008 15:10:30 -0800 */
#include <stdarg.h>
#include <sys/socket.h>
#include <microhttpd.h>


#include <mvutil/debug.h>
#include <mvutil/errlog.h>
#include <mvutil/unet.h>

#include "json/object_utils.h"
#include "json/server.h"

#include "bouncer/shield.h"
#include "utils/lru.h"

#include "trie/trie.h"
#include "trie/internal.h"


static int _dump_node_list( list_t* list, u_int32_t debug_id,
                            barfight_bouncer_debug_print_t* print, void* arg );

static int _dump_item( barfight_trie_item_t* item, u_int32_t debug_id, 
                       barfight_bouncer_debug_print_t* print, void* arg );

int barfight_bouncer_debug_dump_nodes( barfight_lru_t* lru, u_int32_t* debug_id,
                                       barfight_bouncer_debug_print_t* print, void* arg )
{
    if ( lru == NULL ) return errlogargs();

    if ( print == NULL ) return errlogargs();
    if ( debug_id == NULL ) return errlogargs();
    u_int32_t new_debug_id = *debug_id + 1;
    
    if ( _dump_node_list( &lru->permanent_list, new_debug_id, print, arg ) < 0 ) {
        return errlog( ERR_CRITICAL, "_dump_node_list\n" );
    }
    
    if ( _dump_node_list( &lru->lru_list, new_debug_id, print, arg ) < 0 ) {
        return errlog( ERR_CRITICAL, "_dump_node_list\n" );
    }

    *debug_id = new_debug_id;
    
    return 0;
}

struct json_object* barfight_bouncer_debug_node_to_json( barfight_trie_element_t element )
{
    nc_shield_reputation_t* reputation = NULL;
    if ( element.base == NULL ) return errlog_null( ERR_CRITICAL, "NULL Argument" );

    if (( reputation = element.base->data ) == NULL ) {
        return errlog_null( ERR_CRITICAL, "Invalid element\n" );
    }

    struct json_object* json_object = NULL;

    char *temp_string = NULL;

    int _critical_section() {
        if ( json_object_utils_add_int( json_object, "depth", element.base->depth ) < 0 ) {
            return errlog( ERR_CRITICAL, "json_object_utils_add_int\n" );
        }

        temp_string = unet_next_inet_ntoa( reputation->ip.s_addr );
        if ( json_object_utils_add_string( json_object, "ip", temp_string ) < 0 ) {
            return errlog( ERR_CRITICAL, "json_object_utils_add_string\n" );
        }

        if ( json_object_utils_add_double( json_object, "divider", reputation->divider ) < 0 ) {
            return errlog( ERR_CRITICAL, "json_object_utils_add_double\n" );
        }

        if ( json_object_utils_add_double( json_object, "request", reputation->request_load.load ) < 0 ) {
            return errlog( ERR_CRITICAL, "json_object_utils_add_double\n" );
        }

        if ( json_object_utils_add_double( json_object, "accept", reputation->accept_load.load ) < 0 ) {
            return errlog( ERR_CRITICAL, "json_object_utils_add_double\n" );
        }

        if ( json_object_utils_add_int( json_object, "children", barfight_trie_element_children( element )) < 0 ) {
            return errlog( ERR_CRITICAL, "json_object_utils_add_double\n" );
        }

        if ( json_object_utils_add_double( json_object, "score", reputation->score ) < 0 ) {
            return errlog( ERR_CRITICAL, "json_object_utils_add_double\n" );
        }

        return 0;
    }

    if (( json_object = json_object_new_object()) == NULL ) {
        return errlog_null( ERR_CRITICAL, "json_object_new_object\n" );
    }

    int ret = _critical_section();

    if ( ret < 0 ) {
        json_object_put( json_object );
        return errlog_null( ERR_CRITICAL, "_critical_section\n" );
    }

    return json_object;
}

static int _dump_node_list( list_t* list, u_int32_t debug_id, 
                            barfight_bouncer_debug_print_t* print, void* arg )
{
    list_node_t* node = NULL;
    barfight_lru_node_t* lru_node = NULL;
    barfight_trie_item_t* item = NULL;

    for ( node = list_head( list ); node != NULL ; node = list_node_next( node )) {
        if (( lru_node = list_node_val( node )) == NULL ) return errlog( ERR_CRITICAL, "list_node_val\n" );

        if (( item = lru_node->data ) == NULL ) return errlog( ERR_CRITICAL, "NULL lru_node data.\n" );
        
        if ( _dump_item( item, debug_id, print, arg ) < 0 ) return errlog( ERR_CRITICAL, "_dump_item\n" );
    }

    return 0;
}

static int _dump_item( barfight_trie_item_t* _item, u_int32_t debug_id,
                       barfight_bouncer_debug_print_t* print, void* arg )
{
    nc_shield_reputation_t* reputation = NULL;
    
    barfight_trie_element_t item;

    item.base = _item;

    for (  ; item.base != NULL ; item.level = item.base->parent ) {
        if (( reputation = item.base->data ) == NULL ) return errlog( ERR_CRITICAL, "Invalid trie item\n" );

        /* This way nodes are not printed twice */
        if ( reputation->debug_id == debug_id ) break;
        
        reputation->debug_id = debug_id;
        
        if ( print( item, arg ) < 0 ) return errlog( ERR_CRITICAL, "print\n" );
    }

    return 0;
}


