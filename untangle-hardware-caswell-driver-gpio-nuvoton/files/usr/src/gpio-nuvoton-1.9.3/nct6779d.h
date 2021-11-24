
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

#ifndef _NCT6779D_H_
#define _NCT6779D_H_

#define EFER			0x2E
#define EFIR			0x2E
#define EFDR			0x2F

#define CR7			0x07
#define LD7			0x07
#define LD8			0x08
#define LD9			0x09

#define GP_IO			0
#define GP_LVL			1
#define GPI_INV			2

#define GPIO_USE_SEL		0x30


#define NCT6779D_GPIO0		0xE0
#define NCT6779D_GPIO1		0xF0
#define NCT6779D_GPIO2		0xE0
#define NCT6779D_GPIO3		0xE4
#define NCT6779D_GPIO4		0xF0
#define NCT6779D_GPIO5		0xF4
#define NCT6779D_GPIO6		0xF4
#define NCT6779D_GPIO7		0xE0
#define NCT6779D_GPIO8		0xE4

void nct6779d_set_gpio_use_sel(int cmd, int pin);
void nct6779d_set_gp_io_sel(int cmd, int pin);
void nct6779d_set_gp_lvl(int cmd, int pin);
void nct6779d_set_gpi_inv(int cmd, int pin);
u8 nct6779d_get_gpio_use_sel(int port);
u8 nct6779d_get_gp_io_sel(int port);
u8 nct6779d_get_gp_lvl(int port);
u8 nct6779d_get_gpi_inv(int port);


#endif /* _NCT6779D_H_ */
