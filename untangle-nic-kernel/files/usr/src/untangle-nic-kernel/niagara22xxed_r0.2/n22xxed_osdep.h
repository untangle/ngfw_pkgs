
#ifndef _N22XX_OSDEP_H_
#define	_N22XX_OSDEP_H_

#include <linux/types.h>
#include <linux/pci.h>
#include <linux/delay.h>
#include <asm/io.h>
#include <linux/interrupt.h>
//#include "kcompat.h"
                                                                                
#define usec_delay(x) udelay(x)
#ifndef msec_delay
#define msec_delay(x)   do { if(in_interrupt()) { \
                                /* Don't mdelay in interrupt context! */ \
                                BUG(); \
                        } else { \
                                set_current_state(TASK_UNINTERRUPTIBLE); \
                                schedule_timeout((x * HZ)/1000); \
                        } } while(0)
#endif
                                                                                
#define PCI_COMMAND_REGISTER   PCI_COMMAND
#define CMD_MEM_WRT_INVALIDATE PCI_COMMAND_INVALIDATE
                                                                                
#if 1
typedef enum {
    FALSE = 0,
    TRUE = 1
} boolean_t;
#endif
#if 0                                                                           
#define N22XX_WRITE_REG(a, reg, value) \
	(writel((value), ((a)->hw_addr + N22XX_##reg)))
#define N22XX_READ_REG(a, reg) ( \
        readl((a)->hw_addr + N22XX_##reg))
#else
#define N22XX_WRITE_REG(a, reg, value) \
	(writel((value), (a + N22XX_##reg)))
#define N22XX_READ_REG(a, reg) ( \
        readl(a + N22XX_##reg))
#endif

#if 0 
#define N22XX_WRITE_REG_ARRAY(a, reg, offset, value) ( \
    ((a)->mac_type >= e1000_82543) ? \
        writel((value), ((a)->hw_addr + N22XX_##reg + ((offset) << 2))) : \
        writel((value), ((a)->hw_addr + N22XX_82542_##reg + ((offset) << 2))))
                                                                                
#define N22XX_READ_REG_ARRAY(a, reg, offset) ( \
    ((a)->mac_type >= e1000_82543) ? \
        readl((a)->hw_addr + N22XX_##reg + ((offset) << 2)) : \
        readl((a)->hw_addr + N22XX_82542_##reg + ((offset) << 2)))
#endif                                                                                
#define N22XX_WRITE_FLUSH(a) {uint32_t x; x = N22XX_READ_REG(a, STATUS);}
                                                                                
#endif /* _N22XX_OSDEP_H_ */
 
