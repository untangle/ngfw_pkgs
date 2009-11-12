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
#include <string.h>
#include <time.h>

#include <mvutil/debug.h>
#include <mvutil/errlog.h>
#include <mvutil/unet.h>
#include <mvutil/utime.h>

#include "cpd.h"
#include "cpd/host_database.h"

#define HOST_DATABASE_HASH_SIZE 2777

static u_char _hw_addr_equ( const void* input_1, const void* input_2 );
static u_long _hw_addr_hash( const void* input_1 );

static int _remove_entry( cpd_host_database_t* host_database, cpd_host_database_entry_t* entry );

cpd_host_database_t* cpd_host_database_malloc( void )
{
    cpd_host_database_t* host_database = NULL;

    if (( host_database = calloc( 1, sizeof( cpd_host_database_t ))) == NULL ) {
        return errlogmalloc_null();
    }

    return host_database;
}

int cpd_host_database_init( cpd_host_database_t* host_database )
{
    if ( host_database == NULL ) {
        return errlogargs();
    }

    if ( host_database->hw_addr_to_entry != NULL ) {
        return errlogargs();
    }

    if ( host_database->ipv4_addr_to_entry != NULL ) {
        return errlogargs();
    }

    if ( host_database->entry_list != NULL ) {
        return errlogargs();
    }

    int _critical_section()
    {
        host_database->hw_addr_to_entry = ht_create_and_init( HOST_DATABASE_HASH_SIZE, _hw_addr_hash, 
                                                                   _hw_addr_equ, HASH_FLAG_FREE_KEY );
        if ( host_database->hw_addr_to_entry == NULL ) {
            return errlog( ERR_CRITICAL, "ht_create_and_init\n" );
        }
        
        host_database->ipv4_addr_to_entry = ht_create_and_init( HOST_DATABASE_HASH_SIZE, int_hash_func, 
                                                                     int_equ_func, 0 );
        if ( host_database->ipv4_addr_to_entry == NULL ) {
            return errlog( ERR_CRITICAL, "ht_create_and_init\n" );
        }
        
        host_database->entry_list = list_create( LIST_FLAG_FREE_VAL );
        if ( host_database->entry_list == NULL ) {
            return errlog( ERR_CRITICAL, "list_create\n" );
        }

        return 0;
    }

    if ( _critical_section() < 0 ) {
        if ( host_database->hw_addr_to_entry != NULL ) {
            ht_free( host_database->hw_addr_to_entry );
        }
        host_database->hw_addr_to_entry = NULL;
        
        if ( host_database->ipv4_addr_to_entry != NULL ) {
            ht_free( host_database->ipv4_addr_to_entry );
        }
        host_database->ipv4_addr_to_entry = NULL;
        
        if ( host_database->entry_list != NULL ) {
            list_raze( host_database->entry_list );
        }
        host_database->entry_list = NULL;

        return errlog( ERR_CRITICAL, "_critical_section\n" );
    }

    return 0;
}

cpd_host_database_t* cpd_host_database_create( void )
{
    cpd_host_database_t* host_database = NULL;

    if (( host_database = cpd_host_database_malloc()) == NULL ) {
        return errlog_null( ERR_CRITICAL, "cpd_host_database_malloc\n" );
    }

    if ( cpd_host_database_init( host_database ) < 0 ) {
        return errlog_null( ERR_CRITICAL, "cpd_host_database_init\n" );
    }

    return host_database;
}

void cpd_host_database_free( cpd_host_database_t* host_database )
{
    if ( host_database == NULL ) {
        errlogargs();
        return;
    }

    free( host_database );
}

void cpd_host_database_destroy( cpd_host_database_t* host_database )
{
    if ( host_database == NULL ) {
        errlogargs();
        return;
    }

    if ( host_database->hw_addr_to_entry != NULL ) {
        ht_free( host_database->hw_addr_to_entry );
    }
    host_database->hw_addr_to_entry = NULL;
    
    if ( host_database->ipv4_addr_to_entry != NULL ) {
        ht_free( host_database->ipv4_addr_to_entry );
    }
    host_database->ipv4_addr_to_entry = NULL;
    
    if ( host_database->entry_list != NULL ) {
        list_raze( host_database->entry_list );
    }
    host_database->entry_list = NULL;    
}

