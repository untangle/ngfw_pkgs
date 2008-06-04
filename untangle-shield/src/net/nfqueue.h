/*
 * $HeadURL: svn://chef/work/src/libnetcap/src/barfight_shield.c $
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

#ifndef __BARFIGHT_NET_NFQUEUE_H
#define __BARFIGHT_NET_NFQUEUE_H

#include <pthread.h>

#include <libnfnetlink/libnfnetlink.h>
#include <libnetfilter_queue/libnetfilter_queue.h>

#include <net/packet.h>

typedef struct barfight_net_nfqueue
{
    pthread_key_t tls_key;
    struct nfq_handle*  nfq_h;
    struct nfq_q_handle* nfq_qh;
    u_int16_t queue_num;
    u_int8_t copy_mode;
    int copy_size;
    int nfq_fd;
} barfight_net_nfqueue_t;

/* This is to initialize the global state that queuing uses. */
int barfight_net_nfqueue_global_init( void );

/* Destroy the global state for queuing */
void barfight_net_nfqueue_global_destroy( void );

barfight_net_nfqueue_t* barfight_net_nfqueue_malloc( void );
int barfight_net_nfqueue_init( barfight_net_nfqueue_t* nfqueue, u_int16_t queue_num,
                               u_int8_t copy_mode, int copy_size );
barfight_net_nfqueue_t* barfight_net_nfqueue_create( u_int16_t queue_num,
                                                     u_int8_t copy_mode, int copy_size );

void barfight_net_nfqueue_raze( barfight_net_nfqueue_t* nfqueue );
void barfight_net_nfqueue_destroy( barfight_net_nfqueue_t* nfqueue );
void barfight_net_nfqueue_free( barfight_net_nfqueue_t* nfqueue );

/**
 * Get the file descriptor associated with the netfilter queue.
 */
int  barfight_net_nfqueue_get_fd( barfight_net_nfqueue_t* nfqueue );

/** 
 * The netfiler version of the queue reading function
 */
int  barfight_net_nfqueue_read( barfight_net_nfqueue_t* nfqueue, barfight_net_packet_t* packet );

/** 
 * Set the verdict for a packet.
 *
 * @param packet The packet to set the verdict for.
 * @param verdict The verdict to apply to <code>packet</code>.
 */
int  barfight_net_nfqueue_set_verdict( barfight_net_packet_t* packet, int verdict );

/** 
 * Set the verdict for a packet with a mark.
 *
 * @param packet The packet to set the verdict for.
 * @param verdict The verdict to apply to <code>packet</code>.
 * @param set_mark non-zero to set the nfmark to mark, otherwise the mark is unchanged.
 * This only has an affect for the verdict NF_ACCEPT.
 * @param mark The mark to set the packet to, or unused if set_mark is zero.
 */
int  barfight_net_nfqueue_set_verdict_mark( barfight_net_packet_t* packet, int verdict,
                                            int set_mark, u_int32_t mark );

#endif // #ifndef __BARFIGHT_NET_NFQUEUE_H

