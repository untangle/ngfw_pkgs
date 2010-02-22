#ifndef _N22XX_HW_H_
#define _N22XX_HW_H_

#include <linux/timer.h>
#include "n22xxed_osdep.h"

#define N22XX_EECD     			0x00010  	// EEPROM/Flash Control - RW 
#define N22XX_CTRL     			0x00000  	// Device Control - RW 
#define N22XX_CTRL_EXT 			0x00018  	// Extended Device Control - RW 

#define N22XX_CTRL_EXT_SDP4_DIR         0x00000100      // Direction of SDP4 0=in 1=out 
#define N22XX_CTRL_EXT_SDP5_DIR         0x00000200      // Direction of SDP5 0=in 1=out 
#define N22XX_CTRL_EXT_SDP6_DIR  	0x00000400 	// Direction of SDP6 0=in 1=out 
#define N22XX_CTRL_EXT_SDP7_DIR  	0x00000800 	// Direction of SDP7 0=in 1=out 

#define N22XX_CTRL_EXT_SDP4_DATA        0x00000010      // Value of SW Defineable Pin 4 
#define N22XX_CTRL_EXT_SDP5_DATA        0x00000020      // Value of SW Defineable Pin 5 
#define N22XX_CTRL_EXT_SDP6_DATA 	0x00000040 	// Value of SW Defineable Pin 6 
#define N22XX_CTRL_EXT_SDP7_DATA 	0x00000080 	// Value of SW Defineable Pin 7 

#define N22XX_CTRL_SWDPIN0  		0x00040000  	// SWDPIN 0 value 
#define N22XX_CTRL_SWDPIN1  		0x00080000  	// SWDPIN 1 value 
#define N22XX_CTRL_SWDPIN2              0x00100000      // SWDPIN 2 value 
#define N22XX_CTRL_SWDPIN3              0x00200000      // SWDPIN 3 value 

#define N22XX_CTRL_SWDPIO0  		0x00400000  	// SWDPIN 0 Input or output 
#define N22XX_CTRL_SWDPIO1  		0x00800000  	// SWDPIN 1 input or output 
#define N22XX_CTRL_SWDPIO2              0x01000000      // SWDPIN 2 input or output 
#define N22XX_CTRL_SWDPIO3              0x02000000      // SWDPIN 3 input or output 

// Port B	
#define IM_WDI_DIR			N22XX_CTRL_EXT_SDP7_DIR 
#define IM_SPI_CLK_DIR			N22XX_CTRL_SWDPIO1
#define IM_SPI_MISO_DIR			N22XX_CTRL_SWDPIO0
#define IM_SPI_MOSI_DIR			N22XX_CTRL_EXT_SDP6_DIR
#define IM_WDI_DATA			N22XX_CTRL_EXT_SDP7_DATA  
#define IM_SPI_CLK_DATA			N22XX_CTRL_SWDPIN1 
#define IM_SPI_MISO_DATA		N22XX_CTRL_SWDPIN0
#define	IM_SPI_MOSI_DATA		N22XX_CTRL_EXT_SDP6_DATA

// Port A	
#define IM_RELAY_ON_DIR 		N22XX_CTRL_EXT_SDP7_DIR
#define IM_RELAY_ON_DATA 		N22XX_CTRL_EXT_SDP7_DATA
#define	IM_SPI_RD_CMD			0x80	

#define N22XX_EECD_SK        0x00000001 /* EEPROM Clock */
#define N22XX_EECD_CS        0x00000002 /* EEPROM Chip Select */
#define N22XX_EECD_DI        0x00000004 /* EEPROM Data In */
#define N22XX_EECD_DO        0x00000008 /* EEPROM Data Out */
/* EEPROM Read */
#define N22XX_EERD     0x00014  /* EEPROM Read - RW */
#define N22XX_EERD_START      0x00000001 /* Start Read */
#define N22XX_EERD_DONE       0x00000010 /* Read Done */
#define N22XX_EERD_ADDR_SHIFT 8
#define N22XX_EERD_ADDR_MASK  0x0000FF00 /* Read Address */
#define N22XX_EERD_DATA_SHIFT 16
#define N22XX_EERD_DATA_MASK  0xFFFF0000 /* Read Data */
/* EEPROM WRITE */
#define N22XX_EEWR     0x0102C  /* EEPROM Write Register - RW */

