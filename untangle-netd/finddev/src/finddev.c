/**
 * $Id: outdev.c,v 1.00 2013/02/14 10:59:31 dmorris Exp $
 */
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <time.h>
#include <pthread.h>
#include <fcntl.h>
#include <net/if.h>
#include <net/if_arp.h>
#include <netinet/in.h>
#include <netinet/ip.h>
#include <netinet/if_ether.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <sys/ioctl.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <arpa/inet.h>
#include <linux/sockios.h> 
#include <linux/netfilter.h> 
#include <linux/if_packet.h>
#include <libnetfilter_queue/libnetfilter_queue.h>

/**
 * The NFqueue # to listen for packets
 */
#define QUEUE_NUM  1979

/**
 * Maximum number of interfaces in Untangle
 */
#define MAX_INTERFACES 256

/**
 * Kernel constant
 */
#define SIOCFINDEV 0x890E

/**
 * Kernel constant
 */
#define BRCTL_GET_DEVNAME 19

/**
 * length of MAC address string
 */
#define MAC_STRING_LENGTH    20

/**
 * The bypass mark
 */
#define MARK_BYPASS 0x01000000

/**
 * nfnetlink socket buffer size
 */
#define BUFFER_SIZE 1048576

/**
 * Is running flag, to exit set this to 0
 */
int running = 1;

/**
 * Socket used for ARP queries
 */
int arp_socket = 0;

/**
 * Socket used for sending packets
 */
int pkt_socket = 0;

/**
 * Verbosity level
 */
int verbosity = 0;

/**
 * Run as daemon?
 */
int daemonize = 0;

/**
 * log file (if daemonized)
 */
char* logfile = "/var/log/uvm/finddev.log";
    
/**
 * File descriptor for nfnl
 */
int fd;

/**
 * Netfilter handles
 */
struct nfq_handle* h = NULL;
struct nfnl_handle *nh = NULL;
struct nfq_q_handle *qh = NULL;

/**
 * The current thread listening for new packets
 * This will change frequently, as once a thread gets a packet it spawns a new thread to handle the next packet
 * and it overwrites this.
 */
pthread_t current_thread;

/**
 * The device names of the interfaces (according to Untangle)
 * Example: interfacesName[0] = "eth0" interafceNames[1] = "eth1"
 */
char* interfaceNames[MAX_INTERFACES];

/**
 * The interface IDs of the interfaces (according to Untangle, not the O/S!)
 * Example: interfacesName[0] = "0" interafceNames[1] = "1"
 */
int   interfaceIds[MAX_INTERFACES];

/**
 * A global static string used to return inet_ntoa strings
 */
char inet_ntoa_name[INET_ADDRSTRLEN];

/**
 * This is the delay times for ARP requests (in microsecs)
 * 0 means give-up.
 */
unsigned int delay_array[] = {
    3 * 1000,
    6 * 1000,
    20 * 1000,
    60 * 1000,
    100 * 1000,
    1000 * 1000, /* 1 sec */
    3 * 1000 * 1000, /* 3 sec */
    5 * 1000 * 1000, /* 5 sec */
    0
};

/**
 * New thread attributes
 */
pthread_attr_t attr;

/**
 * print lock
 */
pthread_mutex_t print_mutex;

/**
 * broadcast MAC address
 */
struct ether_addr broadcast_mac = { .ether_addr_octet = { 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF } };

static int    _usage( char *name );
static int    _daemonize( );
static int    _set_signals( void );
static int    _parse_args( int argc, char** argv );
static int    _debug( int level, char *lpszFmt, ...);
static int    _error( char *lpszFmt, ...);
static void*  _read_pkt (void* data);
static char*  _inet_ntoa ( in_addr_t addr );
static void   _mac_to_string ( char *mac_string, int len, struct ether_addr* mac );
static void   _print_pkt ( struct nfq_data *tb );

static void*  _handle_packet ( struct nfq_data *nfa );
static int    _nfqueue_callback ( struct nfq_q_handle *qh, struct nfgenmsg *nfmsg, struct nfq_data *nfa, void *data );

static int    _find_outdev_index ( struct nfq_data *tb );
static int    _find_next_hop ( char* dev_name, struct in_addr* dst_ip, struct in_addr* next_hop );
static int    _find_bridge_port ( struct ether_addr* mac_address, char* bridge_name );

