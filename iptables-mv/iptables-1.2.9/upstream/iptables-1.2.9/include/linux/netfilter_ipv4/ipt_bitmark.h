/* IP tables module for matching the value of the TTL
 * (C) 2004 by Jim Mar <jmar@metavize.com> */

#ifndef _IPT_BITMARK_H
#define _IPT_BITMARK_H

struct ipt_bitmark_info {
	int		invertxct;
	int		invertone;
	int		invertzed;
	unsigned long	exactval;
	unsigned long	exactmsk;
	unsigned long	anyone;
	unsigned long	anyzed;
	unsigned long	flags;
};

#endif
