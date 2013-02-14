/**
 * $Id: outdev.c,v 1.00 2013/02/14 10:59:31 dmorris Exp $
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <net/if.h>
#include <net/if_arp.h>
#include <netinet/in.h>
#include <netinet/ip.h>
#include <netinet/if_ether.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <linux/sockios.h> 
#include <linux/netfilter.h> 
#include <libnetfilter_queue/libnetfilter_queue.h>

#define QUEUE_NUM  1979
#define MAX_DELAY  100000L
#define MAX_INTERFACES 256

#define SIOCFINDEV 0x890E  /* kernel constant */
#define BRCTL_GET_DEVNAME 19  /* kernel constant */

int arp_socket = 0;
struct ether_addr zero_mac = { .ether_addr_octet = { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 } };
char* interfaceNames[MAX_INTERFACES];
int   interfaceIds[MAX_INTERFACES];

static int _usage( char *name );
static int _parse_args( int argc, char** argv );

static int    _find_out_port ( struct nfq_data *tb );
static void   _print_pkt ( struct nfq_data *tb );
static int    _callback ( struct nfq_q_handle *qh, struct nfgenmsg *nfmsg, struct nfq_data *nfa, void *data );
static int    _find_next_hop     ( char* dev_name, struct in_addr* dst_ip, struct in_addr* next_hop );
static int    _arp_address       ( struct in_addr* dst_ip, struct ether_addr* mac, char* intf_name, int num_tries, unsigned long* delay_array );
static int    _get_arp_cache_entry     ( struct in_addr* ip, char* intf_name, struct ether_addr* mac );
static int    _find_bridge_port   ( struct ether_addr* mac_address, char* bridge_name );
static char*  _inet_ntoa( in_addr_t addr );
static void   _mac_to_string     ( char *mac_string, int len, struct ether_addr* mac );

/**
 * TODO - handling of non-IP packets
 * TODO - create new thread in callback (thread can NOT block EVER)
 */


int main(int argc, char **argv)
{
    struct nfq_handle *h;
    struct nfq_q_handle *qh;
    struct nfnl_handle *nh;
    int fd;
    int rv;
    char buf[4096];

    if ( _parse_args( argc, argv ) < 0 )
        return _usage( argv[0] );

    printf("initializing arp socket.\n");
    if (( arp_socket = socket( PF_INET, SOCK_DGRAM, 0 )) < 0 ) {
        fprintf( stderr, "socket: %s\n", strerror(errno) );
        return -1;
    }

    printf("opening library handle:\n");
    h = nfq_open();
    if (!h) {
        fprintf(stderr, "error during nfq_open()\n");
        exit(1);
    }

    printf("unbinding existing nf_queue handler for AF_INET (if any)\n");
    if (nfq_unbind_pf(h, AF_INET) < 0) {
        fprintf(stderr, "error during nfq_unbind_pf()\n");
        exit(1);
    }

    printf("binding nfnetlink_queue as nf_queue handler for AF_INET\n");
    if (nfq_bind_pf(h, AF_INET) < 0) {
        fprintf(stderr, "error during nfq_bind_pf()\n");
        exit(1);
    }

    printf("binding this socket to queue %i\n", QUEUE_NUM);
    qh = nfq_create_queue(h, QUEUE_NUM, &_callback, NULL);
    if (!qh) {
        fprintf(stderr, "error during nfq_create_queue()\n");
        exit(1);
    }

    printf("setting copy_packet mode\n");
    //if (nfq_set_mode(qh, NFQNL_COPY_META, 0xffff) < 0) {
    // IPv6? FIXME
    if (nfq_set_mode(qh, NFQNL_COPY_PACKET, sizeof(struct iphdr)) < 0) {
        fprintf(stderr, "can't set packet_copy mode\n");
        exit(1);
    }

    nh = nfq_nfnlh(h);
    fd = nfnl_fd(nh);

    while ((rv = recv(fd, buf, sizeof(buf), 0)) && rv >= 0) {
        //printf("pkt received\n");
        nfq_handle_packet(h, buf, rv);
    }

    printf("unbinding from queue 0\n");
    nfq_destroy_queue(qh);

#ifdef INSANE
/* normally, applications SHOULD NOT issue this command, since
 * it detaches other programs/sockets from AF_INET, too ! */
    printf("unbinding from AF_INET\n");
    nfq_unbind_pf(h, AF_INET);
#endif

    printf("closing library handle\n");
    nfq_close(h);

    exit(0);
}

