#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <linux/unistd.h>
#include <sys/ioctl.h>
#include <net/if.h>
#include <sys/types.h>
#include <fcntl.h>

typedef __uint32_t uint32_t;        
typedef __uint16_t uint16_t;        
typedef __uint8_t uint8_t;          

#include "n22xxed_data.h"
#include "n22xxed_cmd.h"

#include <unistd.h>

#define SYSCALL(X,S) { if((X) < 0) { perror(S); return -1; } }
#define FILEPART(S)  ( rindex((S), '/') == NULL ? (S) : rindex((S), '/') + 1 )

#define TIMEOUT_SCALER_A	0
#define TIMEOUT_SCALER_B	1
#define OEM_ID			65
#define PRODUCT_ID		66
#define PRODUCT_REV		67
#define FW_ID			68
#define DEFAULT_MODE_A		50
#define DEFAULT_MODE_B		56
#define CURRENT_MODE_A		49
#define CURRENT_MODE_B		55
#define OPTICAL_BYPASS_MODE     53
#define INTERFACE_MODE          55
#define RLY_STA_ADDR		47

#define MAC_ID_OFFSET           2
#define DEV_ID_OFFSET           13


#define     TEST_WDI_KICK		0x0001
#define     TEST_RELAY_CHECK		0x0002
#define     TEST_WDT_READ		0x0004
#define     TEST_WDT_WRITE		0x0008
#define     TEST_WDT_DUMP		0x0010
#define     TEST_ADD_TIMER		0x0020
#define     TEST_DEL_TIMER		0x0040
#define     TEST_CARD_INFO		0x0080
#define     TEST_FORCE_ACTIVE 		0x0100
#define     TEST_FORCE_BYPASS		0x0200
#define     TEST_NORMAL_MODE		0x0400
#define     TEST_MODE_0	  		0x0800
#define     TEST_MODE_1	  		0x1000
#define     TEST_MODE_2	  		0x2000
#define     TEST_CPLD_READ		0x4000
#define     TEST_CPLD_WRITE		0x8000
#define	    TEST_REG_READ	        0x10000
#define     TEST_REG_WRITE	        0x20000
#define     TEST_MODE_3	  		0x40000
#define     TEST_SW_INTER	  	0x80000
#define     TEST_EE_DUMP	  	0x100000
#define     TEST_FW_UPDATE          	0x200000
#define     TEST_FORCE_MODE		0x400000
#define     TEST_S_EERD_MODE		0x800000
#define     TEST_S_EEWR_MODE		0x1000000
#define     TEST_FW_VERIFY          	0x2000000
#define	    TEST_EEPROM_READBACK  	0x4000000
#define     TEST_MODE_4	  		0x8000000
#define     TEST_MODE_5	  		0x10000000
#define     TEST_MODE_6	  		0x20000000
#define     TEST_NO_LINK_MODE		0x40000000

int new_mac=0;
// n2264eb copper
static unsigned short n2264_eeprom_copper[] = {
    0x0C00, 0x00BD, 0x3A39, 0x0530, 0xFFFF, 0x5002, 0xFFFF, 0xFFFF, 
    0xC981, 0x4902, 0x242F, 0x0038, 0x1FC1, 0x105E, 0x8086, 0xB17f, 
    0xC100, 0x105E, 0x5C00, 0x0000, 0x5400, 0x0000, 0x0000, 0x0100, 
    0x6CF6, 0x37B0, 0x07AE, 0x0403, 0x0783, 0x0000, 0xC303, 0x0602, 
    0xC100, 0x0EF0, 0x2164, 0x0040, 0x4400, 0x0000, 0x0000, 0x0000, 
    0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 
    0x0100, 0x4000, 0x121E, 0x4007, 0x0100, 0x4000, 0xFFFF, 0xFFFF, 
    0xFFFF, 0xFFFF, 0xFFFF, 0xFFFF, 0xFFFF, 0xFFFF, 0xFFFF, 0x81CF,
};

// n2264eb fiber
static unsigned short n2264_eeprom_fiber[] = {
    0x0C00, 0x00BD, 0x3A39, 0x0530, 0xFFFF, 0x4036, 0xFFFF, 0xFFFF, 
    0xC981, 0x4902, 0x063f, 0x0038, 0x1FC1, 0x105F, 0x8086, 0x3107, 
    0xC100, 0x105F, 0x5C00, 0x0000, 0x7700, 0x0000, 0x0000, 0x0100, 
    0x6CF6, 0x37B0, 0x07AE, 0x0403, 0x0783, 0x0000, 0xC303, 0x0602, 
    0xC100, 0x0EF0, 0x2164, 0x0040, 0x6700, 0x0000, 0x0000, 0x0000, 
    0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 
    0x0100, 0x4000, 0x121E, 0x4007, 0x0100, 0x4000, 0xFFFF, 0xFFFF, 
    0xFFFF, 0xFFFF, 0xFFFF, 0xFFFF, 0xFFFF, 0xFFFF, 0xFFFF, 0x81CF,
};

enum
{
    ADDR_OPTION = 0,
    DATA_OPTION,
    THE_END
};

const char *spi_opts[] =
{
    [ADDR_OPTION] = "addr",
    [DATA_OPTION] = "data",
    [THE_END] = NULL
};