static int    _arp_address ( struct in_addr* dst_ip, struct ether_addr* mac, char* intf_name );
static int    _arp_lookup_cache_entry ( struct in_addr* ip, char* intf_name, struct ether_addr* mac );
static int    _arp_issue_request ( struct in_addr* src_ip, struct in_addr* dst_ip, char* intf_name );
static int    _arp_build_packet ( struct ether_arp* pkt, struct in_addr* src_ip, struct in_addr* dst_ip, char* intf_name );
static int    _arp_determine_source_addr ( struct in_addr* src_ip, struct in_addr* dst_ip, char* intf_name );

static long long _timeval_diff( struct timeval *end_time, struct timeval *start_time );

/**
 * FIXME TODO - handling of non-IP packets?
 * FIXME TODO - handling of IPv6?
 */

int main ( int argc, char **argv )
{
    int rv, i;
    
    _set_signals();
    
    if ( _parse_args( argc, argv ) < 0 )
        return _usage( argv[0] );

    if ( daemonize ) {
        int ret = _daemonize();
        if ( ret < 0 )
            exit( ret );
    }
            
    
    if ( (rv = pthread_attr_init(&attr)) != 0 ) {
        _error( "pthread_attr_init: %s\n", strerror(rv) );
    }
    
    if ( (rv = pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_DETACHED)) != 0 ) {
        _error( "pthread_attr_setdetachstate: %s\n", strerror(rv) );
    }

    if ( (rv = pthread_mutex_init( &print_mutex, NULL )) != 0 ) {
        _error( "pthread_mutex_init: %s\n", strerror(rv) );
    }

    _debug( 2, "Initializing arp socket...\n");
    if (( arp_socket = socket( PF_INET, SOCK_DGRAM, 0 )) < 0 ) {
        _error( "socket: %s\n", strerror(errno) );
        return -1;
    }

    _debug( 2, "Initializing pkt socket...\n");
    if (( pkt_socket = socket( PF_PACKET, SOCK_DGRAM, 0 )) < 0 ) {
        _error( "socket: %s\n", strerror(errno) );
        return -1;
    }

    _debug( 2, "Opening netfilter queue...\n");
    h = nfq_open();
    if (!h) {
        _error( "error during nfq_open()\n");
        exit(1);
    }

    _debug( 2, "Unbinding existing nf_queue handler for AF_INET (if any)\n");
    if (nfq_unbind_pf(h, AF_INET) < 0) {
        _error( "error during nfq_unbind_pf()\n");
        exit(1);
    }

    _debug( 2, "Binding nfnetlink_queue as nf_queue handler for AF_INET\n");
    if (nfq_bind_pf(h, AF_INET) < 0) {
        _error( "error during nfq_bind_pf()\n");
        exit(1);
    }

    _debug( 2, "Binding this socket to queue %i\n", QUEUE_NUM);
    qh = nfq_create_queue(h, QUEUE_NUM, &_nfqueue_callback, NULL);
    if (!qh) {
        _error( "error during nfq_create_queue()\n");
        exit(1);
    }

    // IPv6? FIXME: sizeof(struct iphdr) is IPv4 header
    _debug( 2, "Setting copy_packet mode\n");
    // if (nfq_set_mode(qh, NFQNL_COPY_META, 0xffff) < 0) {
    if (nfq_set_mode(qh, NFQNL_COPY_PACKET, sizeof(struct iphdr)) < 0) {
        _error( "can't set packet_copy mode\n");
        exit(1);
    }

    nh = nfq_nfnlh(h);
    fd = nfnl_fd(nh);
    if ( nfnl_rcvbufsiz(nh, BUFFER_SIZE) < 0 ) {
        _error( "nfnl_rcvbufsiz: %s\n", strerror(errno) );
    }
    
    for ( i = 0 ; i < MAX_INTERFACES ; i++ ) {
        if ( interfaceNames[i] != NULL ) {
            _debug( 1, "Marking Interface %s with mark %i\n", interfaceNames[i], interfaceIds[i]);
        }
    }

    _debug( 1, "Listening for packets...\n" );
    
    pthread_create( &current_thread, &attr, _read_pkt, NULL );
    
    while ( running ) {
        sleep (1);
    }

    _debug( 1, "Shutdown initiated...\n" );

    _debug( 2, "Unbinding from queue %i\n",QUEUE_NUM );

    /**
     * XXX
     * Sometimes nfq_destroy_queue hangs indefinitely preventing the process from exiting
     *
     * Do an alarm(2) so that the process will be killed regardless in 2 seconds.
     *
     * Also, unbind and rebind so nfq_destroy_queue wont hang.
     * http://developer.berlios.de/bugs/?func=detailbug&bug_id=14793&group_id=2509
     */
    if ( alarm( 2 ) < 0 ) {
        _error( "alarm: %s\n", strerror(errno) );
    }
    if (nfq_unbind_pf(h, AF_INET) < 0) {
        _error( "error during nfq_unbind_pf()\n");
    }
    if (nfq_bind_pf(h, AF_INET) < 0) {
        _error( "error during nfq_bind_pf()\n");
    }
    nfq_destroy_queue(qh);

    _debug( 2, "Closing library handle\n" );
    nfq_close(h);

    /**
     * cleanup mallocd interface names
     */
    for ( i = 0 ; i < MAX_INTERFACES ; i++ ) {
        if ( interfaceNames[i] != NULL )
            free( interfaceNames[i] );
    }
        
    _debug( 1, "Exiting...\n" );
    
    exit(0);
}

