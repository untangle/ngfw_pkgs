
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

#include <linux/module.h>
#include <linux/init.h>
#include <linux/version.h>
#include <linux/types.h>
#include <linux/fs.h>
#include <linux/string.h>
#include <linux/pci.h>

#include "nct6776f.h"
#include "nuvoton_main.h"



void nct6776f_set_gpio_use_sel(int cmd, int pin)
{
	u8	port;
	u16	val;

	port = pin / 10;
	if (port >= 1 && port <= 7) {
		nuvoton_enter_ext_mode();
		nuvoton_access_device(LD9);
		outb(GPIO_USE_SEL, EFIR);
		val = inb(EFDR);

		if (cmd) {
			set_bit(port , (void *)&val);
		} else {
			clear_bit(port , (void *)&val);
		}

		outb(GPIO_USE_SEL, EFIR);
		outb(val, EFDR);
		nuvoton_leave_ext_mode();
	} else if (port == 0) {
		nuvoton_enter_ext_mode();
		nuvoton_access_device(LD8);
		outb(GPIO_USE_SEL, EFIR);
		val = inb(EFDR);

		if (cmd) {
			set_bit((port + 1), (void *)&val);
		} else {
			clear_bit((port + 1), (void *)&val);
		}

		outb(GPIO_USE_SEL, EFIR);
		outb(val, EFDR);
		nuvoton_leave_ext_mode();
	} else if (port == 8 || port == 9) {
		nuvoton_enter_ext_mode();
		nuvoton_access_device(LD7);
		outb(GPIO_USE_SEL, EFIR);
		val = inb(EFDR);

		if (cmd) {
			set_bit((port - 8), (void *)&val);
		} else {
			clear_bit((port - 8), (void *)&val);
		}

		outb(GPIO_USE_SEL, EFIR);
		outb(val, EFDR);
		nuvoton_leave_ext_mode();
	}
}

void nct6776f_set_gp_io_sel(int cmd, int pin)
{
	u8	val;
	u8	port;
	u8	bit;
	u8	reg = 0;


	port = pin / 10;
	bit = pin % 10;
	if ((port >= 0 && port <= 9) && (bit < 8)) {
		nuvoton_enter_ext_mode();
		switch (port) {
		case 0:
			reg = NCT6776F_GPIO0 + GP_IO;
			nuvoton_access_device(LD8);
			break;
		case 1:
			reg = NCT6776F_GPIO1 + GP_IO;
			nuvoton_access_device(LD8);
			break;
		case 2:
			reg = NCT6776F_GPIO2 + GP_IO;
			nuvoton_access_device(LD9);
			break;
		case 3:
			reg = NCT6776F_GPIO3 + GP_IO;
			nuvoton_access_device(LD9);
			break;
		case 4:
			reg = NCT6776F_GPIO4 + GP_IO;
			nuvoton_access_device(LD9);
			break;
		case 5:
			reg = NCT6776F_GPIO5 + GP_IO;
			nuvoton_access_device(LD9);
			break;
		case 6:
			reg = NCT6776F_GPIO6 + GP_IO;
			nuvoton_access_device(LD7);
			break;
		case 7:
			reg = NCT6776F_GPIO7 + GP_IO;
			nuvoton_access_device(LD7);
			break;
		case 8:
			reg = NCT6776F_GPIO8 + GP_IO;
			nuvoton_access_device(LD7);
			break;
		case 9:
			reg = NCT6776F_GPIO9 + GP_IO;
			nuvoton_access_device(LD7);
			break;
		}

		outb(reg, EFIR);
		val = inb(EFDR);


		if (cmd) {
			set_bit(bit, (void *)&val);
		} else {
			clear_bit(bit, (void *)&val);
		}


		outb(reg, EFIR);
		outb(val, EFDR);
		nuvoton_leave_ext_mode();
	}
}


