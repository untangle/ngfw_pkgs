// NETCLIENT.CPP
// LibNetFilter Logging Daemon
// Copyright (c) 2011-2015 Untangle, Inc.
// All Rights Reserved
// Written by Michael A. Hotz

#include "common.h"
#include "nflogd.h"
/*--------------------------------------------------------------------------*/
NetworkClient::NetworkClient(int aSock)
{
const char			*username;
unsigned			size;
int					value;
int					ret;

// initialize our member variables
next = NULL;

// accept the inbound connection
memset(&netaddr,0,sizeof(netaddr));
size = sizeof(netaddr);
netsock = accept(aSock,(sockaddr *)&netaddr,(socklen_t *)&size);

	if (netsock < 0)
	{
	// if nobody is there just throw an empty problem
	if (errno == EWOULDBLOCK) throw(new Problem());

	// otherwise throw a problem with a message and error code
	throw(new Problem("Error returned from accept()",errno));
	}

// set socket options
value = 1;
ret = setsockopt(netsock,IPPROTO_TCP,TCP_NODELAY,(char *)&value,sizeof(value));

	if (ret != 0)
	{
	throw(new Problem("Error returned from setsockopt()",errno));
	}

// construct network name string for logging and such
username = inet_ntoa(netaddr.sin_addr);
if (username == NULL) username = "xxx.xxx.xxx.xxx";
sprintf(netname,"%s:%d",username,netaddr.sin_port);

logmessage(LOG_DEBUG,"NETCLIENT CONNECT: %s\n",netname);
}
/*--------------------------------------------------------------------------*/
NetworkClient::~NetworkClient(void)
{
logmessage(LOG_DEBUG,"NETCLIENT GOODBYE: %s\n",netname);

// shutdown and close the socket
shutdown(netsock,SHUT_RDWR);
close(netsock);
}
/*--------------------------------------------------------------------------*/
int NetworkClient::NetworkHandler(void)
{
char	buffer[1024];
int		ret;

// read data from the client to the current offset in our recv buffer
ret = recv(netsock,&buffer,sizeof(buffer),0);

// if the client closed the connection return zero
// to let the server thread know we're done
if (ret == 0) return(0);

	// return of less than zero and we log the error
	// and let the server thread know we're done
	if (ret < 0)
	{
	logmessage(LOG_ERR,"Error %d returned from recv(%s)\n",errno,netname);
	return(0);
	}

buffer[ret] = 0;
logmessage(LOG_DEBUG,"NETCLIENT MESSAGE: %s = %s\n",netname,buffer);

return(1);
}
/*--------------------------------------------------------------------------*/
int NetworkClient::TransmitMessage(const char *buffer,int size)
{
struct timeval	tv;
fd_set			tester;
int				off,ret;

off = 0;

	while (off != size)
	{
	if (g_shutdown != 0) break;

	// clear our set and add the client socket
	FD_ZERO(&tester);
	FD_SET(netsock,&tester);

	// wait for the socket to be ready for writing
	tv.tv_sec = 1;
	tv.tv_usec = 0;
	ret = select(netsock+1,NULL,&tester,NULL,&tv);
	if (ret < 1) continue;
	if (FD_ISSET(netsock,&tester) == 0) continue;

	// write to the socket
	ret = send(netsock,&buffer[off],size - off,0);

		// check for errors
		if (ret == -1)
		{
		if (errno == EWOULDBLOCK) continue;
		logmessage(LOG_ERR,"Error %d returned from send(%s)\n",errno,netname);
		return(0);
		}

	// add the size just sent to the total transmitted
	off+=ret;
	}

return(1);
}
/*--------------------------------------------------------------------------*/