static void* _read_pkt (void* data)
{
    if ( ! running )
        pthread_exit(NULL);

    char buf[4096];
    bzero(buf, 4096);
    int rv;
    
    do {
        _debug(2,"Waiting for pkt...\n");
        rv = recv(fd, buf, 4096, 0);
        if ( rv < 0 ) {
            _error( "recv: %s\n", strerror(errno) );
            continue;
        }

        if ( running == 0 ) {
            _debug( 0, "Thread Exiting...\n" );
            running = 0;
            pthread_exit(NULL);
        } else {
            break;
        }
    } while ( 1 );
    
    /**
     * Create a new thread to handle the next packet
     * We have to use this thread to handle this packet because nfq_handle_packet
     * stores nfa on the stack, so this thread can not be returned
     */
    pthread_create( &current_thread, &attr, _read_pkt, NULL );

    nfq_handle_packet(h, buf, rv);

    return NULL;
}

static int   _debug ( int level, char *lpszFmt, ... )
{
    if (verbosity >= level)
    {
        va_list argptr;

        va_start(argptr, lpszFmt);

        if ( pthread_mutex_lock( &print_mutex ) < 0 ) {
            _error( "pthread_mutex_lock: %s\n", strerror(errno) );
        }
        
        if ( 1 ) {
            struct timeval tv;
            struct tm tm;
            
            gettimeofday(&tv,NULL);
            if (!localtime_r(&tv.tv_sec,&tm))
                fprintf( stderr, "gmtime_r: %s\n", strerror(errno) );
            
            fprintf( stdout, "%02i-%02i %02i:%02i:%02i.%06li| ", tm.tm_mon+1,tm.tm_mday,tm.tm_hour,tm.tm_min,tm.tm_sec, (long)tv.tv_usec );
        }
          
        vfprintf( stdout, lpszFmt, argptr );

        va_end( argptr );

        fflush( stdout );

        if ( pthread_mutex_unlock( &print_mutex ) < 0 ) {
            fprintf( stderr, "pthread_mutex_unlock: %s\n", strerror(errno) );
        }
        
    }

	return 0;
}

static int   _error ( char *lpszFmt, ... )
{
    va_list argptr;

    va_start(argptr, lpszFmt);

    if ( pthread_mutex_lock( &print_mutex ) < 0 ) {
        fprintf( stderr, "pthread_mutex_lock: %s\n", strerror(errno) );
    }
        
    if ( 1 ) {
        struct timeval tv;
        struct tm tm;
            
        gettimeofday(&tv,NULL);
        if (!localtime_r(&tv.tv_sec,&tm))
            fprintf( stderr, "gmtime_r: %s\n", strerror(errno) );
            
        fprintf( stderr, "%02i-%02i %02i:%02i:%02i.%06li| ", tm.tm_mon+1,tm.tm_mday,tm.tm_hour,tm.tm_min,tm.tm_sec, (long)tv.tv_usec );
    }
          
    vfprintf( stderr, lpszFmt, argptr );

    va_end( argptr );

    fflush( stderr );

    if ( pthread_mutex_unlock( &print_mutex ) < 0 ) {
        fprintf( stderr, "pthread_mutex_unlock: %s\n", strerror(errno) );
    }

    return 0;
}

static int   _usage ( char *name )
{
    _error( "Usage: %s\n", name );
    _error( "\t-i interface_name:index.  specify interface. Example -i eth0:1. Can be specified many times.\n" );
    _error( "\t-v                        increase verbosity\n" );
    _error( "\t-d                        run as daemon\n" );
    _error( "\t-l logfile                logfile to write stdout & stderr to (if daemonized) \n" );
    return -1;
}