static int n22xxed_update_eeprom_mac(int fd, struct n22xxed_data *data, unsigned short *n22xxed_eeprom, int mac_h,uint32_t mac_l)
{
    unsigned int 		checkSum = 0;
    unsigned int 		i;

    n22xxed_eeprom[0] = ((mac_h&0x00ff0000) >> 8) | ((mac_h&0xff000000)>>16);
    n22xxed_eeprom[1] = ((mac_h&0x0000ff00) >> 8) | ((mac_h&0x000000ff)<< 8);
    n22xxed_eeprom[2] = mac_l;
  
//    printf("eeprom[2]=0x%x\n",n22xxed_eeprom[2]);
//    printf("eeprom[3]=0x%x\n",n22xxed_eeprom[3]);

    // calculate checksum
    for(i = 0; i < 63; i++) {
        checkSum += n22xxed_eeprom[i];
    }

    // calculate checksum byte
    for(i = 0; (unsigned short) (checkSum+i) != 0xBABA; i++);

    // write checksumbyte to eeprom array
    n22xxed_eeprom[0x3f] = i;
   
    // calculate the checksum again   
    checkSum = 0 ;
    for(i = 0; i < 64; i++) {
       checkSum += n22xxed_eeprom[i];
    }
    
    printf("checkSum: 0x%x, (checkSum-BABA): 0x%x\n",
       (unsigned short) checkSum, (unsigned short) (checkSum) - 0xBABA);

    // update the eeprom with new mac addr
    for (i = 0; i < 64; i++) {
	data->p_addr=i;
	data->p_data=n22xxed_eeprom[i];
	ioctl(fd,S_WRITE_EEPROM,data,N22XX_BASE_SIOC);
    }
     
    return N22XX_STAT_OK;
}

static int n22xxed_eeprom_dump(int fd, struct n22xxed_data *data)
{
    int i;
		
    for (i = 0; i < 64; i++) {
	data->p_addr = i;
	ioctl(fd,S_READ_EEPROM,data,N22XX_BASE_SIOC);

	if (i%8 == 0)	{
	    printf("\n[0x%x]\t0x%x",i,data->p_data);
	}
	else {
	    printf("\t0x%x",data->p_data);
	}
    }
    printf("\n");

    return N22XX_STAT_OK;
}

static int n22xxed_add_timer(int fd, struct n22xxed_data *data)
{
    int retval;

    data->cmd = N22XX_ADD_TIMER;
    retval = ioctl(fd,N22XX_ADD_TIMER,data,N22XX_BASE_SIOC);
	
    printf("\nTimer is added \n");

    return retval;
}

static int n22xxed_del_timer(int fd, struct n22xxed_data *data)
{
    int retval;

    data->cmd = N22XX_DEL_TIMER;
    retval = ioctl(fd,N22XX_DEL_TIMER,data,N22XX_BASE_SIOC);

    printf("\nTimer is del \n");

    return retval;
}

static int n22xxed_wdi_kick(int fd, struct n22xxed_data *data)
{
    int retval;

    data->cmd = N22XX_WDI_KICK;
    retval = ioctl(fd,N22XX_WDI_KICK,data,N22XX_BASE_SIOC);

    printf("\nWDI(GPIO7) is set \n");

    return retval;
}

static int n22xxed_relay_check(int fd, struct n22xxed_data *data)
{
    int retval;

    data->cmd = N22XX_RELAY_CHECK;
    retval = ioctl(fd,N22XX_RELAY_CHECK,data,N22XX_BASE_SIOC);

    if ((data->value == 0x01) || (data->value == 0x10))
        printf("\nPort pair A is in Bypass Mode\n");
    else if ((data->value == 0x2) || (data->value == 0x20))
        printf("\nPort pair A is in Active Mode\n");
    else if ((data->value == 0x3) || (data->value == 0x30))
        printf("\nPort pair A is in No Link Mode\n");
    else
        printf("\nPort pair A is in an unknown state\n");

    return retval;
}

static int n22xxed_wdt_read(int fd, struct n22xxed_data *data)
{
    int retval;
	
    data->value = 0x00;
	
    data->cmd = N22XX_WD_READ;
    retval = ioctl(fd,N22XX_WD_READ,data,N22XX_BASE_SIOC);

    if(data->status != N22XX_STAT_OK) {
        printf("Access error, timeout\n");
    }
    else {	   
        printf("%d : 0x%x\n",data->offset,data->value);
    }

    return retval;
}

static int n22xxed_wdt_write(int fd, struct n22xxed_data *data)
{
    int retval;
    
#if 0
    if (data->offset > 63) {		
        printf("\nAddress location 64:128 is protected.\n");
	return -1;
    }
#endif	

    data->cmd = N22XX_WD_WRITE;
    retval = ioctl(fd,N22XX_WD_WRITE,data,N22XX_BASE_SIOC);
	
    if(data->status != N22XX_STAT_OK) {
        printf("Access error, timeout\n");
    }
    else {
        printf("%d : 0x%x\n",data->offset,data->value);
    }

    return retval;
}

static int n22xxed_wdt_dump(int fd, struct n22xxed_data *data)
{
    int i;
    int retval;
	
    data->cmd = N22XX_WD_READ;
    for (i = 0; i < 128; i++) {	
        data->offset = i;
	data->value = 0x00;
	   
	retval = ioctl(fd,N22XX_WD_READ,data,N22XX_BASE_SIOC);
	   
	if (i % 8 == 0) {
	    printf("\nWDT [0x%d]",i);
	}

	printf("\t0x%x",data->value);
    }
	
    return retval;
}