void nct6776f_set_gp_lvl(int cmd, int pin)
{
	u8	val;
	u8	reg = 0;
	u32	port;
	u32	bit;


	port = pin / 10;
	bit = pin % 10;
	if ((port >= 0 && port <= 9) && (bit < 8)) {
		nuvoton_enter_ext_mode();
		switch (port) {
		case 0:
			reg = NCT6776F_GPIO0 + GP_LVL;
			nuvoton_access_device(LD8);
			break;
		case 1:
			reg = NCT6776F_GPIO1 + GP_LVL;
			nuvoton_access_device(LD8);
			break;
		case 2:
			reg = NCT6776F_GPIO2 + GP_LVL;
			nuvoton_access_device(LD9);
			break;
		case 3:
			reg = NCT6776F_GPIO3 + GP_LVL;
			nuvoton_access_device(LD9);
			break;
		case 4:
			reg = NCT6776F_GPIO4 + GP_LVL;
			nuvoton_access_device(LD9);
			break;
		case 5:
			reg = NCT6776F_GPIO5 + GP_LVL;
			nuvoton_access_device(LD9);
			break;
		case 6:
			reg = NCT6776F_GPIO6 + GP_LVL;
			nuvoton_access_device(LD7);
			break;
		case 7:
			reg = NCT6776F_GPIO7 + GP_LVL;
			nuvoton_access_device(LD7);
			break;
		case 8:
			reg = NCT6776F_GPIO8 + GP_LVL;
			nuvoton_access_device(LD7);
			break;
		case 9:
			reg = NCT6776F_GPIO9 + GP_LVL;
			nuvoton_access_device(LD7);
			break;
		}

		outb(reg, EFIR);
		val = inb(EFDR);


		if (cmd) {
			set_bit(bit, (void *)&val);
		} else {
			clear_bit(bit, (void *)&val);
		}

		outb(reg, EFIR);
		outb(val, EFDR);

		nuvoton_leave_ext_mode();
	}
}

void nct6776f_set_gpi_inv(int cmd, int pin)
{
	u8	val;
	u8	reg = 0;
	u32	port;
	u32	bit;

	port = pin / 10;
	bit = pin % 10;
	if ((port >= 0 && port <= 9) && (bit < 8)) {
		nuvoton_enter_ext_mode();
		switch (port) {
		case 0:
			reg = NCT6776F_GPIO0 + GPI_INV;
			nuvoton_access_device(LD8);
			break;
		case 1:
			reg = NCT6776F_GPIO1 + GPI_INV;
			nuvoton_access_device(LD8);
			break;
		case 2:
			reg = NCT6776F_GPIO2 + GPI_INV;
			nuvoton_access_device(LD9);
			break;
		case 3:
			reg = NCT6776F_GPIO3 + GPI_INV;
			nuvoton_access_device(LD9);
			break;
		case 4:
			reg = NCT6776F_GPIO4 + GPI_INV;
			nuvoton_access_device(LD9);
			break;
		case 5:
			reg = NCT6776F_GPIO5 + GPI_INV;
			nuvoton_access_device(LD9);
			break;
		case 6:
			reg = NCT6776F_GPIO6 + GPI_INV;
			nuvoton_access_device(LD7);
			break;
		case 7:
			reg = NCT6776F_GPIO7 + GPI_INV;
			nuvoton_access_device(LD7);
			break;
		case 8:
			reg = NCT6776F_GPIO8 + GPI_INV;
			nuvoton_access_device(LD7);
			break;
		case 9:
			reg = NCT6776F_GPIO9 + GPI_INV;
			nuvoton_access_device(LD7);
			break;
		}

		outb(reg, EFIR);
		val = inb(EFDR);


		if (cmd) {
			set_bit(bit, (void *)&val);
		} else {
			clear_bit(bit, (void *)&val);
		}

		outb(reg, EFIR);
		outb(val, EFDR);
		nuvoton_leave_ext_mode();
	}
}

u8 nct6776f_get_gpio_use_sel(int port)
{
	u8	val;

	nuvoton_enter_ext_mode();
	switch (port) {
	case 0:
		nuvoton_access_device(LD8);
		break;
	case 1:
	case 2:
	case 3:
	case 4:
	case 5:
	case 6:
	case 7:
		nuvoton_access_device(LD9);
		break;
	case 8:
	case 9:
		nuvoton_access_device(LD7);
		break;
	}

	outb(GPIO_USE_SEL, EFIR);
	val = inb(EFDR);
	nuvoton_leave_ext_mode();

	return val;
}

