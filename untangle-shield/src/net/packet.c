/*
 * $HeadURL: svn://chef/work/src/libnetcap/src/netcap_shield.c $
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

#include <mvutil/debug.h>
#include <mvutil/errlog.h>

#include "net/packet.h"

barfight_net_packet_t* barfight_net_packet_malloc( void )
{
    barfight_net_packet_t* packet = NULL;
    
    if (( packet = malloc( sizeof( barfight_net_packet_t ))) == NULL ) return errlogmalloc_null();

    packet->bucket_size = 0;
    packet->bucket_limit = 0;
    packet->bucket = NULL;
    
    return packet;
}

int barfight_net_packet_init( barfight_net_packet_t* packet, int bucket_size )
{
    if ( packet == NULL ) return errlogargs();

    if ( bucket_size <= 0 ) return errlogargs();

    if ( bucket_size > MAX_BUCKET_SIZE ) return errlogargs();

    bzero( packet, sizeof( barfight_net_packet_t ));
    
    u_char* bucket = NULL;

    if (( bucket = malloc( bucket_size )) == NULL ) return errlogmalloc();
    
    packet->bucket = bucket;
    packet->bucket_limit = bucket_size;
    
    return 0;
}

barfight_net_packet_t* barfight_net_packet_create( int bucket_size )
{
    barfight_net_packet_t* packet = NULL;

    if (( packet = barfight_net_packet_malloc()) == NULL ) {
        return errlog_null( ERR_CRITICAL, "barfight_net_packet_malloc\n" );
    }

    if ( barfight_net_packet_init( packet, bucket_size ) < 0 ) {
        barfight_net_packet_raze( packet );
        return errlog_null( ERR_CRITICAL, "barfight_net_packet_init\n" );
    }
    
    return packet;
}

void barfight_net_packet_raze( barfight_net_packet_t* packet )
{
    barfight_net_packet_destroy( packet );
    barfight_net_packet_free( packet );
}

void barfight_net_packet_destroy( barfight_net_packet_t* packet )
{
    if ( packet == NULL ) {
        errlogargs();
        return;
    }
    
    packet->ip_header = NULL;
    packet->enc_packet = NULL;
    packet->enc_packet_size = 0;
    if ( packet->nf_packet_id != 0 ) {
        errlog( ERR_WARNING, "The packet %d has a non-zero packet_id\n", packet->nf_packet_id );
        packet->nf_packet_id = 0;
    }

    packet->nfqueue = NULL;
    if ( packet->bucket != NULL ) free( packet->bucket );
    packet->bucket_size = 0;
    packet->bucket_limit = 0;
}

void barfight_net_packet_free( barfight_net_packet_t* packet )
{
    if ( packet == NULL ) {
        errlogargs();
        return;
    }

    free( packet );
}