void cpd_host_database_raze( cpd_host_database_t* host_database )
{
    cpd_host_database_destroy( host_database );
    cpd_host_database_raze( host_database );
}

/* If there are existing entries, this will remove them first */
int cpd_host_database_replace( cpd_host_database_t* host_database, cpd_host_database_username_t* username,
                               struct ether_addr* hw_addr, struct in_addr* ipv4_addr )
{
    cpd_host_database_entry_t* entry = NULL;
    cpd_host_database_entry_t trash;
    
    int _critical_section()
    {
        
        if (( hw_addr != NULL ) && ( cpd_host_database_remove_hw_addr( host_database, hw_addr, &trash ) < 0 )) {
            return errlog( ERR_CRITICAL, "cpd_host_databaes_remove_hw_addr\n" );
        }

        if ( cpd_host_database_remove_ipv4_addr( host_database, ipv4_addr, &trash ) < 0 ) {
            return errlog( ERR_CRITICAL, "cpd_host_databaes_remove_ipv4_addr\n" );
        }
        
        if (( entry = calloc( 1, sizeof( cpd_host_database_entry_t ))) == NULL ) {
            return errlogmalloc();
        }

        entry->has_hw_addr = hw_addr == NULL;
        if ( hw_addr != NULL ) {
            memcpy( &entry->hw_addr.ether_addr_octet, hw_addr, sizeof( entry->hw_addr.ether_addr_octet ));
        }
        entry->ipv4_addr.s_addr = ipv4_addr->s_addr;

        clock_gettime( CLOCK_MONOTONIC, &entry->last_session );
        clock_gettime( CLOCK_MONOTONIC, &entry->session_start_time );

        if (( entry->list_node = list_add_tail( host_database->entry_list, entry )) == NULL ) {
            return errlog( ERR_CRITICAL, "list_add_tail\n" );
        }

        if ( ht_add( host_database->hw_addr_to_entry, (void*)hw_addr, entry ) < 0 ) {
            return errlog( ERR_CRITICAL, "ht_add\n" );
        }

        if ( ht_add( host_database->ipv4_addr_to_entry, (void*)ipv4_addr->s_addr, entry ) < 0 ) {
            return errlog( ERR_CRITICAL, "ht_add\n" );
        }
        
        return 0;
    }

    if ( _critical_section() < 0 ) {
        if ( entry != NULL ) {
            if ( _remove_entry( host_database, entry ) < 0 ) {
                errlog( ERR_CRITICAL, "_remove_entry\n" );
            }
        }

        return errlog( ERR_CRITICAL, "_critical_section\n" );
    }

    return 0;
}

int cpd_host_database_get_ipv4_addr( cpd_host_database_t* host_database, 
                                     struct in_addr* ipv4_addr, cpd_host_database_entry_t* entry )
{
    if ( host_database == NULL ) {
        return errlogargs();
    }

    if ( ipv4_addr == NULL ) {
        return errlogargs();
    }

    if ( entry == NULL ) {
        return errlogargs();
    }
    
    cpd_host_database_entry_t* h = NULL;

    if (( h = ht_lookup( host_database->ipv4_addr_to_entry, (void*)ipv4_addr->s_addr )) == NULL ) {
        return 0;
    }

    memcpy( entry, h, sizeof( cpd_host_database_entry_t ));
    entry->list_node = NULL;
    
    return 1;
}

int cpd_host_database_remove_ipv4_addr( cpd_host_database_t* host_database, 
                                        struct in_addr* ipv4_addr, cpd_host_database_entry_t* entry )
{
    if ( host_database == NULL ) {
        return errlogargs();
    }

    if ( ipv4_addr == NULL ) {
        return errlogargs();
    }

    if ( entry == NULL ) {
        return errlogargs();
    }