static int n22xxed_dump_card_info(int fd, struct n22xxed_data *data)
{
    int  	retval;
	
    // get prescaler val
    data->cmd = N22XX_WD_READ;
    
    data->offset = TIMEOUT_SCALER_A;
    retval = ioctl(fd,N22XX_WD_READ,data,N22XX_BASE_SIOC);
    printf("\nTIMEOUT SCALER \t\t[0x%x]",data->value);
 	
    // get oem id
    data->offset = OEM_ID;
    retval = ioctl(fd,N22XX_WD_READ,data,N22XX_BASE_SIOC);
    printf("\nOEM ID\t\t\t[0x%x]",data->value);

    // vender id	
    data->offset = PRODUCT_ID;
    retval = ioctl(fd,N22XX_WD_READ,data,N22XX_BASE_SIOC);
    printf("\nPRODUCT ID\t\t[0x%x]",data->value);
	
    // hw id
    data->offset = PRODUCT_REV;
    retval = ioctl(fd,N22XX_WD_READ,data,N22XX_BASE_SIOC);
    printf("\nPRODUCT REV\t\t[0x%x]",data->value);

    // firmware id
    data->offset = FW_ID;
    retval = ioctl(fd,N22XX_WD_READ,data,N22XX_BASE_SIOC);
    printf("\nFIRMWARE ID\t\t[0x%x]",data->value);

    data->offset = DEFAULT_MODE_A;
    retval = ioctl(fd,N22XX_WD_READ,data,N22XX_BASE_SIOC);
    printf("\nDEFAULT COPPER MODE \t[0x%x]", data->value);

    data->offset = 48;
    retval = ioctl(fd,N22XX_WD_READ,data,N22XX_BASE_SIOC);
    printf("\nDEFAULT FIBER MODE \t[0x%x]",data->value);
	
    // active mode
    data->offset = 49;
    retval = ioctl(fd,N22XX_WD_READ,data,N22XX_BASE_SIOC);
    printf("\nCURRENT MODE \t\t[0x%x]", data->value);

    // check relays
    n22xxed_relay_check(fd, data);
    
    printf("\n");
 	
    return retval;
}

static int n22xxed_force_bypass(int fd, struct n22xxed_data *data)
{
    int retval;
	
    // issue force bypass cmd to the WDT
    
    data->cmd = N22XX_WD_WRITE;
    data->offset = CURRENT_MODE_A;
    data->value = 0x4;
    retval = ioctl(fd,N22XX_WD_WRITE,data,N22XX_BASE_SIOC);

    return retval;
}

static int n22xxed_force_active(int fd, struct n22xxed_data *data)
{
    int retval;
	
    // issue force active cmd to the WDT
    
    data->cmd = N22XX_WD_WRITE;
    data->offset = CURRENT_MODE_A;
    data->value = 0x2;
    retval = ioctl(fd,N22XX_WD_WRITE,data,N22XX_BASE_SIOC);

    return retval;
}

static int n22xxed_no_link_mode(int fd, struct n22xxed_data *data)
{
    int retval;
	
    // issue no link cmd 
    
    data->cmd = N22XX_WD_WRITE;
    data->offset = CURRENT_MODE_A;
    data->value = 0x5;
    retval = ioctl(fd,N22XX_WD_WRITE,data,N22XX_BASE_SIOC);

    return retval;
}

static int n22xxed_normal_mode(int fd, struct n22xxed_data *data)
{
    int retval;
	
    // issue normal cmd 
    
    data->cmd = N22XX_WD_WRITE;
    data->offset = CURRENT_MODE_A;
    data->value = 0x70;
    retval = ioctl(fd,N22XX_WD_WRITE,data,N22XX_BASE_SIOC);

    return retval;
}

static int n22xxed_set_mode0(int fd,struct n22xxed_data *data)
{	
    int retval;
	
    // switch to mode 0
    
    data->cmd = N22XX_WD_WRITE;
    data->offset = DEFAULT_MODE_A;
    data->value = 0;
    retval = ioctl(fd,N22XX_WD_WRITE,data,N22XX_BASE_SIOC);

    return retval;
}

static int n22xxed_set_mode1(int fd,struct n22xxed_data *data)
{	
    int retval;
	
    // switch to mode 1
    
    data->cmd = N22XX_WD_WRITE;
    data->offset = DEFAULT_MODE_A;
    data->value = 1;
    retval = ioctl(fd,N22XX_WD_WRITE,data,N22XX_BASE_SIOC);

    return retval;
}

static int n22xxed_set_mode2(int fd,struct n22xxed_data *data)
{	
    int retval;
	
    // switch to mode 2
    
    data->cmd = N22XX_WD_WRITE;
    data->offset = DEFAULT_MODE_A;
    data->value = 2;
    retval = ioctl(fd,N22XX_WD_WRITE,data,N22XX_BASE_SIOC);

    return retval;
}

static int n22xxed_set_mode3(int fd,struct n22xxed_data *data)
{	
    int retval;
	
    // switch to mode 3
    
    data->cmd = N22XX_WD_WRITE;
    data->offset = DEFAULT_MODE_A;
    data->value = 3;
    retval = ioctl(fd,N22XX_WD_WRITE,data,N22XX_BASE_SIOC);

    return retval;
}