static int   _parse_args ( int argc, char** argv )
{
    int c = 0;

    bzero( interfaceNames, sizeof(interfaceNames));
    bzero( interfaceIds, sizeof(interfaceIds));

    while (( c = getopt( argc, argv, "i:vdl:" ))  != -1 ) {
        switch( c ) {

        case 'v':
        {
            verbosity++;
            break;
        }

        case 'd':
        {
            daemonize = 1;
            break;
        }

        case 'l':
        {
            logfile = optarg;
            break;
        }
        
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
                _error( "Invalid interface name\n");
                return -1;
            }
            if ( id == -1 ) {
                _error( "Invalid interface index\n");
                return -1;
            }
            
            /**
             * find first unused array entry and set it
             */
            for ( i = 0 ; i < MAX_INTERFACES ; i++ ) {
                if ( interfaceNames[i] == NULL ) {
                    interfaceNames[i] = strdup(name);
                    interfaceIds[i] = id;
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

static int   _daemonize ()
{
    pid_t pid, sid;
    int logfile_fd;

    pid = fork();
    if ( pid < 0 ){ 
        _error( "Unable to fork daemon process.\n" );
        return -1;
    } else if ( pid > 0 ) {
        exit(0);
    }
        
    /* This is just copied from http://www.systhread.net/texts/200508cdaemon2.php ... shameless. */
    umask( 0 );
    if (( sid = setsid()) < 0 ) {
        _error( "setsid: %s\n", strerror(errno) );
        return -1;
    }
        
    if ( chdir( "/var/run/" ) < 0 ) {
        _error( "chdir: %s\n", strerror(errno) );
        return -1;
    }
        
    /* pid is zero, this is the daemon process */
    /* Dupe these to logfile until something changes them */
    if (( logfile_fd = open( logfile, O_WRONLY | O_APPEND | O_CREAT, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH )) < 0 ) {
        _error( "open: %s\n", strerror(errno) );
        return -1;
    }
        
    close( STDIN_FILENO );
    close( STDOUT_FILENO );
    close( STDERR_FILENO );
    if ( dup2( logfile_fd, STDOUT_FILENO ) < 0 ) {
        _error( "dup2: %s\n", strerror(errno) );
        return -1;
    }
    if ( dup2( logfile_fd, STDERR_FILENO ) < 0 ) {
        _error( "dup2: %s\n", strerror(errno) );
        return -1;
    }

    return 0;
}

static void  _signal_term( int sig )
{
    running = 0;
}

static void  _signal_kill( int sig )
{
    exit(0);
}

static int   _set_signals( void )
{
    struct sigaction signal_action;
    
    memset( &signal_action, 0, sizeof( signal_action ));
    signal_action.sa_flags = SA_NOCLDSTOP;

    signal_action.sa_handler = _signal_term;
    sigaction( SIGINT,   &signal_action, NULL );

    signal_action.sa_handler = _signal_kill;
    sigaction( SIGALRM,  &signal_action, NULL );
    
    signal_action.sa_handler = SIG_IGN;
    sigaction( SIGCHLD,  &signal_action, NULL );
    sigaction( SIGPIPE,  &signal_action, NULL );
    
    return 0;
}

static int   _nfqueue_callback (struct nfq_q_handle *qh, struct nfgenmsg *nfmsg, struct nfq_data *nfa, void *data)
{
    _handle_packet(nfa);
    pthread_exit(NULL);
}

static void* _handle_packet ( struct nfq_data* nfa )
{
    int id = 0;
    struct nfqnl_msg_packet_hdr *ph;

    ph = nfq_get_msg_packet_hdr( nfa );
    if (!ph) {
        _error( "Packet missing header!\n" );
        pthread_exit( NULL );
    }
    id = ntohl( ph->packet_id );

    if (verbosity >= 1) _print_pkt( nfa );
    
    int out_port_utindex = _find_outdev_index(nfa);

    u_int mark = nfq_get_nfmark(nfa);

    if (out_port_utindex <= 0) {
        /**
         * Unable to determine out interface
         * Set the bypass mark and accept the packet
         */
        _debug( 2, "RESULT: current mark: 0x%08x\n", mark);
        mark = mark | MARK_BYPASS;
        _debug( 2, "RESULT: new     mark: 0x%08x\n", mark);

        mark = htonl( mark );
        nfq_set_verdict_mark(qh, id, NF_ACCEPT, mark, 0, NULL);
        pthread_exit( NULL );
    }
    else {
        _debug( 2, "RESULT: current mark: 0x%08x\n", mark);
        mark = mark & 0xFFFF00FF;
        mark = mark | (out_port_utindex << 8);
        _debug( 2, "RESULT: new     mark: 0x%08x\n", mark);

        mark = htonl( mark );
        nfq_set_verdict_mark(qh, id, NF_ACCEPT, mark, 0, NULL);
        pthread_exit( NULL );
    }

    pthread_exit( NULL );
}

static void  _print_pkt ( struct nfq_data *tb )
{
    int id = 0;
    struct nfqnl_msg_packet_hdr *ph;
    u_int32_t mark,ifindex;
    int ret;
    char *data;
    char intf_name[IF_NAMESIZE];
    
    if ( pthread_mutex_lock( &print_mutex ) < 0 ) {
        _error( "pthread_mutex_lock: %s\n", strerror(errno) );
    }

    if ( 1 ) {
        struct timeval tv;
        struct tm tm;
            
        gettimeofday(&tv,NULL);
        if (!localtime_r(&tv.tv_sec,&tm))
            _error( "gmtime_r: %s\n", strerror(errno) );
            
        printf( "%02i-%02i %02i:%02i:%02i.%06li| ", tm.tm_mon+1,tm.tm_mday,tm.tm_hour,tm.tm_min,tm.tm_sec, (long)tv.tv_usec );
    }
    
    ph = nfq_get_msg_packet_hdr(tb);
    if (ph){
        id = ntohl(ph->packet_id);
        printf("PACKET[%i]: ", id);
        printf("hw_protocol=0x%04x hook=%u id=%u ",
               ntohs(ph->hw_protocol), ph->hook, id);
    }

    mark = nfq_get_nfmark(tb);
    if (mark)
        printf("mark=0x%08x ", mark);

#if 0
    ifindex = nfq_get_indev(tb);
    if (ifindex) {
        if ( if_indextoname(ifindex, intf_name) == NULL) {
            _error( "print_pkt: in_dev: if_indextoname(%i): %s\n", ifindex, strerror(errno) );
        } else {
            printf("indev=(%i,%s) ", ifindex, intf_name);
        }
    }

    ifindex = nfq_get_outdev(tb);
    if (ifindex) {
        if ( if_indextoname(ifindex, intf_name) == NULL) {
            _error( "print_pkt: out_dev: if_indextoname(%i): %s\n", ifindex, strerror(errno) );
        } else {
            printf("outdev=(%i,%s) ", ifindex, intf_name);
        }
    }
#endif
    
#if 1
    ifindex = nfq_get_physindev(tb);
    if (ifindex) {
        if ( if_indextoname(ifindex, intf_name) == NULL) {
            _error( "print_pkt: in_dev: if_indextoname(%i): %s\n", ifindex, strerror(errno) );
        } else {
            printf( "physindev=(%i,%s) ", ifindex, intf_name);
        }
    }

    ifindex = nfq_get_outdev(tb);
    if (ifindex) {
        if ( if_indextoname(ifindex, intf_name) == NULL) {
            _error( "print_pkt: out_dev: if_indextoname(%i): %s\n", ifindex, strerror(errno) );
        } else {
            printf( "physoutdev=(%i,%s) ", ifindex, intf_name);
        }
    }
#endif
    
    ret = nfq_get_payload(tb, &data);
    if (ret >= 0)
        printf("payload_len=%d ", ret);

    if (ret < sizeof(struct iphdr)) {
        printf("\n");
    } else {
    
        struct iphdr * ip = (struct iphdr *) data;

        printf( "IPv%i ", ip->version);

        if (ip->version != 4) {
            printf("\n");
        } else {
            printf( "src: %s ", _inet_ntoa(ip->saddr));
            printf( "dst: %s ", _inet_ntoa(ip->daddr));
            printf( "\n" );
        }
    }

    if ( pthread_mutex_unlock( &print_mutex ) < 0 ) {
        _error( "pthread_mutex_unlock: %s\n", strerror(errno) );
    }

    return;
}

static int   _find_outdev_index ( struct nfq_data* nfq_data )
{
    struct ether_addr mac_address;
    struct in_addr next_hop;
    char *data;
    char intf_name[IF_NAMESIZE];
    int ret = 1;
    struct nfqnl_msg_packet_hdr* ph = nfq_get_msg_packet_hdr(nfq_data);
    int packet_id = 0;
    struct timeval start_time;
    struct timeval end_time;
  
    gettimeofday( &start_time, NULL );

    if ( ph )
        packet_id = ntohl(ph->packet_id);

    memset( &next_hop, 0, sizeof (struct in_addr) );
    
    /**
     * Lookup interface information - will return an interface like br.eth0
     */
    int ifindex = nfq_get_outdev( nfq_data );
    if (ifindex <= 0) {
        _error( "Unable to locate ifindex: %s\n", strerror(errno) );
        return -1;
    }
    if ( if_indextoname( ifindex, intf_name ) == NULL) {
        _error( "if_indextoname: %s\n", strerror(errno));
        return -1;
    }

    /**
     * Lookup dst IP
     */
    if ( ( ret = nfq_get_payload( nfq_data, &data ) ) < sizeof(struct iphdr) ) {
        _error( "packet too short: %i\n", ret);
        return -1;
    }
    struct iphdr * ip = (struct iphdr *) data;
    if ( ip->version != 4 ) {
        _error( "Ignoring non-IPV4 %i\n", ip->version);
        return -1;
    }
    struct in_addr dst;
    memcpy( &dst.s_addr, &ip->daddr, sizeof(in_addr_t));

    if ( _find_next_hop( intf_name, &dst, &next_hop) < 0 ) {
        _error( "_find_next_hop: %s\n", strerror(errno));
        return -1;
    }

    /**
     * Lookup the MAC address for next hop
     */
    if (( ret = _arp_address( &next_hop, &mac_address, intf_name )) < 0 ) {
        _error( "_arp_address: %s\n", strerror(errno) );
        return -1;
    }
    if ( ret == 0 ) {
        _error( "ARP: Unable to resolve the MAC address %s\n", inet_ntoa( next_hop ));
        return 0;
    }
    if ( memcmp(&mac_address, &broadcast_mac, sizeof(broadcast_mac)) == 0 )  {
        return 0;    
    }
    
    /**
     * Find the bridge port for next hop's MAC addr
     */
    int out_port_ifindex = _find_bridge_port( &mac_address, intf_name );
    if ( out_port_ifindex < 0 ) {
        _error( "_find_bridge_port: %s\n", strerror(errno) );
        return -1;
    }
    char bridge_port_intf_name[IF_NAMESIZE];
    if ( if_indextoname( out_port_ifindex, bridge_port_intf_name ) == NULL) {
        _error( "if_indextoname: %s\n", strerror(errno));
        return -1;
    }

    gettimeofday( &end_time, NULL );
    long long usec = _timeval_diff( &end_time, &start_time);
    
    /**
     * Now find Untangle's ID for that bridge port and return that ID
     */
    int i = 0;
    for( i = 0 ; i < MAX_INTERFACES ; i++ ) {
        if (interfaceNames[i] == NULL) {
            _error( "Unable to find interface: %s\n", bridge_port_intf_name );
            return -1;
        }

        if ( strncmp( bridge_port_intf_name, interfaceNames[i], IF_NAMESIZE ) == 0 ) {
            if (verbosity >= 1) {
                char mac_string[MAC_STRING_LENGTH];
                _mac_to_string( mac_string, sizeof( mac_string ), &mac_address );
                _debug( 1, "RESULT[%i]: nextHop: %s nextHopMAC: %s -> systemDev: %s interfaceId: %i usec: %lld\n", packet_id, inet_ntoa( next_hop ), mac_string, bridge_port_intf_name, interfaceIds[i], usec);
            }
            return interfaceIds[i];
        }
    }
    
    return -1;
}

static char* _inet_ntoa ( in_addr_t addr )
{
    struct in_addr i;
    memset(&i, 0, sizeof(i));
    i.s_addr = addr;
    
    strncpy( inet_ntoa_name, inet_ntoa( i ), INET_ADDRSTRLEN );
    
    return inet_ntoa_name;
}

static void  _mac_to_string ( char *mac_string, int len, struct ether_addr* mac )
{
    snprintf( mac_string, len, "%02x:%02x:%02x:%02x:%02x:%02x",
              mac->ether_addr_octet[0], mac->ether_addr_octet[1], mac->ether_addr_octet[2], 
              mac->ether_addr_octet[3], mac->ether_addr_octet[4], mac->ether_addr_octet[5] );
}

/**
 * This queries the kernel for the next hop for packets destined to the specied dst_ip.
 * For example,
 */
static int   _find_next_hop ( char* dev_name, struct in_addr* dst_ip, struct in_addr* next_hop )
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
            _error( "ARP: Destination IP is not reachable: %s\n", _inet_ntoa( args.addr) );
            return -1;
        default:  /* Ignore all other error codes */
            break;
        }

        _error( "SIOCFINDEV[%s] %s.\n", _inet_ntoa( dst_ip->s_addr ), strerror(errno) );
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
    _debug( 2,"ARP: next_hop %s going out [%s,%d]\n", _inet_ntoa( next_hop->s_addr ), args.name, ifindex);
        
    return 0;
}

/**
 * Finds the bridge port for the given MAC address,
 * returns the OS ifindex
 * or -1 for error
 * or 0 for unknown
 */
static int   _find_bridge_port ( struct ether_addr* mac_address, char* bridge_name )
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
            _error( "ARP: Invalid argument, MAC Address is found in ARP Cache but not in bridge MAC table.\n" );
            return -1;
        } else {
            _error( "ioctl: %s\n", strerror(errno) );
            return -1;
        }
    }
        
    _debug( 2,  "ARP[%s]: Outgoing interface index is %s,%d\n", bridge_name, buffer, ret );
    
	return ret;
}

