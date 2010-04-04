/* Copyright(c) 2007, 2008 Broadcom Corporation, all rights reserved
 * Proprietary and Confidential Information.
 *
 * This source file is the property of Broadcom Corporation, and
 * may not be copied or distributed in any isomorphic form without 
 * the prior written consent of Broadcom Corporation. 
 *
 * Name:        bnx2id.c
 *
 * Description: Daemon that monitors the existence of iSCSI HBA
 *                and creates/binds sockets at its request.
 *
 * Author:      Albert To (albertt@broadcom.com)
 *
 * Modifications:
 *		Anil Veerabhadrappa - added ioctl support
 *		01/03/2009 - Added code to change RLIMIT (Resource LIMIT) to increase
 *				 the number of open file descriptors in order to support 1K conn
 * Revision: 1
 */

#include <sys/types.h>
#include <sys/stat.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <errno.h>
#include <unistd.h>
#include <syslog.h>
#include <string.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <signal.h>
//#include <sys/sem.h>
#include <sys/time.h>
#include <sys/resource.h>

#include "bnx2i_ioctl.h"

#define BNX2ID_BIN    bnx2id
#define BNX2ID_VER    "1.0.1d 12/29/2008"

#define MIN_PORT_NUM    3000
#define MAX_PORT_NUM    60000
#define MAX_HBA_NUM     8

#define MAX_TCP_PORT    4096
#define MAX_TABLE_SIZE  (MAX_TCP_PORT * MAX_HBA_NUM)
#define TCP_PORTS_MASK  (MAX_TCP_PORT - 1)
#define TABLE_SIZE_MASK (MAX_TABLE_SIZE - 1)

static char g_ioctl_dev_path[] = "/dev";
static char g_ioctl_dev_name[] = "bnx2i";
static char g_devices_path[] = "/proc/devices";
static char g_pid_path[] = "/var/run/bnx2id.pid";

static unsigned int  g_prod_idx;
static unsigned int  g_cons_idx;
static int g_tcp_port[MAX_TABLE_SIZE];
static int g_port_num = MAX_PORT_NUM;
static int g_exit;

static struct hba_info {
	char path_name[256];
	unsigned int  prod_idx;
	unsigned int  cons_idx;
	int tcp_port[MAX_TCP_PORT];
	int sock_fd[MAX_TCP_PORT];
} *g_ioctl_dev[MAX_HBA_NUM];

#ifdef DEBUG
static void debug_print(int type, const char *fmt, ...)
{
	va_list args;
	char buf[256];

	va_start(args, fmt);
	vsprintf(buf, fmt, args);
	syslog(LOG_DAEMON | type, buf);
	va_end(args);
}
#else
static void debug_print(int type, const char *fmt, ...)
{
}
#endif

static struct hba_info *alloc_ioctl_dev(void)
{
	struct hba_info *dev;

	if (!(dev = malloc(sizeof *dev))) {
		syslog(LOG_DAEMON | LOG_CRIT, "malloc() failed.\n");
		return NULL;
	}

	memset(dev, 0, sizeof *dev);
	sprintf(dev->path_name, "%s/%s", g_ioctl_dev_path, g_ioctl_dev_name);

	g_ioctl_dev[0] = dev;
	return dev;
}

static int get_port_num(void)
{
	int portnum, portidx;

	if (g_prod_idx == g_cons_idx) {
		portnum = g_port_num--;
		g_port_num = g_port_num < MIN_PORT_NUM ?
			MAX_PORT_NUM : g_port_num;
	} else {
		portidx = g_cons_idx & TABLE_SIZE_MASK;
		g_cons_idx++;
		portnum = g_tcp_port[portidx];
	}

	return portnum;
}

static void put_port_num(int portnum)
{
	int portidx;

	portidx = g_prod_idx & TABLE_SIZE_MASK;
	g_prod_idx++;
	g_tcp_port[portidx] = portnum;
}

static void close_socket(struct hba_info *dev)
{
	int portidx, begport, endport;

	if (dev->prod_idx == dev->cons_idx)
		return;

	begport = dev->tcp_port[dev->cons_idx & TCP_PORTS_MASK];
	while (dev->cons_idx != dev->prod_idx) {
		portidx = dev->cons_idx & TCP_PORTS_MASK;
		dev->cons_idx++;
		close(dev->sock_fd[portidx]);
		put_port_num(dev->tcp_port[portidx]);
	}
	endport = dev->tcp_port[portidx];
	debug_print(LOG_INFO,
		"Closing sockets (ports %d-%d)...\n", begport, endport);
}

