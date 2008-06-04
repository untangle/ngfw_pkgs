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

#include <pthread.h>
#include <linux/netfilter.h>
#include <net/if.h>
#include <netinet/ip.h>
#include <netinet/tcp.h>
#include <netinet/udp.h>
#include <stdlib.h>

#include <libnfnetlink/libnfnetlink.h>
#include <libnetfilter_queue/libnetfilter_queue.h>

#include <mvutil/debug.h>
#include <mvutil/errlog.h>
#include <mvutil/unet.h>

#include "net/nfqueue.h"
#include "net/packet.h"

#define FLAG_INITIALIZED      0x543D00D

/* This is passed to the nf_callback using TLS */
typedef struct
{
    barfight_net_packet_t* packet;
} _nfqueue_callback_args_t;

static struct
{
    pthread_key_t tls_key;
    struct nfq_handle*  nfq_h;

    /* Mutex used to guarantee that nfq_h and tls_key are initialized only once. */
    pthread_mutex_t mutex;

    /* This is the current number of running queues */
    int queue_count;

    int is_initialized;
} _globals = 
{
    .nfq_h    = NULL,
    .tls_key  = -1,
    .is_initialized = -1,
    .queue_count = 0,
    .mutex    = PTHREAD_MUTEX_INITIALIZER
};

/* This is the callback for netfilter queuing */
static int _nf_callback( struct nfq_q_handle *qh, struct nfgenmsg *nfmsg, struct nfq_data *nfa, void *na );

/* This is a helper function to retrieve the ctinfo
 */
static int _nfq_get_conntrack( struct nfq_data *nfad, barfight_net_packet_t* pkt );

int barfight_net_nfqueue_global_init( void )
{
    int _critical_section() {
        if ( _globals.is_initialized != -1 ) return errlog( ERR_CRITICAL, "Already initialized." );

        /* Initialize the TLS key */
        /* no need to use a destruction function, because the value is unset after the 
         * netfilter callback is called */
        if ( pthread_key_create( &_globals.tls_key, NULL ) < 0 ) return perrlog( "pthread_key_create" );

        /* initialize the netfilter queue */
        if (( _globals.nfq_h = nfq_open()) == NULL ) return perrlog( "nfq_open" );

        /* Unbind any existing queue handlers */
        if ( nfq_unbind_pf( _globals.nfq_h, PF_INET ) < 0 ) perrlog( "nfq_unbind_pf" );

        /* Bind queue */
        if ( nfq_bind_pf( _globals.nfq_h, PF_INET ) < 0 ) perrlog( "nfq_bind_pf" );
        
        /* Reference count just for error handling on detruction */
        _globals.queue_count = 0;
        _globals.is_initialized = FLAG_INITIALIZED;

        return 0;
    }

    int ret;
    if ( pthread_mutex_lock( &_globals.mutex ) < 0 ) return perrlog( "pthread_mutex_lock\n" );
    ret = _critical_section();
    if ( pthread_mutex_unlock( &_globals.mutex ) < 0 ) return perrlog( "pthread_mutex_unlock\n" );

    if ( ret < 0 ) {
        errlog( ERR_CRITICAL, "_critical_section\n" );
        barfight_net_nfqueue_global_destroy();
        return ret;
    }

    return 0;
}