/**
 * Tries to determine the MAC address corresponding with the provided dst_ip
 * Initially it looks up the dst IP in the local ARP cache
 * If not, found it will force an ARP request and then check the cache again.
 *
 * Returns 1 if successfully resolved MAC address.
 * Returns 0 if ARP resolution failed
 * Returns -1 on error
 */
static int   _arp_address ( struct in_addr* dst_ip, struct ether_addr* mac, char* intf_name )
{
    int c = 0;
    int ret;
    unsigned int delay;
    struct in_addr src_ip;

    while ( 1 ) {
        /* Check the cache before issuing the request */
        ret = _arp_lookup_cache_entry( dst_ip, intf_name, mac );
        if ( ret < 0 ) {
            _error( "_get_arp_entry: %s\n", strerror(errno) );
            return -1;
        } else if (ret == 1 ) {
            return 1;
        } else {
                _debug( 2,  "ARP: MAC not found for '%s' on '%s'. Sending ARP request.\n", _inet_ntoa( dst_ip->s_addr ), intf_name );
        }

        /* Connect and close so the kernel grabs the source address */
        if (( c == 0 ) && ( _arp_determine_source_addr( &src_ip, dst_ip, intf_name ) < 0 )) {
            _error( "Failed to determine address for %s: %s\n", intf_name, strerror(errno) );
            return -1;
        }

        /* Issue the arp request */
        if ( _arp_issue_request( &src_ip, dst_ip, intf_name ) < 0 ) {
            _error( "_arp_issue_request: %s\n", strerror(errno) );
            return -1;
        }

        delay = delay_array[c];
        if ( delay == 0 ) break;
        if ( delay < 0 ) {
            _error( "Invalid delay: index:%i delay:%i\n", c, delay );
            return -1;
        }
        c++;
        
        _debug( 2,  "Waiting for the response for: %i usec\n", delay );
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
static int   _arp_lookup_cache_entry ( struct in_addr* ip, char* intf_name, struct ether_addr* mac )
{
    struct arpreq request;
    struct sockaddr_in* sin = (struct sockaddr_in*)&request.arp_pa;
    struct ether_addr zero_mac = { .ether_addr_octet = { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 } };

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
            _debug( 2,  "ARP CACHE: MAC address for %s was not found\n", _inet_ntoa( ip->s_addr ));
            return 0;
        }

        _error( "ioctl: %s\n", strerror(errno));
        return -1;
    }

    /* Returning an all zero MAC address indicates that the MAC was not found */
    if ( memcmp( &request.arp_ha.sa_data, &zero_mac, sizeof( struct ether_addr )) == 0 ) {
        _debug( 2,  "ARP CACHE: Ethernet address for %s was not found\n", _inet_ntoa( ip->s_addr ));
        return 0;
    }

    memcpy( mac, &request.arp_ha.sa_data, sizeof( struct ether_addr ));

    if (verbosity >= 2) {
        char mac_string[MAC_STRING_LENGTH];
        _mac_to_string( mac_string, sizeof( mac_string ), mac );
        _debug( 2, "ARP: Cache resolved MAC[%d]: '%s' -> '%s'\n", ret, inet_ntoa( *ip ), mac_string );
    }

    return 1;
}