static int n22xxed_set_mode4(int fd,struct n22xxed_data *data)
{	
    int retval;
	
    // switch to mode 4
    
    data->cmd = N22XX_WD_WRITE;
    data->offset = DEFAULT_MODE_A;
    data->value = 4;
    retval = ioctl(fd,N22XX_WD_WRITE,data,N22XX_BASE_SIOC);

    return retval;
}

static int n22xxed_set_mode5(int fd,struct n22xxed_data *data)
{	
    int retval;
	
    // switch to mode 5
    
    data->cmd = N22XX_WD_WRITE;
    data->offset = DEFAULT_MODE_A;
    data->value = 5;
    retval = ioctl(fd,N22XX_WD_WRITE,data,N22XX_BASE_SIOC);

    return retval;
}

static int n22xxed_set_mode6(int fd,struct n22xxed_data *data)
{	
    int retval;
	
    // switch to mode 6
    
    data->cmd = N22XX_WD_WRITE;
    data->offset = DEFAULT_MODE_A;
    data->value = 6;
    retval = ioctl(fd,N22XX_WD_WRITE,data,N22XX_BASE_SIOC);

    return retval;
}

static int n22xxed_cpld_read(int fd, struct n22xxed_data *data)
{
    int retval;
	
    data->value = 0x00;
	
    data->cmd = N22XX_CPLD_READ;
    retval = ioctl(fd,N22XX_CPLD_READ,data,N22XX_BASE_SIOC);

    if(data->status != N22XX_STAT_OK) {
        printf("Access error\n");
    }
    else {	   
        printf("%d : 0x%x\n",data->offset,data->value);
    }

    return retval;
}

static int n22xxed_cpld_write(int fd, struct n22xxed_data *data)
{
    int retval;

    if (data->offset > 63) {		
        printf("\nAddress location 64:128 is protected.\n");
	return -1;
    }
	
    data->cmd = N22XX_CPLD_WRITE;
    retval = ioctl(fd,N22XX_CPLD_WRITE,data,N22XX_BASE_SIOC);
	
    if(data->status != N22XX_STAT_OK) {
        printf("Access error\n");
    }
    else {
        printf("%d : 0x%x\n",data->offset,data->value);
    }

    return retval;
}

static int n22xxed_reg_read(int fd, struct n22xxed_data *data)
{
    int retval;
	
    data->value = 0x00;
	
    data->cmd = N22XX_REG_READ;
    retval = ioctl(fd,N22XX_REG_READ,data,N22XX_BASE_SIOC);

    if( data->status != N22XX_STAT_OK) {
	printf("\nAccess Error");
    }
	
    if (data->port == 1) {
        printf("0x%x\n",data->reg_value_a);
    }
    else {
        printf("0x%x\n",data->reg_value_b);
    }

    return 0;
}

static int n22xxed_reg_write(int fd, struct n22xxed_data *data)
{
    int retval;

    data->cmd = N22XX_REG_WRITE;
    retval = ioctl(fd,N22XX_REG_WRITE,data,N22XX_BASE_SIOC);
	
    if(data->status != N22XX_STAT_OK) {
	printf("\nAccess Error");
    }

    printf("0x%x\n",data->reg_value_a);
	
    return 0;
}

static int n22xxed_load_flash(int fd, struct n22xxed_data *data, uint16_t *buf, int len)
{
    uint16_t i, j, retval;
    uint16_t index;

    data->p_addr = 0x0;
    index  = 0x0;
 
    for(i = 0; i < len; i = i+32)
    {
        data->cmd = N22XXP_ISP_AVR_PROG_PAGE_LOAD;
        
	// load page buf
	for (j = 0; j < 32 /*PAGE_SIZE*/; j++) {
	    data->page[j] = buf[index+j]; 
        }
	// send load page command
  	retval = ioctl(fd,N22XXP_ISP_AVR_PROG_PAGE_LOAD,data,N22XX_BASE_SIOC);

        data->cmd = N22XXP_ISP_AVR_PROG_PAGE_WRITE;
	data->p_addr = index;

	// send prog page command
  	retval = ioctl(fd,N22XXP_ISP_AVR_PROG_PAGE_WRITE,data,N22XX_BASE_SIOC);

	// update index and offset
	index += 32; 		
    } 
    
    return retval;
}

static int n22xxed_verify_flash(int fd, struct n22xxed_data *data, uint16_t *buf, int len)
{
    int      i, retval;
   
    data->p_addr = 0x00; 
    data->p_data = 0x00;
    data->cmd = N22XXP_ISP_AVR_PROG_READ;
    
    for (i = 0; i < len; i++)
    {
  	retval = ioctl(fd,N22XXP_ISP_AVR_PROG_READ,data,N22XX_BASE_SIOC);
	
	if (data->p_data != buf[i]) {
             printf("%d\n", i);
             
	     return -1;
	}
	
	data->p_addr++;	
	data->p_data = 0x00;
    }  
   
    return retval;
}
#if 1
static int eeprom_readback (int fd, struct n22xxed_data *data)
{
    uint16_t eeprom_buf[64];
    int       retval, output_fd;
    int       i;
    
  char fileName[30];

    if (data->file != NULL) {
	strcpy (fileName, data->file );
    }
    else {
	strcpy (fileName, "output.bin");
    }
      printf ("\nOutput binary file : %s\n", fileName);

    if (data->mac_num >= data->max_pair_num*4 ){
	printf("invalid mac number \n");
	return -1;
    }

    for (i = 0; i < 64; i++) {
	data->p_addr = i;
	ioctl(fd,S_READ_EEPROM,data,N22XX_BASE_SIOC);

	if (i%8 == 0)	{
	    printf("\n[0x%x]\t0x%x",i,data->p_data);
	}
	else {
	    printf("\t0x%x",data->p_data);
	}
    	eeprom_buf[i] = data->p_data;
    }


      if ((output_fd = open (fileName, O_RDWR | O_CREAT, 0)) > 0) {
	write (output_fd, eeprom_buf, sizeof (uint16_t) * 64);
	close (output_fd);
      }
      else {
	printf ("Fail to create or open output file!\n");
      }


    return retval;
}
#endif

