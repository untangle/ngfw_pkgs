#include <linux/fs.h>
#include <linux/types.h>
#include <linux/init.h>
#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/time.h>
#include <asm/uaccess.h>

//#include "nic_hw.h"
#include "n22xxed_hw.h"
#include "n22xxed_cmd.h"
#include "n22xxed_data.h"
#include "avrIspCmdDef.h"

#define vendor				0
#define	dev				1
#define subvendor			2
#define	subdevice			3

#define RLY_STA_ADDR			47
#define RLY_STA_ADDR_B			53
#define FW_ID				68
#define CPLD_CPU_HBT			0x01
#define AVR_ADR_REG     		0x00
#define AVR_MAC_REG 			0x01
#define AVR_DAT_REG     		0x02
#define MAC_DAT_REG     		0x03
#define ETH_POS_REG     		0x34
#define ETH_POSN_REG                    0x34
#define MAC_CMD_D               	0x10
#define	WDI		        	0x20
#define AVR_RD_WR               	0x40
#define AVR_CMD_P               	0x80

#define SW_RST_EN	                0x04
#define SW_RSTN		                0x01
#define CPLD_CPU_SPI	                0x06
#define CPLD_RST_CTRL	                0x05
#define SPI_CLK		                0x10
#define SPI_MISO	                0x80
#define SPI_MOSI	                0x20

#define OP_REQ                          0x08
#define OP_DIR                          0x04
#define L_NBLE                          0x01
#define H_NBLE                          0x02
#define DIR_WR                          0x04

#define BIT3 				0x8
#define BIT2 				0x4
#define BIT1 				0x2
#define BIT0 				0x1

#define AVR_ADDR                        0x0
#define AVR_DAT                         0x1
#define HOST_DAT                        0x2
#define STAT                            0x3
#define CTL_0                           0x4
#define CTL_1                           0x5
#define I2C_R                           0x6
#define CSR                             0x7
#define SPI_CTL                         0x8
#define ID_R                            0x9

#define BSL_0                           0x0
#define BSL_1                           0x1
#define BSL_2                           0x2
#define BSL_3                           0x3

#define LOCKED                          0x1
#define UNLOCKED                        0x0
#define MAX_NUM                         0x2
#define lockN22xx() 			\
if (down_interruptible(&n22xxed_sema)) {	\
    return -ERESTARTSYS;		\
}

#define unlockN22xx() 			\
    up(&n22xxed_sema);

#define N22XX_MAJOR			0

#define FW_UPDATE		        0
#define debug 				1
#define	K26				1

typedef enum
{
  atmega8,
  unknown
}
ic_type;

int n22xxed_major = N22XX_MAJOR;
int porta_num = 0;
int portb_num = 0;
int nic_num = 0;
int num_of_n22xxed = 0;
int num_of_n22xxedd = 0;

static struct n22xxed_hd *n22xxed_add;
static uint8_t **nic_addr;

static struct semaphore n22xxed_sema;

volatile atomic_t wait;
#define WAIT_A 0
#define WAIT_B 1
#define WAIT_C 2

//volatile static int heartbeat           = 0;

//MODULE_PARM(debug, "i");
//#define N_DEBUG(fmt, args) do { if(debug!=0) printk(fmt, ##args); } while(0);

int n22xxed_open (struct inode *inode, struct file *filp);
int n22xxed_release (struct inode *inode, struct file *filp);
int n22xxed_ioctl (struct inode *inode, struct file *filp, unsigned int cmd,
		 unsigned long arg);

static enum n22xxed_stat n22xxed_del_timer (struct n22xxed_hd *hw, uint8_t pos);
static enum n22xxed_stat n22xxed_add_timer (struct n22xxed_hd *hw, uint8_t pos);
static enum n22xxed_stat n22xxed_wd_read (struct n22xxed_hd *hw, uint8_t offset,
				      uint8_t * value);
static enum n22xxed_stat n22xxed_wd_write (struct n22xxed_hd *hw, uint8_t offset,
				       uint8_t value);
static boolean_t n22xxed_relay_check (struct n22xxed_hd *hw, uint8_t *val);
static enum n22xxed_stat n22xxed_wdi_kick (struct n22xxed_hd *hw, uint8_t pos);
uint8_t SPI_RX (uint8_t * hw);
void SPI_TX (uint8_t * hw, uint8_t value);
void porta_io_init (struct n22xxed_hd *hw);
void portb_io_init (struct n22xxed_hd *hw);
static enum n22xxed_stat n22xxed_cpld_write (uint8_t * hw_a, uint8_t * hw_b,
					 uint8_t addr, uint8_t data,
					 uint8_t num);
static enum n22xxed_stat n22xxed_cpld_read (uint8_t * hw_a, uint8_t * hw_b,
					uint8_t addr, uint8_t * value,
					uint8_t num);
static enum n22xxed_stat n22xxed_tx_two (uint8_t * hw_a, uint8_t * hw_b,
				     uint8_t addr, uint8_t bsl, uint8_t dat);
static enum n22xxed_stat n22xxed_rx_two (uint8_t * hw_a, uint8_t * hw_b,
				     uint8_t addr, uint8_t bsl,
				     uint8_t * val);

static struct file_operations n22xxed_fops = {
  .owner = THIS_MODULE,
  .llseek = NULL,
  .read = NULL,
  .write = NULL,
  .ioctl = n22xxed_ioctl,
  .open = n22xxed_open,
  .release = n22xxed_release,
};

void
s_spi_rx (uint8_t * nic_base, uint16_t * data, int cnt)
{
  uint16_t s_data = 0, i;
  uint32_t eecd = 0;
  uint8_t *eecd_addr = (uint8_t *) (nic_base + N22XX_EECD);
  uint16_t mask = 0xFFFE;

  eecd = readl (eecd_addr);

  for (i = 0; i < cnt; i++) {

    eecd |= N22XX_EECD_SK;

    writel (eecd, eecd_addr);
    usec_delay (1);		//setup

    if (readl (eecd_addr) & N22XX_EECD_DO)
      s_data |= 0x01;
    else
      s_data &= mask;

    eecd &= ~N22XX_EECD_SK;
    writel (eecd, eecd_addr);
    usec_delay (1);		//hold
    if (i < 15)
      s_data = s_data << 1;
  }
  *data = s_data;
}

void
s_spi_tx (uint8_t * nic_base, uint16_t data, int cnt)
{
  uint16_t s_data, i;
  uint32_t eecd = 0;
  uint8_t *eecd_addr = (uint8_t *) (nic_base + N22XX_EECD);
  uint16_t mask = (0x1 << (cnt - 1));

  eecd = readl (eecd_addr);

  s_data = data;
  for (i = 0; i < cnt; i++) {
    if ((s_data & mask) == mask)
      eecd |= N22XX_EECD_DI;
    else
      eecd &= ~N22XX_EECD_DI;

    writel (eecd, eecd_addr);

    usec_delay (1);		//setup
    eecd |= N22XX_EECD_SK;
    writel (eecd, eecd_addr);

    usec_delay (1);		//hold
    eecd &= ~N22XX_EECD_SK;

    writel (eecd, eecd_addr);

    s_data = s_data << 1;
  }
}

void
s_spi_cs_en (uint8_t * nic_base)
{
  uint32_t eecd = 0;
  uint8_t *eecd_addr = (uint8_t *) (nic_base + N22XX_EECD);

  eecd = readl (eecd_addr);
  eecd &= ~N22XX_EECD_CS;
  writel (eecd, eecd_addr);
}

void
s_spi_cs_disable (uint8_t * nic_base)
{
  uint32_t eecd = 0;
  uint8_t *eecd_addr = (uint8_t *) (nic_base + N22XX_EECD);

  eecd = readl (eecd_addr);
  eecd |= N22XX_EECD_CS;
  writel (eecd, eecd_addr);
}

