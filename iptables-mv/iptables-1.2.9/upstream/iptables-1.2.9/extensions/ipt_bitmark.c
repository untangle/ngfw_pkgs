/* IP tables module for bit matching the value of the nfmark 
 *
 * (C) 2004 by Jim Mar <jmar@metavize.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 as
 * published by the Free Software Foundation.
 */

#include <linux/module.h>
#include <linux/skbuff.h>

#include <linux/netfilter_ipv4/ipt_bitmark.h>
#include <linux/netfilter_ipv4/ip_tables.h>

MODULE_AUTHOR("Jim Mar <jmar@bitmark.com>");
MODULE_DESCRIPTION("IP tables nfmark bit matching module");
MODULE_LICENSE("GPL");

static int match(const struct sk_buff *skb, const struct net_device *in,
		 const struct net_device *out, const void *matchinfo,
		 int offset, int *hotdrop)
{
	const struct ipt_bitmark_info *info = matchinfo;
	unsigned long x;

	if (info->flags & 0x00000001) {
		x = skb->nfmark & info->exactmsk;
		if (info->invertxct == 0) {
			if (x != info->exactval) {
				return 0;
			}
		} else if (info->invertxct == 1) {
			if (x == info->exactval) {
				return 0;
			}
		}
	}

	if (info->flags & 0x00000002) {
		x = skb->nfmark & info->anyone;
		if (info->invertone == 0) {
			if (x == 0) {
				return 0;
			}
		} else if (info->invertone == 1) {
			if (x != 0) {
				return 0;
			}
		}
	}

	if (info->flags & 0x00000004) {
		x = skb->nfmark & info->anyzed;
		if (info->invertzed == 0) {
			if (x == info->anyzed) {
				return 0;
			}
		} else if (info->invertzed == 1) {
			if (x != info->anyzed) {
				return 0;
			}
		}
	}

	return 1;
}

static int checkentry(const char *tablename, const struct ipt_ip *ip,
		      void *matchinfo, unsigned int matchsize,
		      unsigned int hook_mask)
{
	if (matchsize != IPT_ALIGN(sizeof(struct ipt_bitmark_info)))
		return 0;

	return 1;
}

static struct ipt_match bitmark_match = {
	.name		= "bitmark",
	.match		= &match,
	.checkentry	= &checkentry,
	.me		= THIS_MODULE,
};

static int __init init(void)
{
	return ipt_register_match(&bitmark_match);
}

static void __exit fini(void)
{
	ipt_unregister_match(&bitmark_match);

}

module_init(init);
module_exit(fini);