#if 1
static int fw_verify (int fd, struct n22xxed_data *data)
{
    uint16_t  buffer[4096];
    int       retval, fdin;
    int       i, len = 0;
    
    for (i = 0; i < 4096; i++) {
        buffer[i] =0x0;
    }

    if (( fdin= open(data->file, O_RDONLY)) < 0 ) {
        printf("...unable to open %s\n", data->file);
        exit(1);
    }

    printf("...Downloading image to buffer\n");
    len = read(fdin, buffer, 8192);

    data->cmd = N22XXP_ISP_AVR_SPI_MODE_INIT;
    printf("...Enter spi initialization mode\n");
    retval = ioctl(fd,N22XXP_ISP_AVR_SPI_MODE_INIT,data,N22XX_BASE_SIOC);

    data->cmd = N22XXP_ISP_AVR_SPI_PROG_EN;
    printf("...Enter spi programming mode\n");
    retval = ioctl(fd,N22XXP_ISP_AVR_SPI_PROG_EN,data,N22XX_BASE_SIOC);

    data->cmd = N22XXP_ISP_AVR_READ_SIGN;
    printf("...Identifying chip type\n");
    retval = ioctl(fd,N22XXP_ISP_AVR_READ_SIGN,data,N22XX_BASE_SIOC);
        
    if (data->signature[0] == 0x1e &&
        data->signature[1] == 0x93 &&
        data->signature[2] == 0x07)
    {
        printf("...Valid Device Signature\n");
        for (i = 0; i < 3; i++) {
            printf("0x%x ", data->signature[i]);
        }
        printf("\n");
    }
    else { 
        printf("...Unable to identify target device\n");
    }	 
    
    printf("...Verifying Flash\n");

    if (n22xxed_verify_flash(fd, data, buffer, len) == -1) {
        printf("...Update Fail!\n");
    }
    
    data->cmd = N22XXP_ISP_AVR_SPI_MODE_EXIT;
    printf("...Exit spi programming mode\n");
    retval = ioctl(fd,N22XXP_ISP_AVR_SPI_MODE_EXIT,data,N22XX_BASE_SIOC);
        
    close (fdin);

    return retval;
}
#endif




static int fw_upgrade (int fd, struct n22xxed_data *data)
{
    uint16_t  buffer[4096];
    int       retval, fdin;
    int       i, len = 0;
    
    for (i = 0; i < 4096; i++) {
        buffer[i] =0x0;
    }

    if (( fdin= open(data->file, O_RDONLY)) < 0 ) {
        printf("...unable to open %s\n", data->file);
        exit(1);
    }

    printf("...Downloading image to buffer\n");
    len = read(fdin, buffer, 8192);

    data->cmd = N22XXP_ISP_AVR_SPI_MODE_INIT;
    printf("...Enter spi initialization mode\n");
    retval = ioctl(fd,N22XXP_ISP_AVR_SPI_MODE_INIT,data,N22XX_BASE_SIOC);

    data->cmd = N22XXP_ISP_AVR_SPI_PROG_EN;
    printf("...Enter spi programming mode\n");
    retval = ioctl(fd,N22XXP_ISP_AVR_SPI_PROG_EN,data,N22XX_BASE_SIOC);

    data->cmd = N22XXP_ISP_AVR_READ_SIGN;
    printf("...Identifying chip type\n");
    retval = ioctl(fd,N22XXP_ISP_AVR_READ_SIGN,data,N22XX_BASE_SIOC);
        
    if (data->signature[0] == 0x1e &&
        data->signature[1] == 0x93 &&
        data->signature[2] == 0x07)
    {
        printf("...Valid Device Signature\n");
        for (i = 0; i < 3; i++) {
            printf("0x%x ", data->signature[i]);
        }
        printf("\n");
    }
    else { 
        printf("...Unable to identify target device\n");
    }	 

    data->cmd = N22XXP_ISP_AVR_CHIP_ERASE;
    printf("...Erasing Flash\n");
    retval = ioctl(fd,N22XXP_ISP_AVR_CHIP_ERASE,data,N22XX_BASE_SIOC);
        
    printf("...Programming Flash\n");
    n22xxed_load_flash(fd, data, buffer, len);
    
    printf("...Verifying Flash\n");

    if (n22xxed_verify_flash(fd, data, buffer, len) == -1) {
        printf("...Update Fail!\n");
    }
    
    data->cmd = N22XXP_ISP_AVR_SPI_MODE_EXIT;
    printf("...Exit spi programming mode\n");
    retval = ioctl(fd,N22XXP_ISP_AVR_SPI_MODE_EXIT,data,N22XX_BASE_SIOC);
        
    close (fdin);
#if 0    
    data->offset=0;
    data->value =15;
    retval=n22xxed_wdt_write(fd, data);
    
    data->offset=1;
    data->value =15;
    retval=n22xxed_wdt_write(fd, data);

    data->offset=50;
    data->value =0;
    retval=n22xxed_wdt_write(fd, data);
    
    data->offset=56;
    data->value =0;
    retval=n22xxed_wdt_write(fd, data);

    data->offset=65;
    data->value =38;
    retval=n22xxed_wdt_write(fd, data);

    data->offset=66;
    data->value =56;
    retval=n22xxed_wdt_write(fd, data);

    data->offset=67;
    data->value =11;
    retval=n22xxed_wdt_write(fd, data);
    
    data->offset=48;
    data->value =0x3;
    retval=n22xxed_wdt_write(fd, data);

    data->offset=54;
    data->value =0x3;
    retval=n22xxed_wdt_write(fd, data);

    data->offset=49;
    data->value =0x10;
    retval=n22xxed_wdt_write(fd, data);

    data->offset=55;
    data->value =0x10;
    retval=n22xxed_wdt_write(fd, data);
#endif

    return retval;
}