static int
s_read_eeprom (uint8_t * nic_base, uint16_t addr, uint16_t * data)
{
  uint16_t s_addr = addr, s_data = 0;
  uint32_t i = 0, eecd = 0;
  uint8_t *eecd_addr = (uint8_t *) (nic_base + N22XX_EECD);

  eecd = readl (eecd_addr) | N22XX_EECD_REQ;
  writel (eecd, eecd_addr);
  eecd = readl (eecd_addr);

  for (i = 0; i < 2048; i++) {
    usec_delay (1);
    eecd = readl (eecd_addr);
    if ((eecd & N22XX_EECD_GNT) == N22XX_EECD_GNT)
      break;
  }

  s_spi_cs_en (nic_base);
  s_spi_tx (nic_base, S_READ, 8);	// send 8 bit inst
  s_spi_tx (nic_base, s_addr * 2, 16);	// send 16 bit addr
  s_spi_rx (nic_base, &s_data, 16);	// send 8 bit inst
  s_spi_cs_disable (nic_base);

  eecd &= ~(N22XX_EECD_GNT | N22XX_EECD_REQ);
  writel (eecd, eecd_addr);

  *data = (s_data >> 8 & 0x00FF) | (s_data << 8 & 0xFF00);
  usec_delay (1);
  return N22XX_STAT_OK;
}

static int
s_write_eeprom (uint8_t * nic_base, uint16_t addr, uint16_t data)
{
  uint32_t eecd, i, s_addr = addr, s_data;
  uint8_t *eecd_addr;

  eecd_addr = (uint8_t *) (nic_base + N22XX_EECD);	//(hw->hw_addr+N22XX_EECD);

  s_data = (data >> 8 & 0x00FF) | (data << 8 & 0xFF00);

  eecd = readl (eecd_addr) | N22XX_EECD_REQ;
  writel (eecd, eecd_addr);
  eecd = readl (eecd_addr);

  for (i = 0; i < 2048; i++) {
    usec_delay (1);
    eecd = readl (eecd_addr);
    if ((eecd & N22XX_EECD_GNT) == N22XX_EECD_GNT)
      break;
  }

  s_spi_cs_en (nic_base);
  s_spi_tx (nic_base, WREN, 8);
  s_spi_cs_disable (nic_base);
  usec_delay (1);

  s_spi_cs_en (nic_base);
  s_spi_tx (nic_base, S_WRITE, 8);	// send 8 bit inst
  s_spi_tx (nic_base, s_addr * 2, 16);	// send 16 bit addr
  s_spi_tx (nic_base, s_data, 16);	// send 8 bit inst
  s_spi_cs_disable (nic_base);

  usec_delay (1);
  s_spi_cs_en (nic_base);
  s_spi_tx (nic_base, WRDI, 8);
  s_spi_cs_disable (nic_base);

  msec_delay (5);		// at least tccs = 5ms

  eecd &= ~(N22XX_EECD_GNT | N22XX_EECD_REQ);
  writel (eecd, eecd_addr);

  return N22XX_STAT_OK;
}

static void
n22xxed_bypass_t (struct n22xxed_hd *hw)
{
  set_bit(WAIT_A, (volatile void *)&wait);

  // when we are the only one using the resource, send heartbeat
  if (atomic_read(&wait) == (0x1 << WAIT_A)){
    porta_io_init (hw);
    portb_io_init (hw);
    n22xxed_tx_two (hw->hw_a, hw->hw_b, CSR, BSL_2, hw->heartbeat);
  }
  // when we are not the only one using the resource, skip heartbeat
  clear_bit(WAIT_A, (volatile void*)&wait);

  // reset the timer 250 ms 
  mod_timer (&hw->im_bypass_timer, jiffies + 1 * HZ);
}

void
porta_io_init (struct n22xxed_hd *hw)
{
  uint32_t ctrl_ext, ctrl;

  // set i/o direction porta

  ctrl_ext = N22XX_READ_REG (hw->hw_a, CTRL_EXT);
  ctrl = N22XX_READ_REG (hw->hw_a, CTRL);

  ctrl |= IM_D3_DIR;		// set D3 as output
  ctrl_ext |= IM_D4_DIR;	// set D4 as output
  ctrl_ext |= IM_DS_DIR;	// set DS as output

  ctrl &= ~IM_D3_DATA;		// clr D3 pin
  ctrl_ext &= ~IM_D4_DATA;	// clr D4 pin
  ctrl_ext &= ~IM_DS_DATA;	// clr DS pin

  N22XX_WRITE_REG (hw->hw_a, CTRL, ctrl);
  N22XX_WRITE_REG (hw->hw_a, CTRL_EXT, ctrl_ext);
}

void
portb_io_init (struct n22xxed_hd *hw)
{
  uint32_t ctrl_ext, ctrl;

  ctrl_ext = N22XX_READ_REG (hw->hw_b, CTRL_EXT);
  ctrl = N22XX_READ_REG (hw->hw_b, CTRL);

  ctrl |= IM_D0_DIR;		// set D0 as output
  ctrl_ext &= ~IM_D1_DIR;	// set D1 as input
  ctrl_ext &= ~IM_D2_DIR;	// set D2 as input
  ctrl &= ~IM_D0_DATA;		// clr D0 pin

  N22XX_WRITE_REG (hw->hw_b, CTRL_EXT, ctrl_ext);
  N22XX_WRITE_REG (hw->hw_b, CTRL, ctrl);
}

static enum spi_stat
CPLD_POLL_CMD_DONE (struct n22xxed_hd *hw)
{
  struct timeval tv;
  time_t start_time, current_time;
  uint8_t stat;

  do_gettimeofday (&tv);
  start_time = tv.tv_sec;

  n22xxed_rx_two (hw->hw_a, hw->hw_b, CSR, BSL_1, &stat);

  while (stat & 0x02) {
    n22xxed_rx_two (hw->hw_a, hw->hw_b, CSR, BSL_1, &stat);

    do_gettimeofday (&tv);
    current_time = tv.tv_sec;

    if (current_time >= start_time) {
    if ((current_time - start_time) > 1)
      return SPI_STAT_TIMEOUT;
    }
    else {
      if (((start_time - current_time) & 0xFF) < 0xFF)
        return SPI_STAT_TIMEOUT;
    }
    
  }

  return SPI_STAT_OK;
}

void
SPI_TX (uint8_t * hw, uint8_t value)
{
  uint32_t ctrl_ext, ctrl;
  int i;
  uint8_t tx_data;

  tx_data = value;

  ctrl_ext = N22XX_READ_REG (hw, CTRL_EXT);
  ctrl = N22XX_READ_REG (hw, CTRL);

  // tx 8 bit data
  for (i = 0; i < 8; i++) {

    // generate rising edge on clk
    ctrl |= IM_SPI_CLK_DATA;
    if (tx_data & 0x80) {
      ctrl_ext |= IM_SPI_MOSI_DATA;
    }
    else {
      ctrl_ext &= ~IM_SPI_MOSI_DATA;
    }

    // tx data
    N22XX_WRITE_REG (hw, CTRL_EXT, ctrl_ext);
    N22XX_WRITE_REG (hw, CTRL, ctrl);

    // wait for 20u sec
    usec_delay (100);

    // generate fall edge on clk
    ctrl &= ~IM_SPI_CLK_DATA;
    N22XX_WRITE_REG (hw, CTRL, ctrl);
    tx_data = tx_data << 1;

    // wait for 20u sec
    usec_delay (100);
  }
}

uint8_t
SPI_RX (uint8_t * hw)
{
  uint32_t ctrl_ext, ctrl;
  int i;
  uint8_t rx_data = 0x00;

  ctrl_ext = N22XX_READ_REG (hw, CTRL_EXT);
  ctrl = N22XX_READ_REG (hw, CTRL);

  // rx 8 bit data
  for (i = 0; i < 8; i++) {

    // generate rising edge on clk
    ctrl |= IM_SPI_CLK_DATA;
    N22XX_WRITE_REG (hw, CTRL, ctrl);

    // wait
    usec_delay (100);

    // generate falling edge on clk and sample data 
    ctrl &= ~IM_SPI_CLK_DATA;
    N22XX_WRITE_REG (hw, CTRL, ctrl);

    // sample 1 bit
    if (N22XX_READ_REG (hw, CTRL) & IM_SPI_MISO_DATA) {
      rx_data |= 0x01;
    }
    else {
      rx_data &= 0xFE;
    }

    if (i < 7) {
      rx_data = rx_data << 1;
    }

    // wait
    usec_delay (100);
  }

  return rx_data;
}