#define N22XX_EEPROM_GRANT_ATTEMPTS 1000 /* EEPROM # attempts to gain grant */
#define N22XX_EEPROM_POLL_READ     0    /* Flag for polling for read complete */
#define N22XX_EEPROM_RW_REG_DONE   2    /* Offset to READ/WRITE done bit */
#define N22XX_EEPROM_RW_REG_DATA   16   /* Offset to data in EEPROM read/write registers */
#define N22XX_EECD_FWE_MASK  		0x00000030 
#define N22XX_EECD_FWE_DIS   		0x00000010 	// Disable FLASH writes 
#define N22XX_EECD_FWE_EN    		0x00000020 	// Enable FLASH writes 
#define N22XX_EECD_REQ       0x00000040 /* EEPROM Access Request */
#define N22XX_EECD_GNT       0x00000080 /* EEPROM Access Grant */
#define N22XX_EECD_PRES      0x00000100 /* EEPROM Present */
#define N22XX_EECD_TYPE      0x00002000 /* EEPROM Type (1-SPI, 0-Microwire) */

#define IM_NS_DIR                       N22XX_CTRL_SWDPIO0 
#define IM_A0_DIR                       N22XX_CTRL_EXT_SDP6_DIR  	 
#define IM_A1_DIR                       N22XX_CTRL_EXT_SDP7_DIR  	 

#define IM_NS_DATA                      N22XX_CTRL_SWDPIN0 
#define IM_A0_DATA                      N22XX_CTRL_EXT_SDP6_DATA  	 
#define IM_A1_DATA                      N22XX_CTRL_EXT_SDP7_DATA  	 

// Port B	
#define IM_A2_DIR                       N22XX_CTRL_SWDPIO0 
#define IM_A3_DIR                       N22XX_CTRL_EXT_SDP6_DIR  	 
#define IM_DIR_DIR                      N22XX_CTRL_EXT_SDP7_DIR  	 

#define IM_A2_DATA                      N22XX_CTRL_SWDPIN0 
#define IM_A3_DATA                      N22XX_CTRL_EXT_SDP6_DATA  	 
#define IM_DIR_DATA                     N22XX_CTRL_EXT_SDP7_DATA  	 

#define IM_D0_DIR                       N22XX_CTRL_SWDPIO0 
#define IM_D1_DIR                       N22XX_CTRL_EXT_SDP6_DIR  	 
#define IM_D2_DIR                       N22XX_CTRL_EXT_SDP7_DIR  	 

#define IM_D0_DATA                      N22XX_CTRL_SWDPIN0 
#define IM_D1_DATA                      N22XX_CTRL_EXT_SDP6_DATA  	 
#define IM_D2_DATA                      N22XX_CTRL_EXT_SDP7_DATA 	 

// Port A	
#define IM_D3_DIR                       N22XX_CTRL_SWDPIO0 
#define IM_D4_DIR                       N22XX_CTRL_EXT_SDP6_DIR 
#define IM_DS_DIR                       N22XX_CTRL_EXT_SDP7_DIR  	 

#define IM_D3_DATA                      N22XX_CTRL_SWDPIN0 
#define IM_D4_DATA                      N22XX_CTRL_EXT_SDP6_DATA
#define IM_DS_DATA                      N22XX_CTRL_EXT_SDP7_DATA  	 

// serial eeprom op code
#define WREN	0x06
#define WRDI	0x04
#define	RDSR	0x05
#define WRSR	0x01
#define	S_READ	0x03
#define	S_WRITE	0x02

struct n22xxed_hd {
    uint8_t 		*hw_a;
    uint8_t 		*hw_b;
    uint8_t             subdev_id;
    struct timer_list   im_bypass_timer;
    boolean_t           timer_set;
    struct timer_list 	im_bypass_timer_b;
    boolean_t 		timer_set_b;
    uint8_t 		fw_rev;
    uint32_t 		*fl_addr;
    int                 heartbeat;
};

#endif 