static void usage(char *name)
{
    fprintf(stderr, "\nUsage: %s [OPTION] [SUB OPTION]\n\n", name);
    fprintf(stderr, "  -a : add heart beat timer\n");	
    fprintf(stderr, "  -d : del heart beat timer\n");
    fprintf(stderr, "     : write to wdt\n");
    fprintf(stderr, "  	-w addr=<addr_in_dec>\n");	
    fprintf(stderr, "  	-w data=<data_in_dec>\n");
    fprintf(stderr, "     : read from wdt\n");
    fprintf(stderr, "  	-r addr=<addr_in_dec>\n");	
    fprintf(stderr, "  -b : dump all wdt reg\n");
    fprintf(stderr, "  -i : card information \n");
    fprintf(stderr, "  -k : kick watchdog (give pulse to wdt input)\n");	
    fprintf(stderr, "  -s : check relay status\n");
    fprintf(stderr, "  -c : force active (close the relay)\n");
    fprintf(stderr, "  -o : force bypass (open the relay)\n");	
    fprintf(stderr, "  -n : resume to normal (resume from force bypass)\n");
    fprintf(stderr, "  -0 : set default mode to mode 0\n");
    fprintf(stderr, "  -1 : set default mode to mode 1\n");
    fprintf(stderr, "  -2 : set default mode to mode 2\n");
    fprintf(stderr, "  -3 : set default mode to mode 3\n");
    fprintf(stderr, "  -m : switch between fiber and copper\n");
    fprintf(stderr, "  -e : dump eeprom\n");
    fprintf(stderr, "     : force mode\n");
    fprintf(stderr, "   -f data=<data_in_dec>\n"); 
    fprintf(stderr, "     : update local cpu firmware\n");
    fprintf(stderr, "   -L [image]\n");
}