static enum n22xxed_stat
n22xxed_wdi_kick (struct n22xxed_hd *hw, uint8_t pos)
{
    if (pos == 0x1) {
      n22xxed_tx_two (hw->hw_a, hw->hw_b, CSR, BSL_2, 0x1);
    }
    else if (pos == 0x2) {
      n22xxed_tx_two (hw->hw_a, hw->hw_b, CSR, BSL_2, 0x2);
    }
    else {
      n22xxed_tx_two (hw->hw_a, hw->hw_b, CSR, BSL_2, 0x3);
    }

    return N22XX_STAT_OK;
}

static boolean_t
n22xxed_relay_check (struct n22xxed_hd *hw, uint8_t * val)
{
    n22xxed_wd_read (hw, RLY_STA_ADDR, val);

/*
    if (pos == 0x2) {
      n22xxed_wd_read (hw, RLY_STA_ADDR_B, &val);
    }
*/

//    return val == 0x2;
    return N22XX_STAT_OK;
}

static enum n22xxed_stat
n22xxed_reg_read (uint8_t * hw_a, uint8_t * hw_b, uint32_t * value_a,
		uint32_t * value_b, uint8_t pos, uint8_t port)
{
  if (pos == 1) {
    if (port == 1) {
      printk (KERN_INFO "read CTRL porta\n");
      *value_a = N22XX_READ_REG (hw_a, CTRL);
    }
    else {
      printk (KERN_INFO "read CTRL portb\n");
      *value_b = N22XX_READ_REG (hw_b, CTRL);
    }
  }
  else {
    if (port == 1) {
      printk (KERN_INFO "read CTRL_EXT porta\n");
      *value_a = N22XX_READ_REG (hw_a, CTRL_EXT);
    }
    else {
      printk (KERN_INFO "read CTRL_EXT portb\n");
      *value_b = N22XX_READ_REG (hw_b, CTRL_EXT);
    }
  }

  return N22XX_STAT_OK;
}

static enum n22xxed_stat
n22xxed_reg_write (uint8_t * hw_a, uint8_t * hw_b, uint32_t value, uint8_t pos,
		 uint8_t port)
{
  uint32_t ctrla, ctrlb;
  uint32_t ctrl_exta, ctrl_extb;

  ctrla = ctrlb = 0;
  ctrl_exta = ctrl_extb = 0;

  if (pos == 1) {
    if (port == 1) {
      ctrla = N22XX_READ_REG (hw_a, CTRL);
      N22XX_WRITE_REG (hw_a, CTRL, value);
    }
    else {
      ctrlb = N22XX_READ_REG (hw_b, CTRL);
      N22XX_WRITE_REG (hw_b, CTRL, value);
    }
  }
  else {
    if (port == 1) {
      ctrl_exta = N22XX_READ_REG (hw_a, CTRL_EXT);
      N22XX_WRITE_REG (hw_a, CTRL_EXT, value);
    }
    else {
      ctrl_extb = N22XX_READ_REG (hw_b, CTRL_EXT);
      N22XX_WRITE_REG (hw_b, CTRL_EXT, value);
    }
  }

  return N22XX_STAT_OK;
}

static enum n22xxed_stat
n22xxed_tx_two (uint8_t * hw_a, uint8_t * hw_b, uint8_t addr, uint8_t bsl,
	      uint8_t dat)
{
  uint32_t ctrla, ctrl_exta;
  uint32_t ctrlb;

  ctrla = N22XX_READ_REG (hw_a, CTRL);
  ctrl_exta = N22XX_READ_REG (hw_a, CTRL_EXT);

  ctrlb = N22XX_READ_REG (hw_b, CTRL);

  ctrla |= IM_D3_DATA;
  ctrlb |= IM_D0_DATA;

  N22XX_WRITE_REG (hw_a, CTRL, ctrla);
  ctrla = N22XX_READ_REG (hw_a, CTRL );//flush
  N22XX_WRITE_REG (hw_b, CTRL, ctrlb);
  ctrlb = N22XX_READ_REG (hw_b, CTRL );//flush

  udelay (1);
  if (addr & BIT3) {
    ctrl_exta |= IM_DS_DATA;
  }
  else {
    ctrl_exta &= ~IM_DS_DATA;
  }
  if (addr & BIT2) {
    ctrl_exta |= IM_D4_DATA;
  }
  else {
    ctrl_exta &= ~IM_D4_DATA;
  }

  udelay (1);
  N22XX_WRITE_REG (hw_a, CTRL_EXT, ctrl_exta);
  ctrl_exta = N22XX_READ_REG (hw_a, CTRL_EXT );//flush

  ctrla &= ~IM_D3_DATA;
  ctrlb &= ~IM_D0_DATA;
  N22XX_WRITE_REG (hw_a, CTRL, ctrla);
  ctrla = N22XX_READ_REG (hw_a, CTRL);//flush
  N22XX_WRITE_REG (hw_b, CTRL, ctrlb);
  ctrlb = N22XX_READ_REG (hw_b, CTRL);//flush

  if (addr & BIT1) {
    ctrl_exta |= IM_DS_DATA;
  }
  else {
    ctrl_exta &= ~IM_DS_DATA;
  }
  if (addr & BIT0) {
    ctrl_exta |= IM_D4_DATA;
  }
  else {
    ctrl_exta &= ~IM_D4_DATA;
  }
  N22XX_WRITE_REG (hw_a, CTRL_EXT, ctrl_exta);
  ctrl_exta = N22XX_READ_REG (hw_a, CTRL_EXT );//flush

  udelay (1);
  ctrla |= IM_D3_DATA;
  N22XX_WRITE_REG (hw_a, CTRL, ctrla);
  ctrla = N22XX_READ_REG (hw_a, CTRL);//flush

  udelay (1);
  if (bsl & BIT1) {
    ctrl_exta |= IM_DS_DATA;
  }
  else {
    ctrl_exta &= ~IM_DS_DATA;
  }
  if (bsl & BIT0) {
    ctrl_exta |= IM_D4_DATA;
  }
  else {
    ctrl_exta &= ~IM_D4_DATA;
  }
  N22XX_WRITE_REG (hw_a, CTRL_EXT, ctrl_exta);
  ctrl_exta = N22XX_READ_REG (hw_a, CTRL_EXT);	//flush

  udelay (1);
  ctrla &= ~IM_D3_DATA;
  N22XX_WRITE_REG (hw_a, CTRL, ctrla);
  ctrla = N22XX_READ_REG (hw_a, CTRL );	//flush

  udelay (1);
  if (dat & BIT1) {
    ctrl_exta |= IM_DS_DATA;
  }
  else {
    ctrl_exta &= ~IM_DS_DATA;
  }
  if (dat & BIT0) {
    ctrl_exta |= IM_D4_DATA;
  }
  else {
    ctrl_exta &= ~IM_D4_DATA;
  }
  N22XX_WRITE_REG (hw_a, CTRL_EXT, ctrl_exta);
  ctrl_exta = N22XX_READ_REG (hw_a, CTRL_EXT );//flush

  udelay (1);
  ctrlb |= IM_D0_DATA;
  N22XX_WRITE_REG (hw_b, CTRL, ctrlb);
  ctrlb = N22XX_READ_REG (hw_b, CTRL);	//flush

  udelay (1);
  ctrlb &= ~IM_D0_DATA;
  N22XX_WRITE_REG (hw_b, CTRL, ctrlb);
  ctrlb = N22XX_READ_REG (hw_b, CTRL);//flush

  return N22XX_STAT_OK;
}