static int bnx2id_open_ioctl_dev(struct hba_info *dev)
{
	int fd;

	fd = open(dev->path_name, O_NONBLOCK);
	return fd;
}

static int get_port_req(char *path)
{
	int fd;
	int portcnt = -1;
	struct bnx2i_get_port_count port_cnt;

	fd = open(path, O_NONBLOCK);
	if (fd == -1) {
		debug_print(LOG_ALERT, "ioctl dev not opened, errno = %d\n", errno);
		return -1;
	}

	memset(&port_cnt, 0, sizeof port_cnt);
	strcpy(port_cnt.hdr.signature, BNX2I_MGMT_SIGNATURE);

	if (ioctl(fd, BNX2I_IOCTL_GET_PORT_REQ, &port_cnt) != -1) {
		portcnt = port_cnt.port_count;
	} else {
		portcnt = 0;
		debug_print(LOG_ALERT, "ioctl err, %d\n", errno);
	}

	close(fd);

	if (portcnt != -1)
		portcnt &= 0xffff;

	return portcnt;
}

static void unassign_port(struct hba_info *dev, int cnt)
{
	int i, portidx;

	for (i = 0; i < cnt; i++) {
		portidx = --dev->prod_idx & TCP_PORTS_MASK;
		close(dev->sock_fd[portidx]);
		put_port_num(dev->tcp_port[portidx]);
	}
}

static int service_port_req(struct hba_info *dev)
{
	int portidx, portnum, portcnt, sockfd, portreq; 
	struct sockaddr_in serv_addr;
	struct bnx2i_set_port_num *tcp_req;
	int fd;

	portreq = get_port_req(dev->path_name);

	if (portreq == 0xffff || portreq == 0) {
		debug_print(LOG_ALERT, "Zero portbind requested.\n");
		return 0;
	}

	if (portreq < 0) {
		debug_print(LOG_ALERT, "Device/driver removed.\n");
		close_socket(dev);
		return -1;
	}

	debug_print(LOG_INFO,
		"Binding %d port(s) for device: %s...\n", portreq, dev->path_name);

	tcp_req = malloc(sizeof *tcp_req + (portreq * 2));
	if (!tcp_req) {
		syslog(LOG_DAEMON | LOG_CRIT, "malloc() failed.\n");
		return 0;
	}

	memset(tcp_req, 0, sizeof *tcp_req + (portreq * 2));
	memset(&serv_addr, 0, sizeof serv_addr);
	serv_addr.sin_family = AF_INET;
	serv_addr.sin_addr.s_addr = INADDR_ANY;

	portcnt = 0;
	while (portreq--) {
		sockfd = socket(AF_INET, SOCK_STREAM, 0);
		if (sockfd < 0) {
			syslog(LOG_DAEMON | LOG_CRIT, "socket() failed.\n");
			if (!portcnt)
				goto free_mem;
			else
				break;
		}

		portnum = get_port_num();
		serv_addr.sin_port = htons(portnum);
		if (bind(sockfd, (struct sockaddr *) &serv_addr, sizeof(serv_addr)) < 0) {
			debug_print(LOG_ALERT,
				"Socket bind to port %d failed.\n", portnum);
			close(sockfd);
			break;
		}

		debug_print(LOG_INFO,
			"Socket bind to port %d succeed.\n", portnum);
		portidx = dev->prod_idx++ & TCP_PORTS_MASK;
		dev->sock_fd[portidx] = sockfd;
		dev->tcp_port[portidx] = portnum;
		tcp_req->tcp_port[portcnt++] = portnum;
	}

	fd = bnx2id_open_ioctl_dev(dev);
	if (fd == -1)
		goto ret_port_exit;

	strcpy(tcp_req->hdr.signature, BNX2I_MGMT_SIGNATURE);
	tcp_req->num_ports = portcnt;

	if (ioctl(fd, BNX2I_IOCTL_SET_TCP_PORT, tcp_req) == -1) {
		debug_print(LOG_ALERT, "ioctl err, %d\n", errno);
		goto close_dev_ret_port_exit;
	}

	close(fd);

free_mem:
	free(tcp_req);
	return 0;

close_dev_ret_port_exit:
	close(fd);
ret_port_exit:
	unassign_port(dev, portcnt);

	return 0;
}

