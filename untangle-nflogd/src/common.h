// COMMON.H
// LibNetFilter Logging Daemon
// Copyright (c) 2011-2015 Untangle, Inc.
// All Rights Reserved
// Written by Michael A. Hotz

#define __STDC_FORMAT_MACROS

#include <semaphore.h>
#include <pthread.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <syslog.h>
#include <signal.h>
#include <unistd.h>
#include <stdio.h>
#include <errno.h>
#include <fcntl.h>
#include <sys/resource.h>
#include <sys/time.h>
#include <sys/stat.h>
#include <arpa/inet.h>
#include <netinet/ip.h>
#include <netinet/tcp.h>
#include <netinet/udp.h>
#include <netinet/ip_icmp.h>