static enum n22xxed_stat
n22xxed_rx_two (uint8_t * hw_a, uint8_t * hw_b, uint8_t addr, uint8_t bsl,
	      uint8_t * val)
{
  uint32_t ctrla, ctrl_exta;
  uint32_t ctrlb, ctrl_extb;

  ctrla = N22XX_READ_REG (hw_a, CTRL);
  ctrl_exta = N22XX_READ_REG (hw_a, CTRL_EXT);

  ctrlb = N22XX_READ_REG (hw_b, CTRL);
  ctrl_extb = N22XX_READ_REG (hw_b, CTRL_EXT);

  ctrla |= IM_D3_DATA;
  ctrlb |= IM_D0_DATA;

  N22XX_WRITE_REG (hw_a, CTRL, ctrla);
  ctrla =  N22XX_READ_REG (hw_a, CTRL);//flush
  N22XX_WRITE_REG (hw_b, CTRL, ctrlb);
  ctrlb = N22XX_READ_REG (hw_b, CTRL);//flush

  udelay (1);
  if (addr & BIT3) {
    ctrl_exta |= IM_DS_DATA;
  }
  else {
    ctrl_exta &= ~IM_DS_DATA;
  }
  if (addr & BIT2) {
    ctrl_exta |= IM_D4_DATA;
  }
  else {
    ctrl_exta &= ~IM_D4_DATA;
  }
  N22XX_WRITE_REG (hw_a, CTRL_EXT, ctrl_exta);
  ctrl_exta = N22XX_READ_REG (hw_a, CTRL_EXT);//flush

  udelay (1);

  ctrla &= ~IM_D3_DATA;
  ctrlb &= ~IM_D0_DATA;
  N22XX_WRITE_REG (hw_a, CTRL, ctrla);
  ctrla = N22XX_READ_REG (hw_a, CTRL);//flush
  N22XX_WRITE_REG (hw_b, CTRL, ctrlb);
  ctrlb = N22XX_READ_REG (hw_b, CTRL);//flush

  udelay (1);
  if (addr & BIT1) {
    ctrl_exta |= IM_DS_DATA;
  }
  else {
    ctrl_exta &= ~IM_DS_DATA;
  }
  if (addr & BIT0) {
    ctrl_exta |= IM_D4_DATA;
  }
  else {
    ctrl_exta &= ~IM_D4_DATA;
  }
  N22XX_WRITE_REG (hw_a, CTRL_EXT, ctrl_exta);
  ctrl_exta = N22XX_READ_REG (hw_a, CTRL_EXT);//flush

  udelay (1);
  ctrla |= IM_D3_DATA;
  N22XX_WRITE_REG (hw_a, CTRL, ctrla);
  ctrla = N22XX_READ_REG (hw_a, CTRL);//flush

  udelay (1);
  if (bsl & BIT1) {
    ctrl_exta |= IM_DS_DATA;
  }
  else {
    ctrl_exta &= ~IM_DS_DATA;
  }
  if (bsl & BIT0) {
    ctrl_exta |= IM_D4_DATA;
  }
  else {
    ctrl_exta &= ~IM_D4_DATA;
  }
  N22XX_WRITE_REG (hw_a, CTRL_EXT, ctrl_exta);
  ctrl_exta = N22XX_READ_REG (hw_a, CTRL_EXT);//flush

  udelay (1);
  ctrla &= ~IM_D3_DATA;
  N22XX_WRITE_REG (hw_a, CTRL, ctrla);
  ctrla  = N22XX_READ_REG (hw_a, CTRL);//flush

  udelay (1);
  ctrl_extb = N22XX_READ_REG (hw_b, CTRL_EXT);
  if (ctrl_extb & IM_D2_DATA) {
    *val |= BIT1;
  }
  else {
    *val &= ~BIT1;
  }
  if (ctrl_extb & IM_D1_DATA) {
    *val |= BIT0;
  }
  else {
    *val &= ~BIT0;
  }

  return N22XX_STAT_OK;
}

static enum n22xxed_stat
n22xxed_cpld_write (uint8_t * hw_a, uint8_t * hw_b, uint8_t addr, uint8_t data,
		  uint8_t num)
{
  if (num == 2) {
    n22xxed_tx_two (hw_a, hw_b, addr, BSL_0, data);
  }
  else {
    n22xxed_tx_two (hw_a, hw_b, addr, BSL_0, data);
    n22xxed_tx_two (hw_a, hw_b, addr, BSL_1, data >> 2);
    n22xxed_tx_two (hw_a, hw_b, addr, BSL_2, data >> 4);
    n22xxed_tx_two (hw_a, hw_b, addr, BSL_3, data >> 6);
  }

  return N22XX_STAT_OK;
}

static enum n22xxed_stat
n22xxed_cpld_read (uint8_t * hw_a, uint8_t * hw_b, uint8_t addr,
		 uint8_t * value, uint8_t num)
{
  uint8_t tmp;

  tmp = 0;

  if (num != 2) {
    n22xxed_rx_two (hw_a, hw_b, addr, BSL_3, value);
    tmp = (tmp | (*value & 0x3)) << 2;
    n22xxed_rx_two (hw_a, hw_b, addr, BSL_2, value);
    tmp = (tmp | (*value & 0x3)) << 2;
    n22xxed_rx_two (hw_a, hw_b, addr, BSL_1, value);
    tmp = (tmp | (*value & 0x3)) << 2;
  }

  n22xxed_rx_two (hw_a, hw_b, addr, BSL_0, value);
  tmp = (tmp | (*value & 0x3));

  *value = tmp;
  return N22XX_STAT_OK;
}

static enum n22xxed_stat
n22xxed_wd_write (struct n22xxed_hd *hw, uint8_t offset, uint8_t value)
{
    set_bit(WAIT_B, (volatile void *)&wait);

    // poll until we are the only routine using the resource
    while (atomic_read(&wait) != (0x1 << WAIT_B));

    porta_io_init (hw);
    portb_io_init (hw);

    n22xxed_tx_two (hw->hw_a, hw->hw_b, AVR_ADDR, BSL_0, offset);
    n22xxed_tx_two (hw->hw_a, hw->hw_b, AVR_ADDR, BSL_1, offset >> 2);
    n22xxed_tx_two (hw->hw_a, hw->hw_b, AVR_ADDR, BSL_2, offset >> 4);
    n22xxed_tx_two (hw->hw_a, hw->hw_b, AVR_ADDR, BSL_3, offset >> 6);

    n22xxed_tx_two (hw->hw_a, hw->hw_b, AVR_DAT, BSL_0, value);
    n22xxed_tx_two (hw->hw_a, hw->hw_b, AVR_DAT, BSL_1, value >> 2);
    n22xxed_tx_two (hw->hw_a, hw->hw_b, AVR_DAT, BSL_2, value >> 4);
    n22xxed_tx_two (hw->hw_a, hw->hw_b, AVR_DAT, BSL_3, value >> 6);

    n22xxed_tx_two (hw->hw_a, hw->hw_b, CSR, BSL_0, 0x2);
    n22xxed_tx_two (hw->hw_a, hw->hw_b, CSR, BSL_1, 0x3);

    if (CPLD_POLL_CMD_DONE (hw) == SPI_STAT_TIMEOUT) {
      clear_bit(WAIT_B, (volatile void *)&wait);
      return N22XX_STAT_TEST_FAILED;	// poll until slave tell us
      // it clear the cmd_done flag
      // so we can issue a next command
    }

  clear_bit(WAIT_B, (volatile void *)&wait);
  return N22XX_STAT_OK;
}