void barfight_net_nfqueue_global_destroy( void )
{
    int _critical_section() {
        if ( _globals.is_initialized != FLAG_INITIALIZED ) {
            return errlog( ERR_CRITICAL, "NFQUEUE is not initialized.\n" );
        }

        _globals.is_initialized = -1;

        if ( _globals.queue_count != 0 ) {
            errlog( ERR_WARNING, "Destroying global queue with %d queues running.", 
                    _globals.queue_count );
        }
        
        if ( _globals.nfq_h != NULL ) {
            // Don't unbind on shutdown, if you do other processes
            // that use nfq will stop working.
            // if ( nfq_unbind_pf( _nfqueue.nfq_h, AF_INET) < 0 ) perrlog( "nfq_unbind_pf" );

            if ( nfq_close( _globals.nfq_h ) < 0 ) perrlog( "nfq_close" );
        }
        _globals.nfq_h = NULL;

        if (( _globals.tls_key > 0 ) && ( pthread_key_delete( _globals.tls_key ) < 0 )) {
            perrlog( "pthread_key_delete" );
        }
        _globals.tls_key = -1;
        return 0;
    }

    int ret;
    if ( pthread_mutex_lock( &_globals.mutex ) < 0 ) return (void)perrlog( "pthread_mutex_lock\n" );
    ret = _critical_section();
    if ( pthread_mutex_unlock( &_globals.mutex ) < 0 ) return (void)perrlog( "pthread_mutex_unlock\n" );

    if ( ret < 0 ) {
        errlog( ERR_CRITICAL, "_critical_section\n" );
    }    
}

barfight_net_nfqueue_t* barfight_net_nfqueue_malloc( void )
{
    barfight_net_nfqueue_t* nfqueue = NULL;
    
    if (( nfqueue = calloc( 1, sizeof( barfight_net_nfqueue_t ))) == NULL ) return errlogmalloc_null();
    
    return nfqueue;
}

int barfight_net_nfqueue_init( barfight_net_nfqueue_t* nfqueue, u_int16_t queue_num, 
                               u_int8_t copy_mode, int copy_size )
{
    int _critical_section() {
        bzero( nfqueue, sizeof( barfight_net_nfqueue_t ));

        if ( _globals.is_initialized != FLAG_INITIALIZED ) {
            return errlog( ERR_CRITICAL, "NFQUEUE is not initialized.\n" );
        }
                
        nfqueue->tls_key = _globals.tls_key;
        nfqueue->nfq_h = _globals.nfq_h;
        nfqueue->queue_num = queue_num;
        nfqueue->copy_mode = copy_mode;
        nfqueue->copy_size = copy_size;
        
        /* Bind the socket to a queue */
        if (( nfqueue->nfq_qh = nfq_create_queue( nfqueue->nfq_h, queue_num, 
                                                  _nf_callback, NULL )) == NULL ) {
            return perrlog( "nfq_create_queue" );
        }

        if ( _globals.queue_count < 0 ) {
            errlog( ERR_WARNING, "Queue count is uninitialized: %d\n", _globals.queue_count );
            _globals.queue_count = 0;
        }
        
        _globals.queue_count++;

        /* set the copy mode */
        if ( nfq_set_mode( nfqueue->nfq_qh, copy_mode, copy_size ) < 0 ) {
            return perrlog( "nfq_set_mode" );
        }

        /* Retrieve the file descriptor for the netfilter queue */
        if (( nfqueue->nfq_fd = nfnl_fd( nfq_nfnlh( nfqueue->nfq_h ))) <= 0 ) {
            return errlog( ERR_CRITICAL, "nfnl_fd/nfq_nfnlh\n" );
        }        

        return 0;
    }
    
    if ( nfqueue == NULL ) return errlogargs();

    int ret;
    if ( pthread_mutex_lock( &_globals.mutex ) < 0 ) return perrlog( "pthread_mutex_lock\n" );
    ret = _critical_section();
    if ( pthread_mutex_unlock( &_globals.mutex ) < 0 ) return perrlog( "pthread_mutex_unlock\n" );

    if ( ret < 0 ) {
        errlog( ERR_CRITICAL, "_critical_section\n" );
        barfight_net_nfqueue_destroy( nfqueue );
        return ret;
    }
    
    return 0;
}

barfight_net_nfqueue_t* barfight_net_nfqueue_create( u_int16_t queue_num, 
                                                     u_int8_t copy_mode, int copy_size )
{
    barfight_net_nfqueue_t* nfqueue = NULL;

    if (( nfqueue = barfight_net_nfqueue_malloc()) == NULL ) {
        return errlog_null( ERR_CRITICAL, "barfight_net_nfqueue_malloc\n" );
    }

    if ( barfight_net_nfqueue_init( nfqueue, queue_num, copy_mode, copy_size ) < 0 ) {
        barfight_net_nfqueue_raze( nfqueue );
        return errlog_null( ERR_CRITICAL, "barfight_net_nfqueue_init\n" );
    }
    
    return nfqueue;
}

