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

#ifndef __BARFIGHT_BOUNCER_DEBUG_H_
#define __BARFIGHT_BOUNCER_DEBUG_H_

#include "trie/trie.h"
#include "utils/lru.h"

typedef int (barfight_bouncer_debug_print_t)( barfight_trie_element_t element, void *arg );

int barfight_bouncer_debug_dump_nodes( barfight_lru_t* lru, u_int32_t* debug_id,
                                       barfight_bouncer_debug_print_t* print, void* arg );

struct json_object* barfight_bouncer_debug_node_to_json( barfight_trie_element_t element );
                                       

#endif // #ifndef __BARFIGHT_BOUNCER_DEBUG_H_