static int get_bnx2i_major_num(void)
{
	FILE *src;
	char str[256];
	char name[64];
	int num = -1;

        if (!(src = fopen(g_devices_path, "r")))
                return -1;

        while (fgets(str, sizeof str, src)) {
		if (strstr(str, "bnx2i")) {
                	sscanf(str, "%d %s", &num, name);
			break;
		}
	}

        fclose(src);
	return num;
}

static int create_char_device(struct hba_info *dev)
{
	int major_num;
	char cmd[256];

	major_num = get_bnx2i_major_num();
	if (major_num < 0) {
		debug_print(LOG_ALERT, "Device/driver not found.\n");
		return -1;
	}

	sprintf(cmd, "rm -f %s", dev->path_name);
	debug_print(LOG_INFO, "cmd: %s\n", cmd);
	system(cmd);

	sprintf(cmd, "mknod %s c %d 0", dev->path_name, major_num);
	debug_print(LOG_INFO, "cmd: %s\n", cmd);
	system(cmd);

	return 0;
}
static void bnx2i_run_daemon(void)
{
	struct hba_info *dev;

	debug_print(LOG_INFO, "alloc ioctl dev\n");

	if (!(dev = alloc_ioctl_dev()))
		return;

	while (1) {
		if (g_exit)
			break;

		if (create_char_device(dev)) {
			sleep(5);
			continue;
		}

		while (!service_port_req(dev))
			sleep(5);
	}

	free(dev);
}

static void termination_handler(int signal)
{
	struct hba_info *dev = g_ioctl_dev[0];

	if (dev->prod_idx == dev->cons_idx)
		g_exit = 1;
	else
		debug_print(LOG_INFO, "Daemon can't exit.  Device busy\n");
}

static int check_duplicate_run(void)
{
	FILE *src;
	char str[256], path[256];
	int found = 0, pid = 0;

	if (!(src = fopen(g_pid_path, "r")))
		return 0;

	if (fgets(str, sizeof str, src))
		sscanf(str, "%d", &pid);
	fclose(src);

	if (!pid)
		return 0;

	sprintf(path, "/proc/%d/cmdline", pid);
	if (!(src = fopen(path, "r")))
		return 0;

        while (fgets(str, sizeof str, src)) {
		if (strstr(str, "bnx2i")) {
			found = 1;
			break;
		}
	}

        fclose(src);
	return found;
}

void create_pid_file(int pid)
{
	FILE *src;

	if (!(src = fopen(g_pid_path, "w")))
		return;

	fprintf(src, "%d", pid);
        fclose(src);
}

int main(int argc, char **argv)
{
	pid_t pid, sid;
	struct rlimit my_rlimit;
	int rc;

	if (check_duplicate_run()) {
		printf("bnx2i-daemon already run\n");
		exit(EXIT_SUCCESS);
	}

	rc = getrlimit(RLIMIT_NOFILE, &my_rlimit);
	if (!rc && my_rlimit.rlim_max < 2048) {
		my_rlimit.rlim_cur = 2048;
		my_rlimit.rlim_max = 2048;

		rc = setrlimit(RLIMIT_NOFILE, &my_rlimit);
		if (rc)
			printf("bnx2id : unable to set rlimit\n");
	}

	pid = fork();
	if (pid < 0)
		exit(EXIT_FAILURE);

	if (pid > 0)
		exit(EXIT_SUCCESS);

	umask(0);

	sid = setsid();
	if (sid < 0)
		exit(EXIT_FAILURE);
	
	if (chdir("/") < 0)
		exit(EXIT_FAILURE);

	close(STDIN_FILENO);
	close(STDOUT_FILENO);
	close(STDERR_FILENO);

	openlog("bnx2i-daemon", LOG_PID | LOG_CONS, LOG_DAEMON);
	syslog(LOG_DAEMON | LOG_INFO, "bnx2id daemon started.\n");
	signal(SIGTERM, termination_handler);
	create_pid_file((int)sid);
	bnx2i_run_daemon();
	syslog(LOG_DAEMON | LOG_INFO,
		"bnx2id daemon stopped.\n");
	closelog();
	exit(EXIT_SUCCESS);
}