static int _usage( char *name )
{
    fprintf( stderr, "Usage: %s\n", name );
    fprintf( stderr, "\t-i interface_name:index.  Example -i eth0:1. Can be specified many times.\n" );
    return -1;
}

static int _parse_args( int argc, char** argv )
{
    int c = 0;

    bzero( interfaceNames, sizeof(interfaceNames));
    bzero( interfaceIds, sizeof(interfaceIds));

    while (( c = getopt( argc, argv, "i:" ))  != -1 ) {
        switch( c ) {

        case 'i':
        {
            /**
             * Parse name:index
             */
            char* name = NULL;
            int id = -1;

            char* token;
            int i;
            for ( i = 0 ; ((token = strsep(&optarg, ":")) != NULL ) ; i++ ) {
                if ( i == 0 )
                    name = token;
                if ( i == 1) {
                    id = atoi( token );
                }
            }

            if ( name == NULL ) {
                fprintf( stderr, "Invalid interface name\n");
                return -1;
            }
            if ( id == -1 ) {
                fprintf( stderr, "Invalid interface index\n");
                return -1;
            }
            
            /**
             * find first unused array entry and set it
             */
            for ( i = 0 ; i < MAX_INTERFACES ; i++ ) {
                if ( interfaceNames[i] == NULL ) {
                    interfaceNames[i] = strdup(name);
                    interfaceIds[i] = id;
                    printf("Mapping Interface %s with mark %i\n", interfaceNames[i], interfaceIds[i]);
                    break;
                }
            }
            
            break;
        }

        case '?':
            return -1;
        }
    }
    
    return 0;
}

static int _callback(struct nfq_q_handle *qh, struct nfgenmsg *nfmsg, struct nfq_data *nfa, void *data)
{
    int id = 0;
    struct nfqnl_msg_packet_hdr *ph;

    ph = nfq_get_msg_packet_hdr(nfa);
    if (!ph) {
        fprintf(stderr,"Packet missing header!\n");
        return;
    }
    id = ntohl(ph->packet_id);

    _print_pkt(nfa);
    
    int out_port_utindex = _find_out_port(nfa);

    if (out_port_utindex <= 0) {
        return nfq_set_verdict(qh, id, NF_ACCEPT, 0, NULL);
    }
    else {
        u_int mark = nfq_get_nfmark(nfa);
        printf("CURRENT MARK: 0x%08x\n", mark);
        mark = mark & 0xFFFF00FF;
        mark = mark | (out_port_utindex << 8);
        printf("NEW     MARK: 0x%08x\n", mark);

        mark = htonl( mark );
        // NF_REPEAT instead of NF_ACCEPT to repeat mark-dst-intf
        return nfq_set_verdict_mark(qh, id, NF_REPEAT, mark, 0, NULL);

    }
}