u8 nct6776f_get_gp_io_sel(int port)
{
	u8	val;
	u8	reg = 0;

	nuvoton_enter_ext_mode();
	switch (port) {
	case 0:
		reg = NCT6776F_GPIO0 + GP_IO;
		nuvoton_access_device(LD8);
		break;
	case 1:
		reg = NCT6776F_GPIO1 + GP_IO;
		nuvoton_access_device(LD8);
		break;
	case 2:
		reg = NCT6776F_GPIO2 + GP_IO;
		nuvoton_access_device(LD9);
		break;
	case 3:
		reg = NCT6776F_GPIO3 + GP_IO;
		nuvoton_access_device(LD9);
		break;
	case 4:
		reg = NCT6776F_GPIO4 + GP_IO;
		nuvoton_access_device(LD9);
		break;
	case 5:
		reg = NCT6776F_GPIO5 + GP_IO;
		nuvoton_access_device(LD9);
		break;
	case 6:
		reg = NCT6776F_GPIO6 + GP_IO;
		nuvoton_access_device(LD7);
		break;
	case 7:
		reg = NCT6776F_GPIO7 + GP_IO;
		nuvoton_access_device(LD7);
		break;
	case 8:
		reg = NCT6776F_GPIO8 + GP_IO;
		nuvoton_access_device(LD7);
		break;
	case 9:
		reg = NCT6776F_GPIO9 + GP_IO;
		nuvoton_access_device(LD7);
		break;
	}

	if (reg == 0) {
		return -1;
	}

	outb(reg, EFIR);
	val = inb(EFDR);
	nuvoton_leave_ext_mode();

	return val;
}

u8 nct6776f_get_gp_lvl(int port) {
	u8	val;
	u8	reg = 0;

	nuvoton_enter_ext_mode();
	switch (port) {
	case 0:
		reg = NCT6776F_GPIO0 + GP_LVL;
		nuvoton_access_device(LD8);
		break;
	case 1:
		reg = NCT6776F_GPIO1 + GP_LVL;
		nuvoton_access_device(LD8);
		break;
	case 2:
		reg = NCT6776F_GPIO2 + GP_LVL;
		nuvoton_access_device(LD9);
		break;
	case 3:
		reg = NCT6776F_GPIO3 + GP_LVL;
		nuvoton_access_device(LD9);
		break;
	case 4:
		reg = NCT6776F_GPIO4 + GP_LVL;
		nuvoton_access_device(LD9);
		break;
	case 5:
		reg = NCT6776F_GPIO5 + GP_LVL;
		nuvoton_access_device(LD9);
		break;
	case 6:
		reg = NCT6776F_GPIO6 + GP_LVL;
		nuvoton_access_device(LD7);
		break;
	case 7:
		reg = NCT6776F_GPIO7 + GP_LVL;
		nuvoton_access_device(LD7);
		break;
	case 8:
		reg = NCT6776F_GPIO8 + GP_LVL;
		nuvoton_access_device(LD7);
		break;
	case 9:
		reg = NCT6776F_GPIO9 + GP_LVL;
		nuvoton_access_device(LD7);
		break;
	}

	if (reg == 0) {
		return -1;
	}

	outb(reg, EFIR);
	val = inb(EFDR);
	nuvoton_leave_ext_mode();

	return val;
}

u8 nct6776f_get_gpi_inv(int port) {
	u8	val;
	u8	reg = 0;

	nuvoton_enter_ext_mode();
	switch (port) {
	case 0:
		reg = NCT6776F_GPIO0 + GPI_INV;
		nuvoton_access_device(LD8);
		break;
	case 1:
		reg = NCT6776F_GPIO1 + GPI_INV;
		nuvoton_access_device(LD8);
		break;
	case 2:
		reg = NCT6776F_GPIO2 + GPI_INV;
		nuvoton_access_device(LD9);
		break;
	case 3:
		reg = NCT6776F_GPIO3 + GPI_INV;
		nuvoton_access_device(LD9);
		break;
	case 4:
		reg = NCT6776F_GPIO4 + GPI_INV;
		nuvoton_access_device(LD9);
		break;
	case 5:
		reg = NCT6776F_GPIO5 + GPI_INV;
		nuvoton_access_device(LD9);
		break;
	case 6:
		reg = NCT6776F_GPIO6 + GPI_INV;
		nuvoton_access_device(LD7);
		break;
	case 7:
		reg = NCT6776F_GPIO7 + GPI_INV;
		nuvoton_access_device(LD7);
		break;
	case 8:
		reg = NCT6776F_GPIO8 + GPI_INV;
		nuvoton_access_device(LD7);
		break;
	case 9:
		reg = NCT6776F_GPIO9 + GPI_INV;
		nuvoton_access_device(LD7);
		break;
	}

	if (reg == 0) {
		return -1;
	}

	outb(reg, EFIR);
	val = inb(EFDR);
	nuvoton_leave_ext_mode();

	return val;
}


EXPORT_SYMBOL(nct6776f_set_gpio_use_sel);
EXPORT_SYMBOL(nct6776f_set_gp_lvl);
EXPORT_SYMBOL(nct6776f_get_gp_lvl);
