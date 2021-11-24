
/*******************************************************************************

  CASwell(R) Nuvoton Super I/O GPIO Linux driver
  Copyright(c) 2017 Type T.H.Wu     <type.wu@cas-well.com>

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

#include "nct6116d.h"
#include "nuvoton_main.h"

void nct6116d_set_gpio_use_sel(int cmd, int pin)
{
	u8	port;
	u16	val;

	port = pin / 10;
	if (port >= 0 && port <= 8) {
		u8 this_LD;

		if (port == 8)
		{
			this_LD = LD9;
			port = 0;
		}
		else
			this_LD = LD7;


		nuvoton_enter_ext_mode();
		nuvoton_access_device(this_LD);
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

#ifdef	CAW_0110_AMI_BIOS_NOT_READY
		{
			static int printonce = 0;

			if (printonce == 0)
			{
				printk("%s: CAW_0110_AMI_BIOS_NOT_READY Enabled.\n", __func__);
				printk("%s: Driver will configure MF/OD/PP for GP:0X,3X,4X,8X\n", __func__);
	
			}
			printonce++;
		}

		nuvoton_enter_ext_mode();
		if (port == 0)
		{
			nuvoton_access_device(LD8);
			outb(NCT6116D_GPIO0_MFUNC_LD8_CRE, EFIR);
			val = inb(EFDR);
			val = val & 0xF0; // GPIO0->LD8->CRE0->bit[0 ~ 3] := GPIO
			outb(val, EFDR);

			nuvoton_access_device(LDF);
			outb(NCT6116D_GPIO0_PPOD_LDF_CRE, EFIR);
			outb(0xF0, EFDR); // ERD's spec
		}
		
		if (port == 3)
		{
			nuvoton_access_device(LD8);
			outb(NCT6116D_GPIO3_MFUNC_LD8_CRE, EFIR);
			val = inb(EFDR);
			val = val & 0xFE; // GPIO3->LD8->CRE0->bit[0 ~ 1] := GPIO
			outb(val, EFDR);

			nuvoton_access_device(LDF);
			outb(NCT6116D_GPIO3_PPOD_LDF_CRE, EFIR);
			outb(0xFE, EFDR); // ERD's spec
		}
		
		if (port == 4)
		{
			nuvoton_access_device(LD8);
			outb(NCT6116D_GPIO4_MFUNC_LD8_CRE, EFIR);
			val = inb(EFDR);
			val = val & 0xE0; // GPIO4->LD8->CRE0->bit[0 ~ 5] := GPIO
			outb(val, EFDR);

			nuvoton_access_device(LDF);
			outb(NCT6116D_GPIO4_PPOD_LDF_CRE, EFIR);
			outb(0xFD, EFDR); // ERD's spec
		}
	
		if (port == 8)
		{
			nuvoton_access_device(LD8);
			outb(NCT6116D_GPIO8_MFUNC_LD8_CRE, EFIR);
			val = inb(EFDR);
			val = val & 0xFC; // GPIO8->LD8->CRE0->bit[0 ~ 1] := GPIO
			outb(val, EFDR);

			nuvoton_access_device(LDF);
			outb(NCT6116D_GPIO8_PPOD_LDF_CRE, EFIR);
			outb(0x00, EFDR); // ERD's spec
		}
		nuvoton_leave_ext_mode();
#endif	/* CAW_0110_AMI_BIOS_NOT_READY */
		
	}
	else
	{
		printk("%s: Invalid PORT#: %d\n", __func__, port);
		WARN_ON(1);
	}

}