static void _print_pkt ( struct nfq_data *tb )
{
    int id = 0;
    struct nfqnl_msg_packet_hdr *ph;
    u_int32_t mark,ifindex;
    int ret;
    char *data;
    char intf_name[IF_NAMESIZE];

    printf("PACKET: ");
    
    ph = nfq_get_msg_packet_hdr(tb);
    if (ph){
        id = ntohl(ph->packet_id);
        printf("hw_protocol=0x%04x hook=%u id=%u ",
               ntohs(ph->hw_protocol), ph->hook, id);
    }

    mark = nfq_get_nfmark(tb);
    if (mark)
        printf("mark=%u ", mark);

    ifindex = nfq_get_indev(tb);
    if (ifindex) {
        if ( if_indextoname(ifindex, intf_name) == NULL) {
            fprintf(stderr,"if_indextoname: %s", strerror(errno));
            return;
        }
        printf("indev=(%i,%s) ", ifindex, intf_name);
    }

    ifindex = nfq_get_outdev(tb);
    if (ifindex) {
        if ( if_indextoname(ifindex, intf_name) == NULL) {
            fprintf(stderr,"if_indextoname: %s", strerror(errno));
            return;
        }
        printf("outdev=(%i,%s) ", ifindex, intf_name);
    }

    ret = nfq_get_payload(tb, &data);
    if (ret >= 0)
        printf("payload_len=%d ", ret);

    if (ret < sizeof(struct iphdr)) {
        fputc('\n', stdout);
        return;
    }
    
    struct iphdr * ip = (struct iphdr *) data;
    struct in_addr ipa;

    fprintf(stdout, "IP version:%i ", ip->version);

    if (ip->version != 4) {
        fputc('\n', stdout);
        return;
    }
    
    fprintf(stdout, "SRC_IP: %s ", _inet_ntoa(ip->saddr));
    fprintf(stdout, "DST_IP: %s ", _inet_ntoa(ip->daddr));
  
    fputc('\n', stdout);

    return;
}

static int _find_out_port( struct nfq_data* nfq_data )
{
    struct ether_addr mac_address;
    struct in_addr next_hop;
    char *data;
    char intf_name[IF_NAMESIZE];
    int ret = 1;
    unsigned long delay_array[] = {        3000,
        6000,
        20000,
        60000,
        250000,
        700000,
        1000000,
        15000,
        2000000,
        30000,
        3000000,
        10000,
        0
    };

    /**
     * Lookup interface information - will return an interface like br.eth0
     */
    int ifindex = nfq_get_outdev( nfq_data );
    if (ifindex <= 0) {
        fprintf( stderr, "Unable to locate ifindex: %s\n", strerror(errno) );
        return -1;
    }
    if ( if_indextoname(ifindex, intf_name) == NULL) {
        fprintf(stderr,"if_indextoname: %s", strerror(errno));
        return -1;
    }
    printf("ARP: outdev=(%i,%s)\n", ifindex, intf_name);

    /**
     * Lookup dst IP
     */
    if ( ( ret = nfq_get_payload( nfq_data, &data ) ) < sizeof(struct iphdr) ) {
        fprintf(stderr,"packet too short: %i", ret);
        return -1;
    }
    struct iphdr * ip = (struct iphdr *) data;
    if ( ip->version != 4 ) {
        fprintf(stderr,"Ignoring non-IPV4 %i", ip->version);
        return -1;
    }
    struct in_addr dst;
    memcpy( &dst.s_addr, &ip->daddr, sizeof(in_addr_t));
    if ( _find_next_hop( intf_name, &dst, &next_hop) < 0 ) {
        fprintf( stderr, "_find_next_hop: %s\n", strerror(errno));
        return -1;
    }
    //memcpy( &next_hop, &ip->daddr, sizeof( struct in_addr ));

    if (( ret = _arp_address( &next_hop, &mac_address, intf_name, 5, delay_array )) < 0 ) {
        return fprintf( stderr, "_arp_address: %s\n", strerror(errno) );
    }

            
    if ( ret == 0 ) {
        printf( "ARP: Unable to resolve the MAC address %s\n", inet_ntoa( next_hop ));
        return 0;
    }
            
    int out_port_ifindex = _find_bridge_port( &mac_address, intf_name );

    if ( out_port_ifindex < 0 ) {
        return fprintf( stderr, "_find_bridge_port: %s\n", strerror(errno) );
    }

    char bridge_port_intf_name[IF_NAMESIZE];
    
    if ( if_indextoname(out_port_ifindex, bridge_port_intf_name) == NULL) {
        fprintf(stderr,"if_indextoname: %s", strerror(errno));
        return;
    }

    printf("FINAL ANSWER: %s\n", bridge_port_intf_name);
    int i = 0;
    for( i = 0 ; i < MAX_INTERFACES ; i++ ) {

        if (interfaceNames[i] == NULL) {
            fprintf( stderr, "ERROR: Unable to find interface: %s\n", bridge_port_intf_name );
            return -1;
        }

        if ( strncmp( bridge_port_intf_name, interfaceNames[i], IF_NAMESIZE ) == 0 ) {
            printf("FINAL ANSWER2: %s\n", interfaceNames[i]);
            return interfaceIds[i];
        }
    }
    
    return out_port_ifindex;
}