    cpd_host_database_entry_t* h = NULL;
    if (( h = ht_lookup( host_database->ipv4_addr_to_entry, (void*)ipv4_addr->s_addr )) == NULL ) {
        return 0;
    }

    memcpy( entry, h, sizeof( cpd_host_database_entry_t ));
    entry->list_node = NULL;

    if ( _remove_entry( host_database, h ) < 0 ) {
        return errlog( ERR_CRITICAL, "_remove_entry\n" );
    }
    h = NULL;
    
    return 1;
}

int cpd_host_database_get_hw_addr( cpd_host_database_t* host_database, 
                                   struct ether_addr* hw_addr, cpd_host_database_entry_t* entry )
{
    if ( host_database == NULL ) {
        return errlogargs();
    }

    if ( hw_addr == NULL ) {
        return errlogargs();
    }

    if ( entry == NULL ) {
        return errlogargs();
    }
    
    cpd_host_database_entry_t* h = NULL;

    if (( h = ht_lookup( host_database->hw_addr_to_entry, (void*)hw_addr )) == NULL ) {
        return 0;
    }
    
    memcpy( entry, h, sizeof( cpd_host_database_entry_t ));
    entry->list_node = NULL;
    
    return 1;
}

int cpd_host_database_remove_hw_addr( cpd_host_database_t* host_database, 
                                      struct ether_addr* hw_addr, cpd_host_database_entry_t* entry )
{
    if ( host_database == NULL ) {
        return errlogargs();
    }

    if ( hw_addr == NULL ) {
        return errlogargs();
    }

    if ( entry == NULL ) {
        return errlogargs();
    }

    cpd_host_database_entry_t* h = NULL;
    if (( h = ht_lookup( host_database->hw_addr_to_entry, (void*)hw_addr )) == NULL ) {
        return 0;
    }

    memcpy( entry, h, sizeof( cpd_host_database_entry_t ));
    entry->list_node = NULL;

    if ( _remove_entry( host_database, h ) < 0 ) {
        return errlog( ERR_CRITICAL, "_remove_entry\n" );
    }
    h = NULL;
    
    return 1;
}



static u_char _hw_addr_equ( const void* input_1, const void* input_2 )
{
    if ( input_1 == NULL ) {
        return 0;
    }

    if ( input_2 == NULL ) {
        return 0;
    }

    return memcmp( input_1, input_2, sizeof( struct ether_addr )) == 0;
}

static u_long _hw_addr_hash( const void* input_1 )
{
    if ( input_1 == NULL ) {
        return 0;
    }

    const struct ether_addr* hw_addr = input_1;
    int c  = 0;
    u_long result = 17;
    for ( c = 0 ; c < sizeof( hw_addr->ether_addr_octet ) ; c++ ) {
        result = 37 * result + hw_addr->ether_addr_octet[c];
    }
    return result;
}

static int _remove_entry( cpd_host_database_t* host_database, cpd_host_database_entry_t* entry )
{
    if ( entry->list_node == NULL ) {
        return errlog( ERR_WARNING, "Trying to remove an entry that is not in the list." );
    }

     char ether_str[24];
    
    if ( entry->has_hw_addr ) {
        if ( ht_remove( host_database->hw_addr_to_entry, (void*)&entry->hw_addr ) < 0 ) {
            errlog( ERR_WARNING, "Unable to remove an entry from the MAC address hash %s\n", 
                    ether_ntoa_r( &entry->hw_addr, ether_str ));
        }
    }
    
    if ( ht_remove( host_database->ipv4_addr_to_entry, (void*)entry->ipv4_addr.s_addr ) < 0 ) {
        errlog( ERR_WARNING, "Unable to remove an entry from the IPv4 address hash %s\n", 
                unet_inet_ntoa( entry->ipv4_addr.s_addr ));
    }

    if ( list_remove( host_database->entry_list, entry->list_node ) < 0 ) {
        return errlog( ERR_CRITICAL, "list_remove\n" );
    }

    return 0;
}