void barfight_net_nfqueue_raze( barfight_net_nfqueue_t* nfqueue )
{
    barfight_net_nfqueue_destroy( nfqueue );
    barfight_net_nfqueue_free( nfqueue );
}

void barfight_net_nfqueue_destroy( barfight_net_nfqueue_t* nfqueue )
{
    int _critical_section() {
        debug( 4, "NFQUEUE: destroying queue %d.\n", nfqueue->queue_num );

        if ( nfqueue->nfq_qh != NULL ) {
            /* close the queue handler */
            if (( nfqueue->nfq_qh != NULL ) && ( nfq_destroy_queue( nfqueue->nfq_qh ) < 0 )) {
                perrlog( "nfq_destroy_queue" );
            }

            if ( _globals.queue_count < 1 ) {
                errlog( ERR_WARNING, "Queue count is uninitialized: %d\n", _globals.queue_count );
                _globals.queue_count = 1;
            }
            
            _globals.queue_count--;
        } else {
            debug( 4, "NFQUEUE: nfqueue->nfq_qh is NULL.\n" );
        }

        bzero( nfqueue, sizeof( barfight_net_nfqueue_t ));

        nfqueue->nfq_fd = -1;
        
        return 0;
    }
    
    if ( nfqueue == NULL ) {
        errlogargs();
        return;
    }

    int ret;
    if ( pthread_mutex_lock( &_globals.mutex ) < 0 ) return (void)perrlog( "pthread_mutex_lock\n" );
    ret = _critical_section();
    if ( pthread_mutex_unlock( &_globals.mutex ) < 0 ) return (void)perrlog( "pthread_mutex_unlock\n" );

    if ( ret < 0 ) errlog( ERR_CRITICAL, "_critical_section\n" );
}

void barfight_net_nfqueue_free( barfight_net_nfqueue_t* nfqueue )
{
    if ( nfqueue == NULL ) {
        errlogargs();
        return;
    }

    if ( nfqueue->nfq_qh != NULL ) errlog( ERR_WARNING, "non-null queue handle.\n" );

    free( nfqueue );
}

/**
 * Get the file descriptor associated with the netfilter queue.
 */
int  barfight_net_nfqueue_get_fd( barfight_net_nfqueue_t* nfqueue )
{
    if ( nfqueue == NULL ) return errlogargs();
    if ( nfqueue->nfq_fd <= 0 ) return errlog( ERR_CRITICAL, "NFQUEUE: unitialized." );
    return nfqueue->nfq_fd;
}

/* The netfiler version of the queue reading function */
int  barfight_net_nfqueue_read( barfight_net_nfqueue_t* nfqueue, barfight_net_packet_t* packet )
{
    int _critical_section( void )
    {
        int packet_len = 0;
        
        if (( packet_len = recv( nfqueue->nfq_fd, packet->bucket, packet->bucket_limit, 0 )) < 0 ) {
            return perrlog( "recv" );
        }

        debug( 11, "NFQUEUE: Received %d bytes.\n", packet_len );

        if ( nfq_handle_packet( nfqueue->nfq_h, (char*)packet->bucket, packet_len ) < 0 ) {
            return perrlog( "nfq_handle_packet" );
        }

        debug( 11, "NFQUEUE: Packet ID: %#010x.\n", packet->nf_packet_id );

        packet->nfqueue = nfqueue;
        
        return 0;
    }
    
    /* Build the arguments for the queuing callback, and set it to TLS */    
    _nfqueue_callback_args_t args = {
        .packet = packet
    };

    int ret;

    if ( nfqueue == NULL ) return errlogargs();
    if ( packet->bucket == NULL ) return errlogargs();
    if ( packet->bucket_limit == 0 ) return errlogargs();

    pthread_setspecific( nfqueue->tls_key, &args );
    ret = _critical_section();
    pthread_setspecific( nfqueue->tls_key, NULL );
    
    if ( ret < 0 ) return errlog( ERR_CRITICAL, "_critical_section\n" );
    return 0;
}