/**
 * sends an ARP request for the specified dst_ip on the specified intf_name
 */
static int  _arp_address       ( struct in_addr* dst_ip, struct ether_addr* mac, char* intf_name, int num_tries, unsigned long* delay_array )
{
    int c;
    unsigned long delay;
    int ret;
    struct in_addr src_ip;

    for ( c = 0 ; c < num_tries ; c++ ) {
        /* Check the cache before issuing the request */
        ret = _get_arp_cache_entry( dst_ip, intf_name, mac );
        if ( ret < 0 ) {
            return fprintf( stderr, "_get_arp_entry: %s \n", strerror(errno) );
        } else if (ret == 1 ) {
            return 1;
        } else {
            printf( "ARP: MAC not found for '%s' on '%s'. Sending ARP request.\n", _inet_ntoa( dst_ip->s_addr ), intf_name );
        }

        return 0;
                
/*         /\* Connect and close so the kernel grabs the source address *\/ */
/*         if (( c == 0 ) && ( _fake_connect( &src_ip, dst_ip, intf_name ) < 0 )) { */
/*             return fprintf( stderr, "_fake_connect: %s \n", strerror(errno) ); */
/*         } */

/*         delay = delay_array[c]; */
/*         if ( delay == 0 ) break; */
/*         if ( delay > MAX_DELAY ) { */
/*             return fprintf( stderr, "Invalid delay: index %d is %l\n", c, delay ); */
/*         } */

/*         /\* Issue the arp request *\/ */
/*         if ( _issue_arp_request( &src_ip, dst_ip, intf_name ) < 0 ) { */
/*             return fprintf( stderr, "_issue_arp_request: %s \n", strerror(errno) ); */
/*         } */

/*         debug( 11, "Waiting for the response for: %d\n", delay ); */

        usleep( delay );
    }
    
    return 0;
}

/**
 * Checks the ARP cache for the given IP living on the given interface
 * If found, copies the MAC to mac and returns 1
 * Otherwise, returns 0
 * Returns -1, if any error occurs
 */
static int  _get_arp_cache_entry     ( struct in_addr* ip, char* intf_name, struct ether_addr* mac )
{
    struct arpreq request;
    struct sockaddr_in* sin = (struct sockaddr_in*)&request.arp_pa;

    bzero( &request, sizeof( request ));

    sin->sin_family = AF_INET;
    sin->sin_port  = 0;
    memcpy( &sin->sin_addr, ip, sizeof( sin->sin_addr ));

    request.arp_ha.sa_family = ARPHRD_ETHER;
    
    strncpy( request.arp_dev, intf_name, sizeof( request.arp_dev ));

    request.arp_flags = 0;
    
    int ret;
    
    if (( ret = ioctl( arp_socket, SIOCGARP, &request )) < 0 ) {
        /* This only fails if a socket has never been opened to this IP address.
         * Must also check that the address returned a zero MAC address */
        if ( errno == ENXIO ) {
            printf( "ARP CACHE: MAC address for %s was not found\n", _inet_ntoa( ip->s_addr ));
            return 0;
        }

        fprintf(stderr, "ioctl: %s\n", strerror(errno));
        return -1;
    }

    /* Returning an all zero MAC address indicates that the MAC was not found */
    if ( memcmp( &request.arp_ha.sa_data, &zero_mac, sizeof( struct ether_addr )) == 0 ) {
        printf( "ARP CACHE: Ethernet address for %s was not found\n", _inet_ntoa( ip->s_addr ));
        return 0;
    }

    memcpy( mac, &request.arp_ha.sa_data, sizeof( struct ether_addr ));

#define DEBUG_ON
#define MAC_STRING_LENGTH    20
#ifdef DEBUG_ON
    char mac_string[MAC_STRING_LENGTH];
    _mac_to_string( mac_string, sizeof( mac_string ), mac );
    printf( "ARP: Resolved MAC[%d]: '%s' -> '%s'\n", ret, inet_ntoa( *ip ), mac_string );
#endif 

    return 1;
}