static enum n22xxed_stat
n22xxed_wd_read (struct n22xxed_hd *hw, uint8_t offset, uint8_t * value)
{
    uint8_t tmp = 0;

    set_bit(WAIT_C, (volatile void *)&wait);

    // poll until we are the only routine using the resource
    while (atomic_read(&wait) != (0x1 << WAIT_C));

    if (hw->heartbeat) {
        n22xxed_tx_two (hw->hw_a, hw->hw_b, CSR, BSL_2, hw->heartbeat);
    }

    porta_io_init (hw);
    portb_io_init (hw);

    n22xxed_tx_two (hw->hw_a, hw->hw_b, AVR_ADDR, BSL_0, offset);
    n22xxed_tx_two (hw->hw_a, hw->hw_b, AVR_ADDR, BSL_1, offset >> 2);
    n22xxed_tx_two (hw->hw_a, hw->hw_b, AVR_ADDR, BSL_2, offset >> 4);
    n22xxed_tx_two (hw->hw_a, hw->hw_b, AVR_ADDR, BSL_3, offset >> 6);

    n22xxed_tx_two (hw->hw_a, hw->hw_b, CSR, BSL_0, 0x2);
    n22xxed_tx_two (hw->hw_a, hw->hw_b, CSR, BSL_1, 0x2);

    if (CPLD_POLL_CMD_DONE (hw) == SPI_STAT_TIMEOUT) {
      clear_bit(WAIT_C, (volatile void *)&wait);
      return N22XX_STAT_TEST_FAILED;	// poll until slave tell us
      // it clear the cmd_done flag
      // so we can issue a next command
    }

    n22xxed_rx_two (hw->hw_a, hw->hw_b, HOST_DAT, BSL_3, value);
    tmp = (tmp | (*value & 0x3)) << 2;
    n22xxed_rx_two (hw->hw_a, hw->hw_b, HOST_DAT, BSL_2, value);
    tmp = (tmp | (*value & 0x3)) << 2;
    n22xxed_rx_two (hw->hw_a, hw->hw_b, HOST_DAT, BSL_1, value);
    tmp = (tmp | (*value & 0x3)) << 2;
    n22xxed_rx_two (hw->hw_a, hw->hw_b, HOST_DAT, BSL_0, value);
    tmp = (tmp | (*value & 0x3));

    *value = tmp;
    clear_bit(WAIT_C, (volatile void *)&wait);

  return N22XX_STAT_OK;
}

static enum n22xxed_stat
n22xxed_add_timer (struct n22xxed_hd *hw, uint8_t pos)
{
  porta_io_init (hw);
  portb_io_init (hw);

  if ((pos & 0x1) == 0x1) {
    if (hw->timer_set == FALSE) {
      hw->timer_set = TRUE;
      init_timer (&hw->im_bypass_timer);
      hw->heartbeat |= 0x1;
      hw->im_bypass_timer.function = (void *) &n22xxed_bypass_t;
      hw->im_bypass_timer.data = (unsigned long) hw;
      mod_timer (&hw->im_bypass_timer, jiffies);
    }
  }

  return N22XX_STAT_OK;
}

static enum n22xxed_stat
n22xxed_del_timer (struct n22xxed_hd *hw, uint8_t pos)
{
    if ((pos & 0x1) == 0x1){
        if (hw->timer_set) {
            hw->heartbeat &= ~0x1;
        }
        hw->timer_set = FALSE;
        del_timer_sync (&hw->im_bypass_timer);
    }

  return N22XX_STAT_OK;
}
#if 0
static enum n22xxed_stat
n22xxed_force_bypass (struct n22xxed_hd *hw, uint8_t pos)
{
  // issue force bypass cmd to the WDT

  if (pos == 0x1) {
    n22xxed_wd_write (hw, 0x31, 0x04);
  }
  else if (pos == 0x2) {
    n22xxed_wd_write (hw, 0x37, 0x04);
  }
  else {
    n22xxed_wd_write (hw, 0x31, 0x04);
    n22xxed_wd_write (hw, 0x37, 0x04);
  }

  return N22XX_STAT_OK;
}

static enum n22xxed_stat
n22xxed_force_active (struct n22xxed_hd *hw, uint8_t pos)
{
  // issue force bypass cmd to the WDT

  if (pos == 0x1) {
    n22xxed_wd_write (hw, 0x31, 0x02);
  }
  else if (pos == 0x2) {
    n22xxed_wd_write (hw, 0x37, 0x02);
  }
  else {
    n22xxed_wd_write (hw, 0x31, 0x02);
    n22xxed_wd_write (hw, 0x37, 0x02);
  }

  return N22XX_STAT_OK;
}

static enum n22xxed_stat
n22xxed_force_no_link (struct n22xxed_hd *hw, uint8_t pos)
{
  // issue force bypass cmd to the WDT
  if (pos == 0x1) {
    n22xxed_wd_write (hw, 0x31, 0x05);
  }
  else if (pos == 0x2) {
    n22xxed_wd_write (hw, 0x37, 0x05);
  }
  else {
    n22xxed_wd_write (hw, 0x31, 0x05);
    n22xxed_wd_write (hw, 0x37, 0x05);
  }

  return N22XX_STAT_OK;
}

static enum n22xxed_stat
n22xxed_force_normal (struct n22xxed_hd *hw, uint8_t pos)
{
  // issue force bypass cmd to the WDT
  if (pos == 0x1) {
    n22xxed_wd_write (hw, 0x31, 0x10);
  }
  else if (pos == 0x2) {
    n22xxed_wd_write (hw, 0x37, 0x10);
  }
  else {
    n22xxed_wd_write (hw, 0x31, 0x10);
    n22xxed_wd_write (hw, 0x37, 0x10);
  }

  return N22XX_STAT_OK;
}
#endif

void
SPI_PROG_TX (uint8_t * hw, uint8_t * hw_b, uint8_t value)
{
  unsigned char i;
  uint8_t tx_data;
  uint8_t cpld_spi;

  tx_data = value;

  n22xxed_rx_two (hw, hw_b, 8, BSL_2, &cpld_spi);

  // TX 8 bit data    
  for (i = 0; i < 8; i++) {
    // generate rising edge on clk
    if (tx_data & 0x80) {
      cpld_spi |= 0x2;
    }
    else {
      cpld_spi &= ~0x2;
    }

    // TX data    
    n22xxed_tx_two (hw, hw_b, 8, BSL_2, cpld_spi);

    // clock data on rising edge
    cpld_spi |= 0x1;
    n22xxed_tx_two (hw, hw_b, 8, BSL_2, cpld_spi);

    // wait for 2u sec
    usec_delay (1);

    // generate falling edge on clk
    cpld_spi &= ~0x1;
    n22xxed_tx_two (hw, hw_b, 8, BSL_2, cpld_spi);
    tx_data = tx_data << 1;

    usec_delay (1);
  }
}

uint8_t
SPI_PROG_RX (uint8_t * hw, uint8_t * hw_b)
{
  uint8_t cpld_spi, miso;
  unsigned char i;
  uint8_t rx_data = 0x00;

  n22xxed_rx_two (hw, hw_b, 8, BSL_2, &cpld_spi);

  // rx 8 bit data
  for (i = 0; i < 8; i++) {
    // generate rising edge on clk
    cpld_spi |= 0x1;
    n22xxed_tx_two (hw, hw_b, 8, BSL_2, cpld_spi);

    // wait 2u
    usec_delay (1);

    // sample 
    n22xxed_rx_two (hw, hw_b, 8, BSL_3, &miso);

    if (miso & 0x2) {
      rx_data |= 0x01;
    }
    else {
      rx_data &= 0xFE;
    }

    if (i < 7) {
      rx_data = rx_data << 1;
    }

    cpld_spi &= ~0x1;
    n22xxed_tx_two (hw, hw_b, 8, BSL_2, cpld_spi);

    // wait 2u
    usec_delay (1);
  }
  return rx_data;
}

static enum n22xxed_stat
n22xxedp_isp_avr_spi_mode_init (uint8_t * hw, uint8_t * hw_b)
{
  uint8_t rst_ctrl, cpu_spi;

  // state 0
  n22xxed_tx_two (hw, hw_b, CSR, BSL_0, 2);

  n22xxed_rx_two (hw, hw_b, SPI_CTL, BSL_0, &rst_ctrl);
  n22xxed_rx_two (hw, hw_b, SPI_CTL, BSL_2, &cpu_spi);

  // state 2
  rst_ctrl |= SW_RSTN;
  n22xxed_tx_two (hw, hw_b, SPI_CTL, BSL_0, rst_ctrl);
  usec_delay (100);
  cpu_spi &= ~SW_RSTN;
  n22xxed_tx_two (hw, hw_b, SPI_CTL, BSL_2, cpu_spi);

  // state 3
  usec_delay (100);
  rst_ctrl &= ~SW_RSTN;
  n22xxed_tx_two (hw, hw_b, SPI_CTL, BSL_0, rst_ctrl);
  usec_delay (100);
  rst_ctrl |= SW_RSTN;
  n22xxed_tx_two (hw, hw_b, SPI_CTL, BSL_0, rst_ctrl);

  // state 4
  usec_delay (100);
  rst_ctrl &= ~SW_RSTN;
  n22xxed_tx_two (hw, hw_b, SPI_CTL, BSL_0, rst_ctrl);
  usec_delay (100);
  rst_ctrl |= SW_RSTN;
  n22xxed_tx_two (hw, hw_b, SPI_CTL, BSL_0, rst_ctrl);

  // wait for 2 ms before we issue any instructions
  msec_delay (20);

  return N22XX_STAT_OK;
}