/** 
 * Set the verdict for a packet.
 *
 * @param pkt The packet to set the verdict for.
 * @param verdict The verdict to apply to <code>pkt</code>.
 */
int  barfight_net_nfqueue_set_verdict( barfight_net_packet_t* packet, int verdict )
{
    return barfight_net_nfqueue_set_verdict_mark( packet, verdict, 0, 0 );
}

/** 
 * Set the verdict for a packet with a mark.
 *
 * @param pkt The packet to set the verdict for.
 * @param verdict The verdict to apply to <code>pkt</code>.
 * @param set_mark non-zero to set the nfmark to mark, otherwise the mark is unchanged.
 * This only has an affect for the verdict NF_ACCEPT.
 * @param mark The mark to set the packet to, or unused if set_mark is zero.
 */
int  barfight_net_nfqueue_set_verdict_mark( barfight_net_packet_t* packet, int verdict,
                                            int set_mark, u_int32_t mark )
{
    if ( packet == NULL ) return errlogargs();

    if ( packet->nfqueue == NULL ) return errlogargs();
    
    if ( packet->nf_packet_id == 0 ) return errlogargs();

    u_int32_t nf_packet_id = packet->nf_packet_id;
    barfight_net_nfqueue_t* nfqueue = packet->nfqueue;

    /* Clear out the packet id (first in case it errors out) */
    packet->nf_packet_id = 0;

    switch( verdict ) {
    case NF_DROP:
        /* fallthrough */
    case NF_ACCEPT:
        /* fallthrough */
    case NF_STOLEN:
        break;
    default:
        errlog(ERR_CRITICAL, "Invalid verdict, dropping packet %d\n", verdict );
        verdict = NF_DROP;
    }

    if ( set_mark == 0 ) {
        if ( nfq_set_verdict( nfqueue->nfq_qh, nf_packet_id, verdict, 0, NULL ) < 0 ) {
            return perrlog( "nfq_set_verdict" );
        }
    } else {
        /* Convert to the proper byte order */
        mark = htonl( mark );
        if ( nfq_set_verdict_mark( nfqueue->nfq_qh, nf_packet_id, verdict, mark, 0, NULL ) < 0 ) {
            return perrlog( "nfq_set_verdict_mark" );
        }

        /* Reset the mark to the new value */
        packet->has_nfmark = 1;
        packet->nfmark = mark;
    }

    return 0;
}

/* This is the callback for netfilter queuing */
static int _nf_callback( struct nfq_q_handle *qh, struct nfgenmsg *nfmsg, 
                         struct nfq_data *nfa, void *na )
{
    u_char* data = NULL;
    int data_size = 0;
    
    struct nfqnl_msg_packet_hdr *ph = NULL;
    barfight_net_packet_t* packet = NULL;
    _nfqueue_callback_args_t* args = NULL;

    debug( 10, "NFQUEUE: Entering callback.\n" );
    
    if (( args = pthread_getspecific( _globals.tls_key  )) == NULL ) {
        return errlog( ERR_CRITICAL, "null args\n" );
    }
    
    if (( ph = nfq_get_msg_packet_hdr( nfa )) == NULL ) return perrlog( "nfq_get_msg_packet_hdr" );

    if (( packet = args->packet ) == NULL ) return errlogargs();
    
    packet->nf_packet_id = ntohl( ph->packet_id );
    
    /* Fill in the values for a packet */
    if ((( data_size = nfq_get_payload( nfa, (char**)&data )) < 0 ) || ( data == NULL )) {
        return perrlog( "nfq_get_payload" );
    }