/**
 * This function creates a "fake" connection to the specified dst_ip
 * and resolves the source IP that would be used to connect to dst_ip.
 * It copies this value into src_ip and returns.
 *
 * Returns: 0 on success, -1 on error
 */
static int   _arp_determine_source_addr ( struct in_addr* src_ip, struct in_addr* dst_ip, char* intf_name )
{
    struct ifreq ifr;
    ifr.ifr_addr.sa_family = AF_INET;
    
    strncpy(ifr.ifr_name, intf_name, IFNAMSIZ-1);

    if ( ioctl( arp_socket, SIOCGIFADDR, &ifr) < 0 ) {
        _error( "ioctl: %s\n", intf_name, strerror(errno) );
        return -1;
    }

    memcpy( src_ip, &((struct sockaddr_in *)&ifr.ifr_addr)->sin_addr, sizeof( struct in_addr ) );
    return 0;
}

/**
 * Sends an ARP request for the dst_ip (from the src_ip) on intf_name
 */
static int   _arp_issue_request ( struct in_addr* src_ip, struct in_addr* dst_ip, char* intf_name )
{
    struct ether_arp pkt;
    struct sockaddr_ll broadcast = {
        .sll_family   = AF_PACKET,
        .sll_protocol = htons( ETH_P_ARP ),
        .sll_ifindex  = 0, // set me 
        .sll_hatype   = htons( ARPHRD_ETHER ),
        .sll_pkttype  = PACKET_BROADCAST, 
        .sll_halen    = ETH_ALEN,
        .sll_addr = {
            0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF
        }
    };
    int size;

    /* Set the index */
    broadcast.sll_ifindex = if_nametoindex(intf_name);

    if (broadcast.sll_ifindex == 0) {
        _error( "failed to find index of \"%s\"\n", intf_name);
        return -1;
    }
    
    if ( _arp_build_packet( &pkt, src_ip, dst_ip, intf_name ) < 0 ) {
        _error( "_arp_build_packet: %s\n", strerror(errno));
        return -1;
    }
    
    size = sendto( pkt_socket, &pkt, sizeof( pkt ), 0, (struct sockaddr*)&broadcast, sizeof( broadcast ));

    if ( size < 0 ) {
        _error( "sendto: %s\n", strerror(errno) );
        return -1;
    }
    
    if ( size != sizeof( pkt )) {
        _error( "Transmitted truncated ARP packet %i < %i\n", size, (int)sizeof( pkt ));
        return -1;
    }
         
    return 0;
}