char inet_ntoa_name[INET_ADDRSTRLEN];

char*   _inet_ntoa( in_addr_t addr )
{
    struct in_addr i;
    memset(&i, 0, sizeof(i));
    i.s_addr = addr;
    
    strncpy( inet_ntoa_name, inet_ntoa( i ), INET_ADDRSTRLEN );
    
    return inet_ntoa_name;
}

static void _mac_to_string     ( char *mac_string, int len, struct ether_addr* mac )
{
    snprintf( mac_string, len, "%02x:%02x:%02x:%02x:%02x:%02x",
              mac->ether_addr_octet[0], mac->ether_addr_octet[1], mac->ether_addr_octet[2], 
              mac->ether_addr_octet[3], mac->ether_addr_octet[4], mac->ether_addr_octet[5] );
}

/**
 * This queries the kernel for the next hop for packets destined to the specied dst_ip.
 * For example,
 */
static int    _find_next_hop     ( char* dev_name, struct in_addr* dst_ip, struct in_addr* next_hop )
{
    int ifindex;
    struct 
    {
        in_addr_t addr;
        in_addr_t nh;
        char name[IFNAMSIZ];
    } args;
    
    bzero( &args, sizeof( args ));
    args.addr = dst_ip->s_addr;
    strncpy( args.name, dev_name, IFNAMSIZ);
    
    if (( ifindex = ioctl( arp_socket, SIOCFINDEV, &args )) < 0) {
        switch ( errno ) {
        case ENETUNREACH:
            fprintf( stderr, "ARP: Destination IP is not reachable: %s\n", _inet_ntoa( args.addr) );
            return 0;
        default:  /* Ignore all other error codes */
            break;
        }

        fprintf( stderr, "SIOCFINDEV[%s] %s.\n", _inet_ntoa( dst_ip->s_addr ), strerror(errno) );
        return -1;
    }

    /* If the next hop is on the local network, (eg. the next hop is the destination), 
     * the ioctl returns 0 */
    if ( args.nh != 0x00000000 ) {
        next_hop->s_addr = args.nh;
    } else {
        next_hop->s_addr = dst_ip->s_addr;
    }
    
    /* Assuming that the return value is the index of the interface,
     * make sure this is always true */
    printf( "ARP: The destination %s ", _inet_ntoa( dst_ip->s_addr ));
    printf ("is going out [%s,%d] to %s\n", args.name, ifindex, _inet_ntoa( next_hop->s_addr ));
        
    return 0;
}


/**
 * Finds the bridge port for the given MAC address,
 * returns the OS ifindex
 * or -1 for error
 * or 0 for unknown
 */
static int  _find_bridge_port   ( struct ether_addr* mac_address, char* bridge_name )
{
    struct ifreq ifr;
	int ret;
    char buffer[IF_NAMESIZE];

    char mac_string[MAC_STRING_LENGTH];
    _mac_to_string( mac_string, sizeof( mac_string ), mac_address );

    unsigned long args[4] = {BRCTL_GET_DEVNAME, (unsigned long)&buffer, (unsigned long)mac_address, 0};
    
	strncpy( buffer, bridge_name, sizeof( buffer ));
	strncpy( ifr.ifr_name, bridge_name, sizeof( ifr.ifr_name ));
	ifr.ifr_data = (char*)&args;
        
	if (( ret = ioctl( arp_socket, SIOCDEVPRIVATE, &ifr )) < 0 ) {
        if ( errno == EINVAL ) {
            fprintf ( stderr, "ARP: Invalid argument, MAC Address is only found in ARP Cache.\n" );
            return -1;
        } else {
            fprintf( stderr, "ioctl: %s\n", strerror(errno) );
            return -1;
        }
    }
        
    printf( "ARP[%s]: Outgoing interface index is %s,%d\n", bridge_name, buffer, ret );
    
	return ret;
}