void nct6116d_set_gp_io_sel(int cmd, int pin)
{
	u8	val;
	u8	port;
	u8	bit;
	u8	reg = 0;


	port = pin / 10;
	bit = pin % 10;
	if ((port >= 0 && port <= 8) && (bit < 8)) {
		nuvoton_enter_ext_mode();
		switch (port) {
		case 0:
			reg = NCT6116D_GPIO0 + NCT6116D_GP_IO;
			nuvoton_access_device(LD7);
			break;
		case 1:
			reg = NCT6116D_GPIO1 + NCT6116D_GP_IO;
			nuvoton_access_device(LD7);
			break;
		case 2:
			reg = NCT6116D_GPIO2 + NCT6116D_GP_IO;
			nuvoton_access_device(LD7);
			break;
		case 3:
			reg = NCT6116D_GPIO3 + NCT6116D_GP_IO;
			nuvoton_access_device(LD7);
			break;
		case 4:
			reg = NCT6116D_GPIO4 + NCT6116D_GP_IO;
			nuvoton_access_device(LD7);
			break;
		case 5:
			reg = NCT6116D_GPIO5 + NCT6116D_GP_IO;
			nuvoton_access_device(LD7);
			break;
		case 6:
			reg = NCT6116D_GPIO6 + NCT6116D_GP_IO;
			nuvoton_access_device(LD7);
			break;
		case 7:
			reg = NCT6116D_GPIO7 + NCT6116D_GP_IO;
			nuvoton_access_device(LD7);
			break;
		case 8:
			reg = NCT6116D_GPIO8 + NCT6116D_GP_IO;
			nuvoton_access_device(LD9);
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


void nct6116d_set_gp_lvl(int cmd, int pin)
{
	u8	val;
	u8	reg = 0;
	u32	port;
	u32	bit;


	port = pin / 10;
	bit = pin % 10;
	if ((port >= 0 && port <= 8) && (bit < 8)) {
		nuvoton_enter_ext_mode();
		switch (port) {
		case 0:
			reg = NCT6116D_GPIO0 + NCT6116D_GP_LVL;
			nuvoton_access_device(LD7);
			break;
		case 1:
			reg = NCT6116D_GPIO1 + NCT6116D_GP_LVL;
			nuvoton_access_device(LD7);
			break;
		case 2:
			reg = NCT6116D_GPIO2 + NCT6116D_GP_LVL;
			nuvoton_access_device(LD7);
			break;
		case 3:
			reg = NCT6116D_GPIO3 + NCT6116D_GP_LVL;
			nuvoton_access_device(LD7);
			break;
		case 4:
			reg = NCT6116D_GPIO4 + NCT6116D_GP_LVL;
			nuvoton_access_device(LD7);
			break;
		case 5:
			reg = NCT6116D_GPIO5 + NCT6116D_GP_LVL;
			nuvoton_access_device(LD7);
			break;
		case 6:
			reg = NCT6116D_GPIO6 + NCT6116D_GP_LVL;
			nuvoton_access_device(LD7);
			break;
		case 7:
			reg = NCT6116D_GPIO7 + NCT6116D_GP_LVL;
			nuvoton_access_device(LD7);
			break;
		case 8:
			reg = NCT6116D_GPIO8 + NCT6116D_GP_LVL;
			nuvoton_access_device(LD9);
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

void nct6116d_set_gpi_inv(int cmd, int pin)
{
	u8	val;
	u8	reg = 0;
	u32	port;
	u32	bit;

	port = pin / 10;
	bit = pin % 10;
	if ((port >= 0 && port <= 8) && (bit < 8)) {
		nuvoton_enter_ext_mode();
		switch (port) {
		case 0:
			reg = NCT6116D_GPIO0 + NCT6116D_GPI_INV;
			nuvoton_access_device(LD7);
			break;
		case 1:
			reg = NCT6116D_GPIO1 + NCT6116D_GPI_INV;
			nuvoton_access_device(LD7);
			break;
		case 2:
			reg = NCT6116D_GPIO2 + NCT6116D_GPI_INV;
			nuvoton_access_device(LD7);
			break;
		case 3:
			reg = NCT6116D_GPIO3 + NCT6116D_GPI_INV;
			nuvoton_access_device(LD7);
			break;
		case 4:
			reg = NCT6116D_GPIO4 + NCT6116D_GPI_INV;
			nuvoton_access_device(LD7);
			break;
		case 5:
			reg = NCT6116D_GPIO5 + NCT6116D_GPI_INV;
			nuvoton_access_device(LD7);
			break;
		case 6:
			reg = NCT6116D_GPIO6 + NCT6116D_GPI_INV;
			nuvoton_access_device(LD7);
			break;
		case 7:
			reg = NCT6116D_GPIO7 + NCT6116D_GPI_INV;
			nuvoton_access_device(LD7);
			break;
		case 8:
			reg = NCT6116D_GPIO8 + NCT6116D_GPI_INV;
			nuvoton_access_device(LD9);
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

u8 nct6116d_get_gpio_use_sel(int port)
{
	u8	val;
	u8	this_LD;
		
	if (port == 8)
		this_LD = LD9;
	else
		this_LD = LD7;

	nuvoton_enter_ext_mode();
	nuvoton_access_device(this_LD);
	outb(GPIO_USE_SEL, EFIR);
	val = inb(EFDR);
	nuvoton_leave_ext_mode();

	// thwu debug
	{
		u8 v1c, v1d, ld8e0, ldfe0;
		int i;

		nuvoton_enter_ext_mode();
		nuvoton_access_device(LD7);
		
		outb(0x1D, EFIR);
		v1d = inb(EFDR);

		outb(0x1C, EFIR);
		v1c = inb(EFDR);
	
		for (i=0; i<=8; i++)
		{
			nuvoton_access_device(LD8);
			outb(0xE0 + i, EFIR);
			ld8e0 = inb(EFDR);
		
			nuvoton_access_device(LDF);
			outb(0xE0 + i, EFIR);
			ldfe0 = inb(EFDR);

			printk("%s: CR1d=0x%x, CR1c=0x%x, LD8-E%d=0x%x, LDF-E%d=0x%x\n", 
						__func__, v1d, v1c, i, ld8e0, i, ldfe0);
		}

		nuvoton_leave_ext_mode();
	}


	return val;
}

u8 nct6116d_get_gp_io_sel(int port)
{
	u8	val;
	u8	reg = 0;

	nuvoton_enter_ext_mode();
	switch (port) {
	case 0:
		reg = NCT6116D_GPIO0 + NCT6116D_GP_IO;
		nuvoton_access_device(LD7);
		break;
	case 1:
		reg = NCT6116D_GPIO1 + NCT6116D_GP_IO;
		nuvoton_access_device(LD7);
		break;
	case 2:
		reg = NCT6116D_GPIO2 + NCT6116D_GP_IO;
		nuvoton_access_device(LD7);
		break;
	case 3:
		reg = NCT6116D_GPIO3 + NCT6116D_GP_IO;
		nuvoton_access_device(LD7);
		break;
	case 4:
		reg = NCT6116D_GPIO4 + NCT6116D_GP_IO;
		nuvoton_access_device(LD7);
		break;
	case 5:
		reg = NCT6116D_GPIO5 + NCT6116D_GP_IO;
		nuvoton_access_device(LD7);
		break;
	case 6:
		reg = NCT6116D_GPIO6 + NCT6116D_GP_IO;
		nuvoton_access_device(LD7);
		break;
	case 7:
		reg = NCT6116D_GPIO7 + NCT6116D_GP_IO;
		nuvoton_access_device(LD7);
		break;
	case 8:
		reg = NCT6116D_GPIO8 + NCT6116D_GP_IO;
		nuvoton_access_device(LD9);
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

u8 nct6116d_get_gp_lvl(int port) {
	u8	val;
	u8	reg = 0;

	nuvoton_enter_ext_mode();
	switch (port) {
	case 0:
		reg = NCT6116D_GPIO0 + NCT6116D_GP_LVL;
		nuvoton_access_device(LD7);
		break;
	case 1:
		reg = NCT6116D_GPIO1 + NCT6116D_GP_LVL;
		nuvoton_access_device(LD7);
		break;
	case 2:
		reg = NCT6116D_GPIO2 + NCT6116D_GP_LVL;
		nuvoton_access_device(LD7);
		break;
	case 3:
		reg = NCT6116D_GPIO3 + NCT6116D_GP_LVL;
		nuvoton_access_device(LD7);
		break;
	case 4:
		reg = NCT6116D_GPIO4 + NCT6116D_GP_LVL;
		nuvoton_access_device(LD7);
		break;
	case 5:
		reg = NCT6116D_GPIO5 + NCT6116D_GP_LVL;
		nuvoton_access_device(LD7);
		break;
	case 6:
		reg = NCT6116D_GPIO6 + NCT6116D_GP_LVL;
		nuvoton_access_device(LD7);
		break;
	case 7:
		reg = NCT6116D_GPIO7 + NCT6116D_GP_LVL;
		nuvoton_access_device(LD7);
		break;
	case 8:
		reg = NCT6116D_GPIO8 + NCT6116D_GP_LVL;
		nuvoton_access_device(LD9);
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
u8 nct6116d_get_gpi_inv(int port) {
	u8	val;
	u8	reg = 0;

	nuvoton_enter_ext_mode();
	switch (port) {
	case 0:
		reg = NCT6116D_GPIO0 + NCT6116D_GPI_INV;
		nuvoton_access_device(LD7);
		break;
	case 1:
		reg = NCT6116D_GPIO1 + NCT6116D_GPI_INV;
		nuvoton_access_device(LD7);
		break;
	case 2:
		reg = NCT6116D_GPIO2 + NCT6116D_GPI_INV;
		nuvoton_access_device(LD7);
		break;
	case 3:
		reg = NCT6116D_GPIO3 + NCT6116D_GPI_INV;
		nuvoton_access_device(LD7);
		break;
	case 4:
		reg = NCT6116D_GPIO4 + NCT6116D_GPI_INV;
		nuvoton_access_device(LD7);
		break;
	case 5:
		reg = NCT6116D_GPIO5 + NCT6116D_GPI_INV;
		nuvoton_access_device(LD7);
		break;
	case 6:
		reg = NCT6116D_GPIO6 + NCT6116D_GPI_INV;
		nuvoton_access_device(LD7);
		break;
	case 7:
		reg = NCT6116D_GPIO7 + NCT6116D_GPI_INV;
		nuvoton_access_device(LD7);
		break;
	case 8:
		reg = NCT6116D_GPIO7 + NCT6116D_GPI_INV;
		nuvoton_access_device(LD9);
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


EXPORT_SYMBOL(nct6116d_set_gpio_use_sel);
EXPORT_SYMBOL(nct6116d_set_gp_lvl);
EXPORT_SYMBOL(nct6116d_get_gp_lvl);