static int   _arp_build_packet ( struct ether_arp* pkt, struct in_addr* src_ip, struct in_addr* dst_ip, char* intf_name )
{
    struct ifreq ifr;
    struct ether_addr mac;
    struct sockaddr_ll broadcast = {
        .sll_family   = AF_PACKET,
        .sll_protocol = htons( ETH_P_ARP ),
        .sll_ifindex  = 6, // SETME WITH SOMETHING
        .sll_hatype   = htons( ARPHRD_ETHER ),
        .sll_pkttype  = PACKET_BROADCAST, 
        .sll_halen    = ETH_ALEN,
        .sll_addr = {
            0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF
        }
    };

    strncpy( ifr.ifr_name, intf_name, IFNAMSIZ );

    if ( ioctl( arp_socket, SIOCGIFHWADDR, &ifr ) < 0 ) {
        _error( "ioctl: %s\n", strerror( errno ));
        return -1;
    }

    memcpy( &mac, ifr.ifr_hwaddr.sa_data, sizeof( mac ));
    
    pkt->ea_hdr.ar_hrd = htons( ARPHRD_ETHER );
    pkt->ea_hdr.ar_pro = htons( ETH_P_IP );
    pkt->ea_hdr.ar_hln = ETH_ALEN;
	pkt->ea_hdr.ar_pln = sizeof( *dst_ip );
	pkt->ea_hdr.ar_op  = htons( ARPOP_REQUEST );
    memcpy( &pkt->arp_sha, &mac, sizeof( pkt->arp_sha ));
    memcpy( &pkt->arp_spa, src_ip, sizeof( pkt->arp_spa ));
    memcpy( &pkt->arp_tha, &broadcast.sll_addr, sizeof( pkt->arp_tha ));
    memcpy( &pkt->arp_tpa, dst_ip, sizeof( pkt->arp_tpa ));

    return 0;
}

long long _timeval_diff( struct timeval *end_time, struct timeval *start_time )
{
    struct timeval difference;

    difference.tv_sec =end_time->tv_sec -start_time->tv_sec ;
    difference.tv_usec=end_time->tv_usec-start_time->tv_usec;

    while( difference.tv_usec < 0 ) {
        difference.tv_usec += 1000000;
        difference.tv_sec -= 1;
    }

    return 1000000LL*difference.tv_sec+ difference.tv_usec;
} 
