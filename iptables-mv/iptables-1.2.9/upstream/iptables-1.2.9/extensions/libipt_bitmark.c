/* Shared library add-on to iptables to add nfmark bit matching support 
 * (C) 2004 by Jim Mar <jmar@metavize.com>
 *
 * $Id
 *
 * This program is released under the terms of GNU GPL */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <getopt.h>
#include <iptables.h>

#include <linux/netfilter_ipv4/ip_tables.h>
#include <linux/netfilter_ipv4/ipt_bitmark.h>

static void help(void) 
{
	printf(
"bitmark match v%s options:\n"
"[!] --bitexact  value/mask	Match nfmark value with required mask\n"
"[!] --anyone mask		Match any one under mask\n"
"[!] --anyzed mask		Match any zero under mask\n"
, IPTABLES_VERSION);
}

static void init(struct ipt_entry_match *m, unsigned int *nfcache)
{
	/* caching not yet implemented */
	*nfcache |= NFC_UNKNOWN;
}

static int parse(int c, char **argv, int invert, unsigned int *flags,
		const struct ipt_entry *entry, unsigned int *nfcache,
		struct ipt_entry_match **match)
{
	struct ipt_bitmark_info *info = (struct ipt_bitmark_info *) (*match)->data;
	unsigned long value;
	char *end;

	check_inverse(optarg, &invert, &optind, 0);
	value = strtoul(optarg, &end, 0);

	if (!optarg)
		exit_error(PARAMETER_PROBLEM,
				"bitmark: You must specify a value");
	switch (c) {
		case '1':
			if (*flags & 0x00000001)
				exit_error(PARAMETER_PROBLEM,
					"bitmark: Can't specify option none or once");
			if (invert)
				info->invertxct = 1;
			else
				info->invertxct = 0;

			info->exactval = value;
			if (*end != '/')
				exit_error(PARAMETER_PROBLEM,
					"bitmark: must specify a mask");
			info->exactmsk = strtoul(end+1, &end, 0);
			*flags |= 0x00000001;
			info->flags = *flags;
			break;
		case '2':
			if (*flags & 0x00000002)
				exit_error(PARAMETER_PROBLEM,
					"bitmark: Can't specify option none or once");
			if (invert)
				info->invertone = 1;
			else
				info->invertone = 0;

			info->anyone = value;
			*flags |= 0x00000002;
			info->flags = *flags;
			break;
		case '3':
			if (*flags & 0x00000004)
				exit_error(PARAMETER_PROBLEM,
					"bitmark: Can't specify option none or once");
			if (invert)
				info->invertzed = 1;
			else
				info->invertzed = 0;

			info->anyzed = value;
			*flags |= 0x00000004;
			info->flags = *flags;
			break;
		default:
			return 0;

	}
	return 1;
}

static void final_check(unsigned int flags)
{
	if (!flags) 
		exit_error(PARAMETER_PROBLEM,
			"bitmark match: You must specify one of "
			"`--bitexact <value>/<mask>;"
			"`--anyone <value>', `-anyzed <value>'");
}

static void print(const struct ipt_ip *ip, 
		const struct ipt_entry_match *match,
		int numeric)
{
	const struct ipt_bitmark_info *info = 
		(struct ipt_bitmark_info *) match->data;

	printf("bitmark match ");
	if (info->flags & 0x00000001) {
		if (info->invertone)
			printf("! ");
		printf("bitexact 0x%08lx/0x%08lx ",
			info->exactval, info->exactmsk);
	}
	if (info->flags & 0x00000002) {
		if (info->invertone)
			printf("! ");
		printf("anyone 0x%08lx ", info->anyone);
	}
	if (info->flags & 0x00000004) {
		if (info->invertzed)
			printf("! ");
		printf("anyzed 0x%08lx ", info->anyzed);
	}
}

static void save(const struct ipt_ip *ip, 
		const struct ipt_entry_match *match)
{
	const struct ipt_bitmark_info *info =
		(struct ipt_bitmark_info *) match->data;
	if (info->invertone)
		printf("! ");
	printf("--anyone 0x%08lx ", info->anyone);
	if (info->invertzed)
		printf("! ");
	printf("--anyzed 0x%08lx ", info->anyzed);
}

static struct option opts[] = {
	{ "bitexact",  1, 0, '1'},
	{ "anyone", 1, 0, '2'},
	{ "anyzed", 1, 0, '3'},
	{ 0 }
};

static
struct iptables_match bitmark = {
	NULL,
	"bitmark",
	IPTABLES_VERSION,
	IPT_ALIGN(sizeof(struct ipt_bitmark_info)),
	IPT_ALIGN(sizeof(struct ipt_bitmark_info)),
	&help,
	&init,
	&parse,
	&final_check,
	&print,
	&save,
	opts
};


void _init(void) 
{
	register_match(&bitmark);
}