static enum n22xxed_stat
n22xxedp_isp_avr_enter_prog_mode (uint8_t * hw, uint8_t * hw_b)
{
  SPI_PROG_TX (hw, hw_b, PROG_ENABLE_1);
  SPI_PROG_TX (hw, hw_b, PROG_ENABLE_2);
  SPI_PROG_TX (hw, hw_b, PROG_ENABLE_3);
  SPI_PROG_TX (hw, hw_b, PROG_ENABLE_4);

  return N22XX_STAT_OK;
}

static enum n22xxed_stat
n22xxedp_isp_avr_spi_mode_exit (uint8_t * hw, uint8_t * hw_b)
{
  uint8_t rst_ctrl, cpu_spi;

  n22xxed_rx_two (hw, hw_b, SPI_CTL, BSL_0, &rst_ctrl);
  n22xxed_rx_two (hw, hw_b, SPI_CTL, BSL_2, &cpu_spi);

  cpu_spi &= ~SW_RSTN;
  n22xxed_tx_two (hw, hw_b, SPI_CTL, BSL_2, cpu_spi);

  // state 5
  rst_ctrl &= ~SW_RSTN;
  n22xxed_tx_two (hw, hw_b, SPI_CTL, BSL_0, rst_ctrl);
  usec_delay (100);

  // state 6
  rst_ctrl |= SW_RSTN;
  n22xxed_tx_two (hw, hw_b, SPI_CTL, BSL_0, rst_ctrl);
  usec_delay (100);

  // state 7
  rst_ctrl &= ~SW_RSTN;
  n22xxed_tx_two (hw, hw_b, SPI_CTL, BSL_0, rst_ctrl);
  usec_delay (100);

  return N22XX_STAT_OK;
}

static enum n22xxed_stat
n22xxedp_isp_avr_read_sign (uint8_t * hw, uint8_t * hw_b, uint8_t * signature)
{
  uint8_t i;

  // clear array
  for (i = 0; i < 3; i++) {
    signature[i] = 0x00;
  }

  // get signature
  for (i = 0; i < 3; i++) {
    SPI_PROG_TX (hw, hw_b, RD_SIGN_BYTE_1);
    SPI_PROG_TX (hw, hw_b, RD_SIGN_BYTE_2);
    SPI_PROG_TX (hw, hw_b, RD_SIGN_BYTE_3 | i);
    signature[i] = SPI_PROG_RX (hw, hw_b);
  }

  return N22XX_STAT_OK;
}

static enum n22xxed_stat
n22xxedp_isp_avr_chip_erase (uint8_t * hw, uint8_t * hw_b)
{
  SPI_PROG_TX (hw, hw_b, CHIP_ERASE_1);
  SPI_PROG_TX (hw, hw_b, CHIP_ERASE_2);
  SPI_PROG_TX (hw, hw_b, CHIP_ERASE_3);
  SPI_PROG_TX (hw, hw_b, CHIP_ERASE_4);
  msec_delay (500);		// wait at least 18 ms

  return N22XX_STAT_OK;
}

static enum n22xxed_stat
n22xxedp_isp_avr_prog_page_load (uint8_t * hw, uint8_t * hw_b, uint16_t * value)
{
  uint8_t i;

  for (i = 0; i < 32; i++) {

    //  load low byte to program memory page 
    SPI_PROG_TX (hw, hw_b, LOAD_PROG_PAGE_1L);
    SPI_PROG_TX (hw, hw_b, LOAD_PROG_PAGE_2);
    SPI_PROG_TX (hw, hw_b, i);
    SPI_PROG_TX (hw, hw_b, value[i]);

    //  load high byte to program memory page
    SPI_PROG_TX (hw, hw_b, LOAD_PROG_PAGE_1H);
    SPI_PROG_TX (hw, hw_b, LOAD_PROG_PAGE_2);
    SPI_PROG_TX (hw, hw_b, i);
    SPI_PROG_TX (hw, hw_b, (value[i] >> 8));
  }

  msec_delay (10);

  return N22XX_STAT_OK;
}

static enum n22xxed_stat
n22xxedp_isp_avr_prog_page_write (uint8_t * hw, uint8_t * hw_b, uint16_t offset)
{
  // write program memory page 
  SPI_PROG_TX (hw, hw_b, WRITE_PROG_PAGE_1);
  SPI_PROG_TX (hw, hw_b, (offset & 0x0f00) >> 8);
  SPI_PROG_TX (hw, hw_b, (offset & 0x00e0));
  SPI_PROG_TX (hw, hw_b, WRITE_PROG_PAGE_4);

  msec_delay (10);

  return N22XX_STAT_OK;
}

static enum n22xxed_stat
n22xxedp_isp_avr_prog_read (uint8_t * hw, uint8_t * hw_b, uint16_t offset,
			  uint16_t * value)
{
  // read the lower byte
  SPI_PROG_TX (hw, hw_b, READ_PROG_1L);
  SPI_PROG_TX (hw, hw_b, (offset & 0x0f00) >> 8);
  SPI_PROG_TX (hw, hw_b, (offset & 0x00ff));

  *value = (uint16_t) SPI_PROG_RX (hw, hw_b);

  // read the higher byte
  SPI_PROG_TX (hw, hw_b, READ_PROG_1H);
  SPI_PROG_TX (hw, hw_b, (offset & 0x0f00) >> 8);
  SPI_PROG_TX (hw, hw_b, (offset & 0x00ff));

  *value |= ((uint16_t) SPI_PROG_RX (hw, hw_b) << 8);

  return N22XX_STAT_OK;
}

static enum n22xxed_stat
n22xxedp_isp_avr_eeprom_read (uint8_t * hw, uint8_t * hw_b, uint16_t offset,
			    uint8_t * value)
{
  SPI_PROG_TX (hw, hw_b, READ_EPROM_1);
  SPI_PROG_TX (hw, hw_b, (offset & 0x0100) >> 8);
  SPI_PROG_TX (hw, hw_b, offset);

  *value = SPI_PROG_RX (hw, hw_b);

  return N22XX_STAT_OK;
}

static enum n22xxed_stat
n22xxedp_isp_avr_eeprom_write (uint8_t * hw, uint8_t * hw_b, uint16_t offset,
			     uint8_t value)
{
  uint8_t tmp;

  SPI_PROG_TX (hw, hw_b, WRITE_EPROM_1);
  //SPI_PROG_TX(hw, WRITE_EPROM_2);
  SPI_PROG_TX (hw, hw_b, (offset & 0x0100) >> 8);
  SPI_PROG_TX (hw, hw_b, offset);
  SPI_PROG_TX (hw, hw_b, value);

  // poll until the lower byte have been programmed 
  if (value != 0xff) {
    n22xxedp_isp_avr_eeprom_read (hw, hw_b, offset, &tmp);
    while (tmp != value) {
      n22xxedp_isp_avr_eeprom_read (hw, hw_b, offset, &tmp);
    }
  }
  else {
    // wait until the lower byte have been programmed
    msec_delay (100);
  }

  return N22XX_STAT_OK;
}

