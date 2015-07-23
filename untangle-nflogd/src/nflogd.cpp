// NFLOGD.CPP
// LibNetFilter Logging Daemon
// Copyright (c) 2011-2015 Untangle, Inc.
// All Rights Reserved
// Written by Michael A. Hotz

#define DATALOC
#include "common.h"
#include "nflogd.h"
/*--------------------------------------------------------------------------*/
const char *month[12] = { "Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec" };
const char *weekday[7] = { "Sun","Mon","Tue","Wed","Thu","Fri","Sat" };
const int client_port = 1999;
/*--------------------------------------------------------------------------*/
int main(int argc,char *argv[])
{
struct timeval		tv;
pthread_attr_t		attr;
rlimit				core;
fd_set				tester;
int					ret,x;

printf("[ NFLOGD ] Untangle LibNetFilter Logging Daemon Version %s\n",VERSION);

gettimeofday(&g_runtime,NULL);

// set the core dump file size limit
core.rlim_cur = 0x40000000;
core.rlim_max = 0x40000000;
setrlimit(RLIMIT_CORE,&core);

	for(x = 1;x < argc;x++)
	{
	if (strncasecmp(argv[x],"-F",2) == 0) g_nofork++;
	if (strncasecmp(argv[x],"-L",2) == 0) g_console++;

		if (strncasecmp(argv[x],"-D",2) == 0)
		{
		g_debug = atoi(&argv[x][2]);
		if (g_debug == 0) g_debug = 0xFFFF;
		}
	}

// change directory to path for core dump files
if (g_console == 0) chdir("/tmp");

// get the default application stack size so
// we can set the same stack size for threads
pthread_attr_init(&attr);
pthread_attr_getstacksize(&attr,&g_stacksize);
pthread_attr_destroy(&attr);

	if (g_console == 0)
	{
	// not running on the console so we use syslog
	openlog("nflogd",LOG_NDELAY,LOG_DAEMON);

	if (g_nofork == 0) ret = fork();
	else ret = 0;

		if (ret > 0)
		{
		printf("[ NFLOGD ] Daemon %d started successfully\n\n",ret);
		return(0);
		}

		if (ret < 0)
		{
		printf("[ NFLOGD ] Error %d on fork daemon process\n\n",errno);
		return(1);
		}

	// since we are running as a daemon we need to disconnect from the console
	freopen("/dev/null","r",stdin);
	freopen("/dev/null","w",stdout);
	freopen("/dev/null","w",stderr);
	}

signal(SIGALRM,sighandler);
signal(SIGTERM,sighandler);
signal(SIGQUIT,sighandler);
signal(SIGINT,sighandler);
signal(SIGHUP,sighandler);

// grab the profile itimer value for thread profiling support
getitimer(ITIMER_PROF,&g_itimer);

logmessage(LOG_NOTICE,"STARTUP Untangle NFlogd %d-Bit Version %s Build %s\n",(int)sizeof(void*)*8,VERSION,BUILDID);

if (g_console != 0) logmessage(LOG_NOTICE,"Running on console - Use ENTER or CTRL+C to terminate\n");

// create the network server
g_netserver = new NetworkServer(client_port);
g_netserver->BeginExecution();

// start the netfilter log capture thread
sem_init(&g_capture_sem,0,0);
pthread_attr_init(&attr);
pthread_attr_setstacksize(&attr,g_stacksize);
ret = pthread_create(&g_capture_tid,&attr,capture_thread,NULL);
pthread_attr_destroy(&attr);

	// if there was an error starting the thread set the shutdown flag
	if (ret != 0)
	{
	logmessage(LOG_ERR,"Error %d returned from pthread_create(capture)\n",ret);
	g_shutdown = 1;
	}

	// no error so wait for the thread to signal init complete
	else
	{
	sem_wait(&g_capture_sem);
	}

	while (g_shutdown == 0)
	{
		// if running on the console watch input for one second
		if (g_console != 0)
		{
		FD_ZERO(&tester);
		FD_SET(fileno(stdin),&tester);
		tv.tv_sec = 1;
		tv.tv_usec = 0;
		ret = select(fileno(stdin)+1,&tester,NULL,NULL,&tv);
		if ((ret == 1) && (FD_ISSET(fileno(stdin),&tester) != 0)) break;
		}

		// in daemon mode we just snooze for one second
		else
		{
		sleep(1);
		}

		if (g_logrecycle != 0)
		{
		logrecycle();
		g_logrecycle = 0;
		}
	}

// set the global shutdown flag
g_shutdown = 1;

// the five second alarm gives all threads time to shut down cleanly
// if any get stuck the abort() in the signal handler should do the trick
alarm(5);
pthread_join(g_capture_tid,NULL);
alarm(0);

// clean up the thread semaphores
sem_destroy(&g_capture_sem);

// cleanup the network server and log capture threads
delete(g_netserver);

logmessage(LOG_NOTICE,"GOODBYE Untangle NFlogd Version %s Build %s\n",VERSION,BUILDID);

// if not running on console close our syslog handle
if (g_console == 0) closelog();

return(0);
}
/*--------------------------------------------------------------------------*/
void sighandler(int sigval)
{
	switch(sigval)
	{
	case SIGALRM:
		abort();
		break;

	case SIGTERM:
	case SIGQUIT:
	case SIGINT:
		signal(sigval,sighandler);
		g_shutdown = 1;
		break;

	case SIGHUP:
		signal(sigval,sighandler);
		g_logrecycle = 1;
		break;
	}
}
/*--------------------------------------------------------------------------*/
void logrecycle(void)
{
// if running on console just return
if (g_console != 0) return;

// recycle our connection to the syslog facility
closelog();
openlog("nflogd",LOG_NDELAY,LOG_DAEMON);
}
/*--------------------------------------------------------------------------*/
void logmessage(int priority,const char *format,...)
{
va_list			args;
char			message[1024];

// don't even format the message if debug is not enabled
if ((priority == LOG_DEBUG) && (g_debug == 0)) return;

va_start(args,format);
vsnprintf(message,sizeof(message),format,args);
va_end(args);

rawmessage(priority,message);
}
/*--------------------------------------------------------------------------*/
void hexmessage(int priority,const void *buffer,int size)
{
const unsigned char		*data;
char					*message;
int						loc;
int						x;

// don't even format the message if debug is not enabled
if ((priority == LOG_DEBUG) && (g_debug == 0)) return;

message = (char *)malloc((size * 3) + 4);
data = (const unsigned char *)buffer;

	for(x = 0;x < size;x++)
	{
	loc = (x * 3);
	if (x == 0) sprintf(&message[loc],"%02X ",data[x]);
	else sprintf(&message[loc],"%02X ",data[x]);
	}

loc = (size * 3);
strcpy(&message[loc],"\n");
rawmessage(priority,message);
free(message);
}
/*--------------------------------------------------------------------------*/
void rawmessage(int priority,const char *message)
{
struct timeval	nowtime;
double			rr,nn,ee;
char			string[32];

	// if running on the console display log messages there
	if (g_console != 0)
	{
	gettimeofday(&nowtime,NULL);

	rr = ((double)g_runtime.tv_sec * (double)1000000.00);
	rr+=(double)g_runtime.tv_usec;

	nn = ((double)nowtime.tv_sec * (double)1000000.00);
	nn+=(double)nowtime.tv_usec;

	ee = ((nn - rr) / (double)1000000.00);

	itolevel(priority,string);
	printf("[%.6f] %s %s",ee,string,message);

	fflush(stdout);
	return;
	}

// not running on the consoleso we use the syslog facility
syslog(priority,"%s",message);
}
/*--------------------------------------------------------------------------*/
char *itolevel(int value,char *dest)
{
if (value == LOG_EMERG)		return(strcpy(dest,"EMERGENCY"));
if (value == LOG_ALERT)		return(strcpy(dest,"ALERT"));
if (value == LOG_CRIT)		return(strcpy(dest,"CRITICAL"));
if (value == LOG_ERR)		return(strcpy(dest,"ERROR"));
if (value == LOG_WARNING)	return(strcpy(dest,"WARNING"));
if (value == LOG_NOTICE)	return(strcpy(dest,"NOTICE"));
if (value == LOG_INFO)		return(strcpy(dest,"INFO"));
if (value == LOG_DEBUG)		return(strcpy(dest,"DEBUG"));

sprintf(dest,"LOG_%d",value);
return(dest);
}
/*--------------------------------------------------------------------------*/

