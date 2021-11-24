
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

#include "nct5581d.h"
#include "nuvoton_main.h"

void nct5581d_set_gpio_use_sel(int cmd, int pin)
{
	u8	port;
	u16	val;

	port = pin / 10;
	if (port == 2 || port == 3 || port == 5) {
		nuvoton_enter_ext_mode();
		nuvoton_access_device(LD9);
		outb(GPIO_USE_SEL, EFIR);
		val = inb(EFDR);

		if (cmd) {
			set_bit((port - 2) , (void *)&val);
		} else {
			clear_bit((port - 2) , (void *)&val);
		}

		outb(GPIO_USE_SEL, EFIR);
		outb(val, EFDR);
		nuvoton_leave_ext_mode();
	} else if (port == 7 || port == 8) {
		nuvoton_enter_ext_mode();
		nuvoton_access_device(LD7);
		outb(GPIO_USE_SEL, EFIR);
		val = inb(EFDR);

		if (cmd) {
			set_bit((port - 6), (void *)&val);
		} else {
			clear_bit((port - 6), (void *)&val);
		}

		outb(GPIO_USE_SEL, EFIR);
		outb(val, EFDR);
		nuvoton_leave_ext_mode();
	}
}

void nct5581d_set_gp_io_sel(int cmd, int pin)
{
	u8	val;
	u8	port;
	u8	bit;
	u8	reg = 0;


	port = pin / 10;
	bit = pin % 10;
	if ((port >= 2 && port <= 8 && port != 4 && port != 6) && (bit < 8)) {
		nuvoton_enter_ext_mode();
		switch (port) {
		case 2:
			reg = NCT5581D_GPIO2 + GP_IO;
			nuvoton_access_device(LD9);
			break;
		case 3:
			reg = NCT5581D_GPIO3 + GP_IO;
			nuvoton_access_device(LD9);
			break;
		case 5:
			reg = NCT5581D_GPIO5 + GP_IO;
			nuvoton_access_device(LD9);
			break;
		case 7:
			reg = NCT5581D_GPIO7 + GP_IO;
			nuvoton_access_device(LD7);
			break;
		case 8:
			reg = NCT5581D_GPIO8 + GP_IO;
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


void nct5581d_set_gp_lvl(int cmd, int pin)
{
	u8	val;
	u8	reg = 0;
	u32	port;
	u32	bit;


	port = pin / 10;
	bit = pin % 10;
	if ((port >= 2 && port <= 8 && port != 4 && port != 6) && (bit < 8)) {
		nuvoton_enter_ext_mode();
		switch (port) {
		case 2:
			reg = NCT5581D_GPIO2 + GP_LVL;
			nuvoton_access_device(LD9);
			break;
		case 3:
			reg = NCT5581D_GPIO3 + GP_LVL;
			nuvoton_access_device(LD9);
			break;
		case 5:
			reg = NCT5581D_GPIO5 + GP_LVL;
			nuvoton_access_device(LD9);
			break;
		case 7:
			reg = NCT5581D_GPIO7 + GP_LVL;
			nuvoton_access_device(LD7);
			break;
		case 8:
			reg = NCT5581D_GPIO8 + GP_LVL;
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

void nct5581d_set_gpi_inv(int cmd, int pin)
{
	u8	val;
	u8	reg = 0;
	u32	port;
	u32	bit;

	port = pin / 10;
	bit = pin % 10;
	if ((port >= 2 && port <= 8 && port != 4 && port != 6) && (bit < 8)) {
		nuvoton_enter_ext_mode();
		switch (port) {
		case 2:
			reg = NCT5581D_GPIO2 + GPI_INV;
			nuvoton_access_device(LD9);
			break;
		case 3:
			reg = NCT5581D_GPIO3 + GPI_INV;
			nuvoton_access_device(LD9);
			break;
		case 5:
			reg = NCT5581D_GPIO5 + GPI_INV;
			nuvoton_access_device(LD9);
			break;
		case 7:
			reg = NCT5581D_GPIO7 + GPI_INV;
			nuvoton_access_device(LD7);
			break;
		case 8:
			reg = NCT5581D_GPIO8 + GPI_INV;
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

u8 nct5581d_get_gpio_use_sel(int port)
{
	u8	val;

	nuvoton_enter_ext_mode();
	switch (port) {
	case 2:
	case 3:
	case 5:
		nuvoton_access_device(LD9);
		break;
	case 7:
	case 8:
		nuvoton_access_device(LD7);
		break;
	}

	outb(GPIO_USE_SEL, EFIR);
	val = inb(EFDR);
	nuvoton_leave_ext_mode();

	return val;
}

u8 nct5581d_get_gp_io_sel(int port)
{
	u8	val;
	u8	reg = 0;

	nuvoton_enter_ext_mode();
	switch (port) {
	case 2:
		reg = NCT5581D_GPIO2 + GP_IO;
		nuvoton_access_device(LD9);
		break;
	case 3:
		reg = NCT5581D_GPIO3 + GP_IO;
		nuvoton_access_device(LD9);
		break;
	case 5:
		reg = NCT5581D_GPIO5 + GP_IO;
		nuvoton_access_device(LD9);
		break;
	case 7:
		reg = NCT5581D_GPIO7 + GP_IO;
		nuvoton_access_device(LD7);
		break;
	case 8:
		reg = NCT5581D_GPIO8 + GP_IO;
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

u8 nct5581d_get_gp_lvl(int port) {
	u8	val;
	u8	reg = 0;

	nuvoton_enter_ext_mode();
	switch (port) {
	case 2:
		reg = NCT5581D_GPIO2 + GP_LVL;
		nuvoton_access_device(LD9);
		break;
	case 3:
		reg = NCT5581D_GPIO3 + GP_LVL;
		nuvoton_access_device(LD9);
		break;
	case 5:
		reg = NCT5581D_GPIO5 + GP_LVL;
		nuvoton_access_device(LD9);
		break;
	case 7:
		reg = NCT5581D_GPIO7 + GP_LVL;
		nuvoton_access_device(LD7);
		break;
	case 8:
		reg = NCT5581D_GPIO8 + GP_LVL;
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

u8 nct5581d_get_gpi_inv(int port) {
	u8	val;
	u8	reg = 0;

	nuvoton_enter_ext_mode();
	switch (port) {
	case 2:
		reg = NCT5581D_GPIO2 + GPI_INV;
		nuvoton_access_device(LD9);
		break;
	case 3:
		reg = NCT5581D_GPIO3 + GPI_INV;
		nuvoton_access_device(LD9);
		break;
	case 5:
		reg = NCT5581D_GPIO5 + GPI_INV;
		nuvoton_access_device(LD9);
		break;
	case 7:
		reg = NCT5581D_GPIO7 + GPI_INV;
		nuvoton_access_device(LD7);
		break;
	case 8:
		reg = NCT5581D_GPIO8 + GPI_INV;
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


EXPORT_SYMBOL(nct5581d_set_gpio_use_sel);
EXPORT_SYMBOL(nct5581d_set_gp_lvl);
EXPORT_SYMBOL(nct5581d_get_gp_lvl);
