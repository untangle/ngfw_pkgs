// nflogd.h
// LibNetFilter Logging Daemon
// Copyright (c) 2011-2015 Untangle, Inc.
// All Rights Reserved
// Written by Michael A. Hotz

#ifndef VERSION
#define VERSION "TEST"
#endif

#ifndef BUILDID
#define BUILDID "0"
#endif

/*--------------------------------------------------------------------------*/
class NetworkServer;
class NetworkClient;
class Problem;
/*--------------------------------------------------------------------------*/
class NetworkServer
{
public:

	NetworkServer(int aPort);
	virtual ~NetworkServer(void);

	void BeginExecution(void);
	int BroadcastMessage(const char *aMessage,int aSize);

private:

	static void* ThreadMaster(void *arg);
	void* ThreadWorker(void);
	void InsertClient(NetworkClient *aClient);
	void RemoveClient(NetworkClient *aClient);

	NetworkClient			*ClientList;
	pthread_t				ThreadHandle;
	sem_t					ThreadSignal;
	int						ListenPort;
	int						netsock;
};
/*--------------------------------------------------------------------------*/
class NetworkClient
{
friend class NetworkServer;

protected:

	NetworkClient(int aSock);
	virtual ~NetworkClient(void);

	int NetworkHandler(void);
	int TransmitMessage(const char *buffer,int size);

	NetworkClient			*next;
	struct sockaddr_in		netaddr;
	char					netname[32];
	int						netsock;
};
/*--------------------------------------------------------------------------*/
class Problem
{
public:

	inline Problem(const char *aString = NULL,int aValue = 0)
	{
	string = aString;
	value = aValue;
	}

	inline ~Problem(void)
	{
	}

	const char				*string;
	int						value;
};
/*--------------------------------------------------------------------------*/
void hexmessage(int priority,const void *buffer,int size);
void logmessage(int priority,const char *format,...);
void rawmessage(int priority,const char *message);
void sighandler(int sigval);
void logrecycle(void);
char *itolevel(int value,char *dest);
void* capture_thread(void *arg);
/*--------------------------------------------------------------------------*/
#ifndef DATALOC
#define DATALOC extern
#endif
/*--------------------------------------------------------------------------*/
DATALOC pthread_t			g_capture_tid;
DATALOC sem_t				g_capture_sem;
DATALOC struct itimerval	g_itimer;
DATALOC struct timeval		g_runtime;
DATALOC size_t				g_stacksize;
DATALOC NetworkServer		*g_netserver;
DATALOC int					g_logrecycle;
DATALOC int					g_shutdown;
DATALOC int					g_console;
DATALOC int					g_nofork;
DATALOC int					g_debug;
/*--------------------------------------------------------------------------*/