int
n22xxed_init (void)
{
  int i, k;
  struct pci_dev *pdev;

  uint8_t *tmpAddrA;
  uint8_t *tmpAddrB;

  uint64_t mmio_mem, mmio_len;
  uint8_t fwRev, tmp;

  int result = 0;

  uint16_t n22xxedq_pci_tbl[][4] = {
    {0x8086, 0x105e, 0x1fc1, 0x0039},	//n2265 copper
    {0x8086, 0x105f, 0x1fc1, 0x0044},	//n2285 fiber
    {0x8086, 0x10c9, 0x8086, 0x008A},    //n32256 copper
    {0x8086, 0x10c9, 0x1fc1, 0x008A},    //n32256 copper
  };

  num_of_n22xxed = 0;
  num_of_n22xxedd = 0;
  porta_num = 0;
  portb_num = 0;

  /*
   * look for all pci base niagara devices
   */
  for (i = 0; i < (sizeof (n22xxedq_pci_tbl) / 8); i++) {
    pdev = NULL;

    do {
#ifdef K26
      pdev = pci_get_subsys (n22xxedq_pci_tbl[i][vendor],
			     n22xxedq_pci_tbl[i][dev],
			     n22xxedq_pci_tbl[i][subvendor],
			     n22xxedq_pci_tbl[i][subdevice], pdev);
#else
      pdev = pci_find_subsys (n22xxedq_pci_tbl[i][vendor],
			      n22xxedq_pci_tbl[i][dev],
			      n22xxedq_pci_tbl[i][subvendor],
			      n22xxedq_pci_tbl[i][subdevice], pdev);
#endif
      if (pdev) {
	num_of_n22xxedd++;

#ifdef debug
	printk (KERN_INFO "\n[%x][%x] find %d", n22xxedq_pci_tbl[i][dev],
		n22xxedq_pci_tbl[i][subdevice], i);
#endif

      }
    } while (pdev);
  }

  num_of_n22xxed = num_of_n22xxedd / 2;

#ifdef debug
  printk (KERN_INFO "\nfind %d dual", num_of_n22xxedd / 2);
  printk (KERN_INFO "\nfind %d n22xxed dev", num_of_n22xxed);
  printk (KERN_INFO "\n");
#endif

  /*  
   *  allocate space  
   */

  n22xxed_add = kmalloc (num_of_n22xxed * sizeof (struct n22xxed_hd), GFP_KERNEL);
  nic_addr = kmalloc (num_of_n22xxedd * sizeof (uint8_t *), GFP_KERNEL);

  // goto fail_malloc;
  if ((!n22xxed_add) || (!nic_addr)) {
#ifdef debug
    printk (KERN_INFO "can't allocate kernel space\n");
#endif
    goto fail_malloc;
  }

  /* 
   * assign hardware and flash address for quad port devices 
   */

  k = 0;
  for (i = 0; i < (sizeof (n22xxedq_pci_tbl) / 8); i++) {
    pdev = NULL;

    do {
#ifdef K26
      pdev = pci_get_subsys (n22xxedq_pci_tbl[i][vendor],
			     n22xxedq_pci_tbl[i][dev],
			     n22xxedq_pci_tbl[i][subvendor],
			     n22xxedq_pci_tbl[i][subdevice], pdev);
#else
      pdev = pci_find_subsys (n22xxedq_pci_tbl[i][vendor],
			      n22xxedq_pci_tbl[i][dev],
			      n22xxedq_pci_tbl[i][subvendor],
			      n22xxedq_pci_tbl[i][subdevice], pdev);
#endif
      if (pdev) {

	  mmio_mem = pci_resource_start (pdev, 0);
	  mmio_len = pci_resource_len (pdev, 0);
	  nic_addr[nic_num] = ioremap (mmio_mem, mmio_len);
	  nic_num++;

	  if ((k % 2) == 0) {
	    n22xxed_add[porta_num].hw_a = nic_addr[nic_num - 1];
	    n22xxed_add[porta_num].subdev_id = n22xxedq_pci_tbl[i][subdevice];
	    n22xxed_add[porta_num].timer_set = FALSE;
	    n22xxed_add[porta_num].timer_set_b = FALSE;
	    n22xxed_add[porta_num].heartbeat = 0;

#ifdef debug
//	    printk (KERN_INFO "porta_num %d\n", porta_num);
//                      printk (KERN_INFO "n22xxed.hw_addr %x\n", (uint32_t)n22xxed_hw_a[porta_num].hw_addr);        
#endif
	    porta_num++;
	  }
	  else {
	    n22xxed_add[portb_num].hw_b = nic_addr[nic_num - 1];
	    n22xxed_add[portb_num].subdev_id = n22xxedq_pci_tbl[i][subdevice];
	    n22xxed_add[portb_num].timer_set = FALSE;
	    n22xxed_add[portb_num].timer_set_b = FALSE;
	    n22xxed_add[portb_num].heartbeat = 0;

#ifdef debug
//	    printk (KERN_INFO "portb_num %d\n", portb_num);
//                      printk (KERN_INFO "n22xxed.hw_addr %x\n", (uint32_t)n22xxed_hw_b[portb_num].hw_addr);       
#endif
	    portb_num++;
	  }
	k++;
      }
    } while (pdev);
  }
  printk (KERN_INFO "nic_num = %d\n", nic_num);
  /*
   * locate memory map
   */
  for (i = 0; i < num_of_n22xxed; i++) {
      porta_io_init (&n22xxed_add[i]);
      portb_io_init (&n22xxed_add[i]);
      n22xxed_cpld_write (n22xxed_add[i].hw_a, n22xxed_add[i].hw_b,
              AVR_ADDR, 0x02, 8);
      n22xxed_cpld_read (n22xxed_add[i].hw_a, n22xxed_add[i].hw_b, AVR_ADDR,
              &tmp, 8);
      if (tmp != 0x02) {
	tmpAddrA = (uint8_t *) n22xxed_add[i].hw_a;
	tmpAddrB = (uint8_t *) n22xxed_add[i].hw_b;
	n22xxed_add[i].hw_a = (uint8_t *) tmpAddrB;
	n22xxed_add[i].hw_b = (uint8_t *) tmpAddrA;
      }
  }

  /* 
   * initialize all porta and portb gpio
   */
  for (i = 0; i < num_of_n22xxed; i++) {
#ifdef debug
//      printk (KERN_INFO "INIT porta & portb IO %d\n", i);
#endif
      porta_io_init (&n22xxed_add[i]);
      portb_io_init (&n22xxed_add[i]);
  }
#if 0				/* frank debug */
  for (i = 0; i < nic_num; i++) {
    printk (KERN_INFO "dump remap nic_num = %d %d 0x%x\n", nic_num, i,
	    (uint8_t *) nic_addr[i]);
  }

#endif
  /*
   * identify firmware rev 
   */

  for (i = 0; i < num_of_n22xxed; i++) {
      n22xxed_cpld_write (n22xxed_add[i].hw_a, n22xxed_add[i].hw_b,
              AVR_DAT, 0x55, 8);
      n22xxed_cpld_write (n22xxed_add[i].hw_a, n22xxed_add[i].hw_b,
              SPI_CTL, 0x02, 8);
    n22xxed_wd_read (&n22xxed_add[i], FW_ID, &fwRev);
    n22xxed_add[i].fw_rev = fwRev;
  }

  sema_init (&n22xxed_sema, 1);

  /*
   * register your major, and accept a dynamic number
   */

  result = register_chrdev (n22xxed_major, "n22xxed", &n22xxed_fops);
  if (result < 0) {
    return result;
  }

  if (n22xxed_major == 0) {
    n22xxed_major = result;
  }

  return 0;

fail_malloc:
  kfree (n22xxed_add);
  kfree (nic_addr);

  unregister_chrdev (n22xxed_major, "n22xxed");

  return result;
}

void
n22xxed_exit (void)
{
  int i;

  /*
   * remove all heart beat timer 
   */

  for (i = 0; i < num_of_n22xxed; i++) {
    if (n22xxed_add[i].timer_set == TRUE)
      del_timer_sync (&n22xxed_add[i].im_bypass_timer);
  }

  /* 
   * unmap all niagara devices 
   */

  for (i = 0; i < nic_num; i++) {
    printk (KERN_INFO "unmap %d 0x%x\n", nic_num, (uint32_t)nic_addr[i]);
    iounmap (nic_addr[i]);
  }

  /* 
   * free all devices space 
   */

  kfree (n22xxed_add);
  kfree (nic_addr);
  unregister_chrdev (n22xxed_major, "n22xxed");
}

module_init (n22xxed_init);
module_exit (n22xxed_exit);

MODULE_LICENSE ("Dual BSD/GPL");

/*
 * Open and close
 */

