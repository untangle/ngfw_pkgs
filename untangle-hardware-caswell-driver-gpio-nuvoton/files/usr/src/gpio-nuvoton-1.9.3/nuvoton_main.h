/*******************************************************************************

  CASwell(R) Nuvoton Super I/O GPIO Linux driver
  Copyright(c) 2013 Alan Yu     <alan.yu@cas-well.com>

  This program is free software; you can redistribute it and/or modify it
  under the terms and conditions of the GNU General Public License,
  version 2, as published by the Free Software Foundation.

  This program is distributed in the hope it will be useful, but WITHOUT
  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
  more details.

  You should have received a copy of the GNU General Public License along with
  this program; if not, write to the Free Software Foundation, Inc.,
  51 Franklin St - Fifth Floor, Boston, MA 02110-1301 USA.

*******************************************************************************/

#ifndef _GPIO_NUVOTON_H_
#define _GPIO_NUVOTON_H_

#define DRIVERNAME		"gpio-nuvoton"

#define DRV_VERSION		"V1.9.3"

struct SIO_DEVICE {
	u32 devid;
	u8 *devname;
	u8 ports;
};

#define SIO_PRIV(id, name, pt)  \
	.devid = id,                \
	.devname = name,	\
	.ports = pt

struct gpio_ops {
	void (*set_select)(int, int);
	void (*set_direction)(int, int);
	void (*set_output)(int, int);
	void (*set_inv)(int, int);

	u8 (*get_select)(int);
	u8 (*get_direction)(int);
	u8 (*get_output)(int);
	u8 (*get_inv)(int);
};

#define SELECT_OPT		0
#define OUTPUT_OPT		1
#define INPUT_OPT		2
#define DIRECTION_OPT		3
#define INVERSE_OPT		4

#define BIT_HI			1
#define BIT_LO			0
#define MAX_GPIO_PINS		8
#define MAX_MFUNC_REGS		2

/*
 * ISA constants
 */

#define IOREGION_ALIGNMENT      (~7)
#define IOREGION_OFFSET         5
#define IOREGION_LENGTH         2
#define ADDR_REG_OFFSET         0
#define DATA_REG_OFFSET         1

#define NCT6775_REG_BANK        0x4E


/*
 * Super-I/O constants and functions
 */

#define NCT6775_LD_HWM          0x0b
#define SIO_REG_DEVID           0x20    /* Device ID (2 bytes) */
#define SIO_REG_ENABLE          0x30    /* Logical device enable */
#define SIO_REG_ADDR            0x60    /* Logical device address (2 bytes) */

#define NCT6791_REG_HM_IO_SPACE_LOCK_ENABLE     0x28

/* Bank0 FBh for determination NCT6796D or NCT5581D */
#define NCT5581D_MASK     0x18

typedef struct gpio_priv {
	struct miscdevice	*mdev;
	unsigned int 		mem_base;
	u32 			sio_priv_index;
	struct			gpio_ops ops;
} gpio_priv_t;


void nuvoton_enter_ext_mode(void);
void nuvoton_leave_ext_mode(void);
void nuvoton_access_device(u8 ld);
int nuvoton_match(void);
#endif /* _GPIO_NUVOTON_H_ */