    debug( 5, "NFQUEUE: bucket: %#010x ip_header: %#010x difference: %#010x\n", packet->bucket, data, 
           data - packet->bucket );

    packet->ip_header = (struct iphdr*)data;

    /* The header length is only 4 bits */
    packet->enc_packet = (void*)( data + ( 4 * packet->ip_header->ihl ));
    
    if (( packet->enc_packet_size = ( data_size - ( 4 * packet->ip_header->ihl ))) <= 0 ) {
        return errlog( ERR_CRITICAL, "Invalid encapsulated packet size %d\n", packet->enc_packet_size );
    }

    if ( data_size < ntohs( packet->ip_header->tot_len )) return errlogcons();

    packet->bucket_size = data_size;
    
    packet->has_nfmark = 1;
    packet->nfmark  = nfq_get_nfmark( nfa );
    
    /* Verify that the marks match, eventually, it should just go to this other method */
    /* First lookup the physdev in */

    u_int32_t dev = nfq_get_physindev( nfa );
    if ( dev == 0 ) dev = nfq_get_indev( nfa );

    /* Load the name of the interface */
    if ( dev != 0 ) {
        if ( if_indextoname( dev, packet->if_name ) == NULL ) {
            errlog( ERR_WARNING, "if_indextoname (%s)\n", errstr );
            strncpy( packet->if_name, "unknown", sizeof( packet->if_name ));
        }
    } else {
        strncpy( packet->if_name, "unknown", sizeof( packet->if_name ));
    }
        
    /* Try to get the conntrack information */
    if ( _nfq_get_conntrack( nfa, packet ) <0 ) {
        errlog( ERR_WARNING, "_nfq_get_conntrack\n" );
    } else {
        debug( 10, "NFQUEUE: Conntrack original info: %s:%d -> %s:%d\n",
               unet_next_inet_ntoa( packet->nat_info.original.src_address ), 
               ntohs( packet->nat_info.original.src_protocol_id ),
               unet_next_inet_ntoa( packet->nat_info.original.dst_address ), 
               ntohs( packet->nat_info.original.dst_protocol_id ));
        
        debug( 10, "NFQUEUE: Conntrack reply info: %s:%d -> %s:%d\n",
               unet_next_inet_ntoa( packet->nat_info.reply.src_address ), 
               ntohs( packet->nat_info.reply.src_protocol_id ),
               unet_next_inet_ntoa( packet->nat_info.reply.dst_address ), 
               ntohs( packet->nat_info.reply.dst_protocol_id ));
    }
        
    debug( 10, "NFQUEUE Input device %d\n", dev );
        
    return 0;
}

static int _nfq_get_conntrack( struct nfq_data *nfad, barfight_net_packet_t* packet )
{
    struct nf_conntrack_tuple* original;
    struct nf_conntrack_tuple* reply;

    if (nfq_get_conntrack(nfad, &original,  &reply ) < 0){
	errlog( ERR_WARNING, "nfq_get_conntrack could not find conntrack info\n" );
	return 0;
    }

    /* using the union from the nfqueue structure, doesn't matter if
     * this is TCP, UDP, whatever, but it is kind of filthy. */
    packet->nat_info.original.src_address     = original->src.u3.ip;
    packet->nat_info.original.src_protocol_id = original->src.u.tcp.port;
    packet->nat_info.original.dst_address     = original->dst.u3.ip;
    packet->nat_info.original.dst_protocol_id = original->dst.u.tcp.port;
    
    /* using the union from the nfqueue structure, doesn't matter if
     * this is TCP, UDP, whatever, but it is kind of filthy. */
    packet->nat_info.reply.src_address     = reply->src.u3.ip;
    packet->nat_info.reply.src_protocol_id = reply->src.u.tcp.port;
    packet->nat_info.reply.dst_address     = reply->dst.u3.ip;
    packet->nat_info.reply.dst_protocol_id = reply->dst.u.tcp.port;

    return 0;
}
