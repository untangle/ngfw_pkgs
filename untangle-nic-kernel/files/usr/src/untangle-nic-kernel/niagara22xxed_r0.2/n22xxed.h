/*
 * n22xx.h -- definitions for the n22xx char module
 *
 */

#include <linux/ioctl.h>

/* version dependencies have been confined to a separate file */

#include "sysdep.h"


/*
 * Macros to help debugging
 */


#define N22XX_MAJOR 0   /* dynamic major by default */
#define N22XX_DEVS 4   

extern int n22xxed_major;     /* main.c */
extern int n22xxed_devs;
/*
 * The bare device is a variable-length region of memory.
 * Use a linked list of indirect blocks.

 * "ScullC_Dev->data" points to an array of pointers, each

 *
 * The array (quantum-set) is SCULLC_QSET long.
 */

/*
 * The different configurable parameters
 */
extern int n22xxed_major;     /* main.c */
extern int n22xxed_devs;

/*
 * Prototypes for shared functions
 */
/*
 * Ioctl definitions
 */