int
n22xxed_open (struct inode *inode, struct file *filp)
{
  return 0;
}

int
n22xxed_release (struct inode *inode, struct file *filp)
{
  return 0;
}

/*
 * The ioctl() implementation
 */

int
n22xxed_ioctl (struct inode *inode, struct file *filp, unsigned int cmd,
	     unsigned long arg)
{
  int pair_num, eeprom_num;

  struct n22xxed_data n22xxedData;

  copy_from_user ((struct n22xxed_data *) &n22xxedData, (uint8_t *) arg,
		  sizeof (struct n22xxed_data));

  pair_num = n22xxedData.pair_num;
  eeprom_num = n22xxedData.pair_num;

  /* 
   * run the diagnotic test 
   */

  switch (cmd) {

  case N22XX_UPDATE_MAX_PAIR_NUM:
    n22xxedData.max_pair_num = num_of_n22xxed;

    break;

  case N22XX_WDI_KICK:
    lockN22xx ();
    n22xxedData.status = n22xxed_wdi_kick (&n22xxed_add[pair_num],
            n22xxedData.pos);
    unlockN22xx ();

    break;

  case N22XX_RELAY_CHECK:
    lockN22xx ();
    n22xxedData.status = n22xxed_relay_check (&n22xxed_add[pair_num],
            &n22xxedData.value);
    unlockN22xx ();

    break;

  case N22XX_WD_WRITE:
    lockN22xx ();
    n22xxedData.status = n22xxed_wd_write (&n22xxed_add[pair_num],
            n22xxedData.offset, n22xxedData.value);

    unlockN22xx ();

    break;

  case N22XX_WD_READ:
    lockN22xx ();
    n22xxedData.status = n22xxed_wd_read (&n22xxed_add[pair_num],
            n22xxedData.offset, &n22xxedData.value);

    unlockN22xx ();

    break;

  case N22XX_ADD_TIMER:
    n22xxedData.status = n22xxed_add_timer (&n22xxed_add[pair_num],
            n22xxedData.pos);

    break;

  case N22XX_DEL_TIMER:
    n22xxedData.status = n22xxed_del_timer (&n22xxed_add[pair_num],
            n22xxedData.pos);

    break;

#if 0
  case N22XX_FORCE_BYPASS:
    lockN22xx ();
    n22xxedData.status = n22xxed_force_bypass (&n22xxed_add[pair_num],
            n22xxedData.pos);
    unlockN22xx ();

    break;

  case N22XX_FORCE_ACTIVE:
    lockN22xx ();
    n22xxedData.status = n22xxed_force_active (&n22xxed_add[pair_num],
            n22xxedData.pos);
    unlockN22xx ();

    break;

  case N22XX_FORCE_NO_LINK:
    lockN22xx ();
    n22xxedData.status = n22xxed_force_no_link (&n22xxed_add[pair_num],
            n22xxedData.pos);
    unlockN22xx ();

    break;

  case N22XX_FORCE_NORMAL:
    lockN22xx ();
    n22xxedData.status = n22xxed_force_normal (&n22xxed_add[pair_num],
            n22xxedData.pos);
    unlockN22xx ();

    break;
#endif

  case N22XX_CPLD_WRITE:
    lockN22xx ();
    n22xxedData.status = n22xxed_cpld_write (n22xxed_add[pair_num].hw_a,
            n22xxed_add[pair_num].hw_b, n22xxedData.offset, n22xxedData.value,
            n22xxedData.num);
    unlockN22xx ();
    break;

  case N22XX_CPLD_READ:
    lockN22xx ();
    n22xxedData.status = n22xxed_cpld_read (n22xxed_add[pair_num].hw_a,
            n22xxed_add[pair_num].hw_b, n22xxedData.offset,
            &(n22xxedData.value), n22xxedData.num);
    unlockN22xx ();
    break;

  case N22XX_REG_READ:
    n22xxedData.status = n22xxed_reg_read (n22xxed_add[pair_num].hw_a,
            n22xxed_add[pair_num].hw_b, &n22xxedData.reg_value_a,
            &n22xxedData.reg_value_b, n22xxedData.pos, n22xxedData.port);
    break;

#if 1
  case N22XX_REG_WRITE:
    n22xxedData.status = n22xxed_reg_write (n22xxed_add[pair_num].hw_a,
            n22xxed_add[pair_num].hw_b, n22xxedData.reg_value_a,
            n22xxedData.pos, n22xxedData.port);
    break;
#endif

  case S_READ_EEPROM:
    lockN22xx ();
    n22xxedData.status =
            s_read_eeprom (nic_addr[eeprom_num + n22xxedData.mac_num],
            n22xxedData.p_addr, &n22xxedData.p_data);
    unlockN22xx ();
    break;

  case S_WRITE_EEPROM:
    lockN22xx ();
    n22xxedData.status =
            s_write_eeprom (nic_addr[eeprom_num + n22xxedData.mac_num],
            n22xxedData.p_addr, n22xxedData.p_data);
    unlockN22xx ();
    break;

  case N22XX_ISP_AVR_PROG_UPDATE:

    break;

  case N22XXP_ISP_AVR_SPI_MODE_INIT:
    n22xxedData.status =
            n22xxedp_isp_avr_spi_mode_init (n22xxed_add[pair_num].hw_a,
            n22xxed_add[pair_num].hw_b);
    break;

  case N22XXP_ISP_AVR_SPI_MODE_EXIT:
    n22xxedData.status =
            n22xxedp_isp_avr_spi_mode_exit (n22xxed_add[pair_num].hw_a,
            n22xxed_add[pair_num].hw_b);
    break;

  case N22XXP_ISP_AVR_SPI_PROG_EN:
    n22xxedData.status =
            n22xxedp_isp_avr_enter_prog_mode (n22xxed_add[pair_num].hw_a,
            n22xxed_add[pair_num].hw_b);
    break;

  case N22XXP_ISP_AVR_READ_SIGN:
    n22xxedData.status =
            n22xxedp_isp_avr_read_sign (n22xxed_add[pair_num].hw_a,
            n22xxed_add[pair_num].hw_b, n22xxedData.signature);
    break;

  case N22XXP_ISP_AVR_PROG_READ:
    n22xxedData.status =
            n22xxedp_isp_avr_prog_read (n22xxed_add[pair_num].hw_a,
            n22xxed_add[pair_num].hw_b, n22xxedData.p_addr,
            &(n22xxedData.p_data));
    break;

  case N22XXP_ISP_AVR_CHIP_ERASE:
    n22xxedData.status =
            n22xxedp_isp_avr_chip_erase (n22xxed_add[pair_num].hw_a,
            n22xxed_add[pair_num].hw_b);
    break;

  case N22XXP_ISP_AVR_PROG_PAGE_LOAD:
    n22xxedData.status =
            n22xxedp_isp_avr_prog_page_load (n22xxed_add[pair_num].hw_a,
            n22xxed_add[pair_num].hw_b, n22xxedData.page);
    break;

  case N22XXP_ISP_AVR_PROG_PAGE_WRITE:
    n22xxedData.status =
            n22xxedp_isp_avr_prog_page_write (n22xxed_add[pair_num].hw_a,
            n22xxed_add[pair_num].hw_b, n22xxedData.p_addr);
    break;

  case N22XXP_ISP_AVR_EEPROM_WRITE:
    n22xxedData.status =
            n22xxedp_isp_avr_eeprom_write (n22xxed_add[pair_num].hw_a,
            n22xxed_add[pair_num].hw_b, n22xxedData.offset, n22xxedData.value);
    break;

  case N22XXP_ISP_AVR_EEPROM_READ:
    n22xxedData.status =
            n22xxedp_isp_avr_eeprom_read (n22xxed_add[pair_num].hw_a,
            n22xxed_add[pair_num].hw_b, n22xxedData.offset,
            &n22xxedData.value);
    break;

  default:
    n22xxedData.status = N22XX_STAT_NOT_SUPPORTED;

    break;
  }

  copy_to_user ((uint8_t *) arg, (struct n22xxed_data *) &n22xxedData,
		sizeof (struct n22xxed_data));

  return 0;
}