int main(int argc, char *argv[])
{
    int 			fd, i, ch, pair;
    char 			*subopts, *value, *tail;
    struct n22xxed_data 		data; 
    int 			retval 			= 0;
    unsigned char 		command_line_parsed 	= 0;
    unsigned int 		tests 			= 0;
    uint32_t                    mac_h, subdev_id;
    uint16_t 			mac_l; 
    uint8_t                     band;

    mac_h = 0x000cbd00;
    mac_l = 0x00000;
    
    fd = open("/dev/n22xxed", O_RDWR,0);
	
    if(fd < 0) {
        printf("error\n") ;
        exit(1) ;
    }
    else {
        data.status = N22XX_STAT_OK;		
        retval = ioctl(fd, N22XX_UPDATE_MAX_PAIR_NUM, &data, N22XX_BASE_SIOC);
    }
	
    if(argc < 2) {
        usage(FILEPART(argv[0]));
        return -1;
    }

    data.pos      = 3;
    data.port     = 0;
    data.num      = 8;
    data.pair_num = 0;
 
    while((ch = getopt(argc, argv, "YadbcekoSsimnxlu0123456?H:E:M:v:8:9:r:w:R:W:I:p:L:f:")) != -1) {
        switch (ch) {

            case 'u':
                band = 55;
                data.pos = 2;

            break;

            case 'l':
                band = 49;
                data.pos = 1;

            break;

	    case 'M':
		data.mac_num = atoi(optarg);
		printf("select mac# %d\n",data.mac_num);
	    break;

	    case 'p':
		pair = atoi(optarg);
		if (pair < data.max_pair_num * 2) {
                    data.pair_num = pair;
                }
                else {
                    data.pair_num = 0;
                }
                
            break;

            case 'a':
     	        tests |= TEST_ADD_TIMER;

	    break;

	    case 'd':
	        tests |= TEST_DEL_TIMER;

	    break;

	    case 'w':
	        tests |= TEST_WDT_WRITE;		
		subopts = optarg;
		while (*subopts != '\0') {
		    switch (getsubopt(&subopts, spi_opts, &value)) {
		        case ADDR_OPTION:
		            if (value == NULL)
		                abort();
		            data.offset=strtoul(value, &tail, 0);

		        break;

		        case DATA_OPTION:
		            if (value == NULL)
		                abort();
			    data.value=strtoul(value, &tail, 0);

		        break;

		        default:
		            printf ("Unknown suboption `%s'\n", value);

		        break;
		    }
		}

	    break;

	    case 'r':
	        tests |= TEST_WDT_READ;
	        subopts = optarg;
	        while (*subopts != '\0') {
	            switch (getsubopt(&subopts, spi_opts, &value)) {
	                case ADDR_OPTION:
	                    if (value == NULL)
	                        abort();
	    		    data.offset=strtoul(value, &tail, 0);

	                break;

		        default:
		            printf ("Unknown suboption `%s'\n", value);

	                break;
		    }
                }
	    break;

	    case 'k':
	        tests |= TEST_WDI_KICK;

	    break;
		
	    case 's':
	        tests |= TEST_RELAY_CHECK;

	    break;

	    case 'b':
	        tests |= TEST_WDT_DUMP;

	    break;
	
	    case 'i':
	        tests |= TEST_CARD_INFO;

	    break;
	
	    case 'c': 
	        tests |= TEST_FORCE_ACTIVE;

	    break;

	    case 'o':
	        tests |= TEST_FORCE_BYPASS;

	    break;

	    case 'x':
	        tests |= TEST_NO_LINK_MODE;

	    break;

	    case 'n':
	        tests |= TEST_NORMAL_MODE;

	    break;

	    case '0':
	        tests |= TEST_MODE_0;
                data.pos = 0;

	    break;

	    case '1':
	        tests |= TEST_MODE_1;
                data.pos = 0;

	    break;	

	    case '2':
	        tests |= TEST_MODE_2;
                data.pos = 0;

	    break;	

	    case '3':
	        tests |= TEST_MODE_3;
                data.pos = 0;

	    break;	

	    case '4':
	        tests |= TEST_MODE_4;
                data.pos = 0;

	    break;	

	    case '5':
	        tests |= TEST_MODE_5;
                data.pos = 0;

	    break;	

	    case '6':
	        tests |= TEST_MODE_6;
                data.pos = 0;

	    break;	

	    case 'W':
	        tests |= TEST_CPLD_WRITE;		
		subopts = optarg;
		while (*subopts != '\0') {
		    switch (getsubopt(&subopts, spi_opts, &value)) {
		        case ADDR_OPTION:
		            if (value == NULL)
		                abort();
			    data.offset=strtoul(value, &tail, 0);

		        break;

		        case DATA_OPTION:
		            if (value == NULL)
		                abort();
			    data.value=strtoul(value, &tail, 0);

		        break;

		        default:
		            printf ("Unknown suboption `%s'\n", value);

		        break;
		    }
		}

	    break;

	    case 'R':
	        tests |= TEST_CPLD_READ;
	        subopts = optarg;
	        while (*subopts != '\0') {
	            switch (getsubopt(&subopts, spi_opts, &value)) {
	                case ADDR_OPTION:
	                    if (value == NULL)
	                        abort();
			    data.offset=strtoul(value, &tail, 0);

	                break;
	                
	                default:
		            printf ("Unknown suboption `%s'\n", value);

		        break;
		    }
		}
		break;

	    case 'I':
	        tests |= TEST_REG_WRITE;		
		subopts = optarg;
		while (*subopts != '\0') {
		    switch (getsubopt(&subopts, spi_opts, &value)) {
		        case DATA_OPTION:
		            if (value == NULL)
		                abort();
			    data.reg_value_a=strtoul(value, &tail, 0);

		        break;

		        default:
		            printf ("Unknown suboption `%s'\n", value);

		        break;
		    }
		}

	        break;

	    case 'Y':
	        tests |= TEST_REG_READ;

	    break;
            
            case 'm':
                tests |= TEST_SW_INTER;
            break;
            
            case 'e':
     	        tests |= TEST_EE_DUMP;

	    break;
              
            case 'L':
		strncpy(data.file, optarg, 20);
		tests |= TEST_FW_UPDATE;
            break;
      
            case 'v':
		strncpy(data.file, optarg, 20);
		tests |= TEST_FW_VERIFY;
            break;

            case 'f':
	        tests |= TEST_FORCE_MODE;		
		subopts = optarg;
		while (*subopts != '\0') {
		    switch (getsubopt(&subopts, spi_opts, &value)) {
		        case DATA_OPTION:
		            if (value == NULL)
		                abort();
			    data.value=strtoul(value, &tail, 0);

		        break;

		        default:
		            printf ("Unknown suboption `%s'\n", value);

		        break;
		    }
		}

	    break;

            case '8':
		data.mac_num =0;
		subopts = optarg;
		while (*subopts != '\0') {
		    switch (getsubopt(&subopts, spi_opts, &value)) {
		        case ADDR_OPTION:
		            if (value == NULL)
		                abort();
			    data.p_addr=strtoul(value, &tail, 0);

		        break;
		        default:
		            printf ("Unknown suboption `%s'\n", value);

		        break;
		    }
		}
		tests |= TEST_S_EERD_MODE;	
		break;

            case '9':
		data.mac_num =0;
		subopts = optarg;
		while (*subopts != '\0') {
		    switch (getsubopt(&subopts, spi_opts, &value)) {
		        case ADDR_OPTION:
		            if (value == NULL)
		                abort();
			    data.p_addr=strtoul(value, &tail, 0);

		        break;

		        case DATA_OPTION:
		            if (value == NULL)
		                abort();
			    data.p_data=strtoul(value, &tail, 0);

		        break;

		        default:
		            printf ("Unknown suboption `%s'\n", value);

		        break;
		    }
		}
		tests |= TEST_S_EEWR_MODE;	
		break;

	    case 'E':
		strncpy(data.file, optarg, 20);
		tests |= TEST_EEPROM_READBACK;
		break;
	    case 'H':
		mac_l = strtoul(optarg,&tail,0);
		new_mac=1;
		printf("mac_l = 0x%x \n",mac_l);
		break;
	    case 'S':
		printf("%d\n",data.max_pair_num);
		break;
	    case ':':
	    case '?':
	        usage(FILEPART(argv[0]));
	        return -1;
	}
	command_line_parsed = 1;
    }

    if(command_line_parsed == 0) {
        usage(FILEPART(argv[0]));
        return -1;
    }
	
    if ((data.max_pair_num != 0) && (data.pair_num < data.max_pair_num)) {
        
        if(tests & TEST_ADD_TIMER) {
    	    retval |= n22xxed_add_timer(fd,&data);
    	}

	if(tests & TEST_DEL_TIMER) {
	    retval |= n22xxed_del_timer(fd,&data);
	}

	if(tests & TEST_WDI_KICK) {
	    retval |= n22xxed_wdi_kick(fd,&data);
	}
		
	if(tests & TEST_RELAY_CHECK) {
	    retval |= n22xxed_relay_check(fd,&data);
	}
	
	if(tests & TEST_WDT_WRITE) {
	    retval |= n22xxed_wdt_write(fd,&data);
	}

	if(tests & TEST_WDT_READ) {
	    retval |= n22xxed_wdt_read(fd,&data);
	}

	if(tests & TEST_WDT_DUMP) {
	    retval |= n22xxed_wdt_dump(fd,&data);
	}

	if(tests & TEST_CARD_INFO) {
	    retval |= n22xxed_dump_card_info(fd,&data);
	}

	if(tests & TEST_FORCE_ACTIVE) {
	    retval |= n22xxed_force_active(fd,&data);
	}

        if(tests & TEST_FORCE_BYPASS) {
	    retval |= n22xxed_force_bypass(fd,&data);
	}

        if(tests & TEST_NO_LINK_MODE) {
	    retval |= n22xxed_no_link_mode(fd,&data);
	}

        if(tests & TEST_NORMAL_MODE) {
	    retval |= n22xxed_normal_mode(fd,&data);
	}

        if(tests & TEST_MODE_0) {
	    retval |= n22xxed_set_mode0(fd,&data);
	}
	
        if(tests & TEST_MODE_1)	{
	    retval |= n22xxed_set_mode1(fd,&data);
	}
	
        if(tests & TEST_MODE_2)	{
	    retval |= n22xxed_set_mode2(fd,&data);
	}

        if(tests & TEST_MODE_3)	{
	    retval |= n22xxed_set_mode3(fd,&data);
	}

        if(tests & TEST_MODE_4)	{
	    retval |= n22xxed_set_mode4(fd,&data);
	}

        if(tests & TEST_MODE_5)	{
	    retval |= n22xxed_set_mode5(fd,&data);
	}

        if(tests & TEST_MODE_6)	{
	    retval |= n22xxed_set_mode6(fd,&data);
	}

	if(tests & TEST_CPLD_WRITE) {
	    retval |= n22xxed_cpld_write(fd,&data);
	}

	if(tests & TEST_CPLD_READ) {
	    retval |= n22xxed_cpld_read(fd,&data);
	}

	if(tests & TEST_REG_WRITE) {
	    retval |= n22xxed_reg_write(fd,&data);
        }

        if(tests & TEST_REG_READ) {
	    retval |= n22xxed_reg_read(fd,&data);
        }
        
        if(tests & TEST_SW_INTER) {
//	    for (i=0;i<4;i++){
//		data.mac_num = i;
		if ( !new_mac ){
		data.p_addr=2;
		data.p_data=0;
    		ioctl(fd,S_READ_EEPROM,&data,N22XX_BASE_SIOC);
		mac_l = 0x0000FFFF & (data.p_data);
		}

            if(subdev_id == 0x105F) {
	        retval |= n22xxed_update_eeprom_mac(fd, &data, n2264_eeprom_fiber, mac_h, mac_l);
	    }
	    else if(subdev_id == 0x105E) {
	        retval |= n22xxed_update_eeprom_mac(fd, &data, n2264_eeprom_copper, mac_h, mac_l);
	    }
//	   }
        }
        
        if(tests & TEST_EE_DUMP) {
	    for (i=0;i<4;i++){
	    data.mac_num=i;
	    retval |= n22xxed_eeprom_dump(fd, &data);
	    }
        }
        
        if(tests & TEST_FW_UPDATE) {
            retval |= fw_upgrade (fd, &data);
	}
	
        if(tests & TEST_FW_VERIFY) {
            retval |= fw_verify (fd, &data);
	}

	if(tests & TEST_FORCE_MODE) {
            data.offset=band;
	    retval |= n22xxed_wdt_write(fd,&data);
        }
        
	if (tests & TEST_S_EERD_MODE){
    		retval = 
		ioctl(fd,S_READ_EEPROM,&data,N22XX_BASE_SIOC);
		printf("[0x%x] [0x%x]\n",data.p_addr,data.p_data);
	}

	if (tests & TEST_S_EEWR_MODE){
    		retval = 
		ioctl(fd,S_WRITE_EEPROM,&data,N22XX_BASE_SIOC);
		printf("[0x%x] [0x%x]\n",data.p_addr,data.p_data);
	}
	if ( tests & TEST_EEPROM_READBACK){
		eeprom_readback (fd,&data);
	}
    }
    else {
        printf ("HW is NOT found\n");
    }
    
    close(fd);

    return retval;
}
	
