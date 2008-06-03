/*
 * Copyright (c) 2003-2007 Untangle, Inc.
 * All rights reserved.
 *
 * This software is the confidential and proprietary information of
 * Untangle, Inc. ("Confidential Information"). You shall
 * not disclose such Confidential Information.
 *
 * $Id: ip.h 8515 2007-01-03 00:13:24Z rbscott $
 */

#ifndef __BARFIGHT_NET_PACKET_H
#define __BARFIGHT_NET_PACKET_H

#include <netinet/in.h>
#include <netinet/ip.h>

#define MAX_BUCKET_SIZE 0x10000

typedef struct barfight_net_packet_tuple
{
    u_int32_t src_address;
    /* these are stored in network byte order */
    u_int32_t src_protocol_id;

    u_int32_t dst_address;
    /* these are stored in network byte order */
    u_int32_t dst_protocol_id;
} barfight_net_packet_tuple_t;

typedef struct
{
    /* Pointer to the IP Header of this packet */
    struct iphdr* ip_header;

    /* Pointer to encapsulated packet (UDP, TCP, GRE, etc header) */
    void *enc_packet;

    /* Size of the encapsulated packet */
    size_t enc_packet_size;

    /* Source interface (may not be set) */
    u_int32_t source_interface;

    /* Netfilter packet id, 0 if unused */
    u_int32_t nf_packet_id;

    /* nonzero if nfmark should be set (send) or is valid (from recv) */
    int  has_nfmark;
    u_int32_t nfmark;
    
    /* This is the bucket, it is the base pointer used to store the
     * data in this pointer, this value should always be set, and is the
     * only value that should be freed/malloced. */
    u_char* bucket;

    /** This is the total size of the ip packet (must be smaller than the
     * size of the bucket) (also updated by ut_ip_pkt_update) */
    size_t bucket_size;
    
    /** This is the size of the bucket */
    size_t bucket_limit;

    /* This is the queue where the packet came from */
    struct barfight_net_nfqueue* nfqueue;

    /* The original and reply tuples. */
    struct {
        barfight_net_packet_tuple_t original;
        barfight_net_packet_tuple_t reply;
    } nat_info;
} barfight_net_packet_t;

/**
 * Allocate memory to store a packet structure.
 */
barfight_net_packet_t* barfight_net_packet_malloc( void );

/**
 * @param bucket_size Size of the memory block to store the requested packet
 */
int barfight_net_packet_init( barfight_net_packet_t* packet, int bucket_size );

/**
 * @param bucket_size Size of the memory block to store the requested packet
 */
barfight_net_packet_t* barfight_net_packet_create( int bucket_size );

void barfight_net_packet_raze( barfight_net_packet_t* packet );
void barfight_net_packet_destroy( barfight_net_packet_t* packet );
void barfight_net_packet_free( barfight_net_packet_t* packet );

#endif // __BARFIGHT_NET_PACKET_H
