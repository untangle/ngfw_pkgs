// CAPTURE.CPP
// LibNetFilter Logging Daemon
// Copyright (c) 2011-2015 Untangle, Inc.
// All Rights Reserved
// Written by Michael A. Hotz

#include "common.h"
#include "nflogd.h"

extern "C" {
#include <libnetfilter_log/libnetfilter_log.h>
}

/*--------------------------------------------------------------------------*/
// local functions
int capture_startup(void);
void capture_shutdown(void);

// local variables
static struct nflog_handle			*l_log_handle;
static struct nflog_g_handle		*l_grp_handle;
static int							l_logsock;
/*--------------------------------------------------------------------------*/
static int capture_callback(
	struct nflog_g_handle *gh,
	struct nfgenmsg *nfmsg,
	struct nflog_data *nfa,
	void *data
	)
{
struct icmphdr	*icmphead;
struct tcphdr	*tcphead;
struct udphdr	*udphead;
struct iphdr	*iphead;
u_int16_t		sport,dport,itype;
const char		*prefix;
char			message[1024];
char			*packet_data;
char			sname[32];
char			dname[32];
int				sin,din;
int				packet_size;
int				protocol;
int				mark;
int				len;

// get the raw packet and check for sanity
packet_size = nflog_get_payload(nfa,&packet_data);
if ((packet_data == NULL) || (packet_size < 20)) return(0);

// get the prefix string
prefix = nflog_get_prefix(nfa);
if (prefix == NULL) prefix = "";

// get the mark and parse the source and dest interfaces
mark = nflog_get_nfmark(nfa);
sin = (mark & 0xFF);
din = ((mark & 0xFF00) >> 8);

// set up the IP, TCP, and UDP headers for parsing
iphead = (struct iphdr *)packet_data;
tcphead = (struct tcphdr *)&packet_data[iphead->ihl << 2];
udphead = (struct udphdr *)&packet_data[iphead->ihl << 2];
icmphead = (struct icmphdr *)&packet_data[iphead->ihl << 2];

// grab the protocol
protocol = iphead->protocol;

// extract the client and server addresses
inet_ntop(AF_INET,&iphead->saddr,sname,sizeof(sname));
inet_ntop(AF_INET,&iphead->daddr,dname,sizeof(dname));

// Since 0 is a valid ICMP type we use 999 to signal null or unknown
sport = dport = 0;
itype = 999;

	switch(protocol)
	{
	case IPPROTO_ICMP:
		itype = icmphead->type;
		break;
	case IPPROTO_TCP:
		sport = ntohs(tcphead->source);
		dport = ntohs(tcphead->dest);
		break;
	case IPPROTO_UDP:
		sport = ntohs(udphead->source);
		dport = ntohs(udphead->dest);
		break;
	}

len = sprintf(message,"|PROTO:%d|ICMP:%d|SINTF:%d|SADDR:%s|SPORT:%d|DINTF:%d|DADDR:%s|DPORT:%d|PREFIX:%s|\r\n",protocol,itype,sin,sname,sport,din,dname,dport,prefix);
g_netserver->BroadcastMessage(message,len);

return(0);
}
/*--------------------------------------------------------------------------*/
void* capture_thread(void *arg)
{
struct timeval		tv;
sigset_t			sigset;
fd_set				tester;
char				buffer[4096];
int					ret;

logmessage(LOG_INFO,"The capture thread is starting\n");

// set the itimer value of the main thread which is required
// for gprof to work properly with multithreaded applications
setitimer(ITIMER_PROF,&g_itimer,NULL);

// start by masking all signals
sigfillset(&sigset);
pthread_sigmask(SIG_BLOCK,&sigset,NULL);

// now we allow only the PROF signal
sigemptyset(&sigset);
sigaddset(&sigset,SIGPROF);
sigaddset(&sigset,SIGALRM);
pthread_sigmask(SIG_UNBLOCK,&sigset,NULL);

// call our capture startup function
ret = capture_startup();

// signal the startup complete semaphore
sem_post(&g_capture_sem);

	// if there were any capture startup errors set the shutdown flag
	if (ret != 0)
	{
	logmessage(LOG_ERR,"Error %d returned from capture_startup()\n",ret);
	g_shutdown = 1;
	}

	// sit in this loop processing messages from the queue
	while (g_shutdown == 0)
	{
	// clear the select set and add the log socket
	FD_ZERO(&tester);
	FD_SET(l_logsock,&tester);

	// wait for some log data
	tv.tv_sec = 1;
	tv.tv_usec = 0;
	ret = select(l_logsock+1,&tester,NULL,NULL,&tv);
	if (ret < 1) continue;

	// read the log data
	ret = recv(l_logsock,buffer,sizeof(buffer),0);

		// break out on error
		if (ret < 0)
		{
		logmessage(LOG_ERR,"Error %d returned from recv()\n",errno);
		break;
		}

	nflog_handle_packet(l_log_handle,buffer,ret);
	}

// call our capture shutdown function
capture_shutdown();

logmessage(LOG_INFO,"The capture thread has terminated\n");
return(NULL);
}
/*--------------------------------------------------------------------------*/
int capture_startup(void)
{
int		ret;

// open a log handle to the netfilter log library
l_log_handle = nflog_open();

	if (l_log_handle == NULL)
	{
	logmessage(LOG_ERR,"Error %d returned from nflog_open()\n",errno);
	return(__LINE__);
	}

// unbind any existing AF_INET handler
ret = nflog_unbind_pf(l_log_handle,AF_INET);

	if (ret < 0)
	{
	logmessage(LOG_ERR,"Error %d returned from nflog_unbind_pf()\n",errno);
	return(__LINE__);
	}

// bind us as the AF_INET handler
ret = nflog_bind_pf(l_log_handle,AF_INET);

	if (ret < 0)
	{
	logmessage(LOG_ERR,"Error %d returned from nflog_bind_pf()\n",errno);
	return(__LINE__);
	}

// bind our log handle to group zero
l_grp_handle = nflog_bind_group(l_log_handle,0);

	if (l_grp_handle == NULL)
	{
	logmessage(LOG_ERR,"Error %d returned from nflog_bind_group()\n",errno);
	return(__LINE__);
	}

// set copy packet mode to give us the first 256 bytes
ret = nflog_set_mode(l_grp_handle,NFULNL_COPY_PACKET,256);

	if (ret < 0)
	{
	logmessage(LOG_ERR,"Error %d returned from nflog_set_mode()\n",errno);
	return(__LINE__);
	}

// get a file descriptor for our log handle
l_logsock = nflog_fd(l_log_handle);

// register callback for our group handle
nflog_callback_register(l_grp_handle,&capture_callback,NULL);

return(0);
}
/*--------------------------------------------------------------------------*/
void capture_shutdown(void)
{
int		ret;

	// unbind from our group
	if (l_grp_handle != NULL)
	{
	ret = nflog_unbind_group(l_grp_handle);
	if (ret < 0) logmessage(LOG_ERR,"Error %d returned from nflog_unbind_group()\n",errno);
	}

	// close our log handle
	if (l_log_handle != NULL)
	{
	ret = nflog_close(l_log_handle);
	if (ret < 0) logmessage(LOG_ERR,"Error %d returned from nflog_close()\n",errno);
	}
}
/*--------------------------------------------------------------------------*/

