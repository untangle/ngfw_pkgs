
/*******************************************************************************

  CASwell(R) Nuvoton Super I/O GPIO Linux driver
  Copyright(c) 2017 Type T.H.Wu   <type.wu@cas-well.com>

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

#ifndef _NCT6116D_H_
#define _NCT6116D_H_

#define EFER			0x2E
#define EFIR			0x2E
#define EFDR			0x2F

#define CR7			0x07
#define LD7			0x07
#define LD8			0x08
#define LD9			0x09
#define	LDF			0x0F

#define NCT6116D_GP_IO			0
#define NCT6116D_GP_LVL			1
#define NCT6116D_GPI_INV		2

#define GPIO_USE_SEL		0x30

/* 0~7: LD7->(E0 ~ FC),  8: LD9->(F0) */
#define NCT6116D_GPIO0		0xE0
#define NCT6116D_GPIO1		0xE4
#define NCT6116D_GPIO2		0xE8
#define NCT6116D_GPIO3		0xEC
#define NCT6116D_GPIO4		0xF0
#define NCT6116D_GPIO5		0xF4
#define NCT6116D_GPIO6		0xF8
#define NCT6116D_GPIO7		0xFC
#define NCT6116D_GPIO8		0xF0 


/*
 * !!! NOTICE !!!
 *
 * If your AMI BIOS code is not ready yet to configure
 * GPIO Multi-Function/OpenDrain/Push-Pull variants @ CAW-0110
 * Please consider to enable this directive.  
 *
 * - CASwell Type T.H.Wu 2017/06/13
 */
//---(DISABLED) #define	CAW_0110_AMI_BIOS_NOT_READY

/*
 * Multi-Function(LD8) &  OD/PP(LDF)
 *
 * NOTE: This is used when "CAW_0110_BIOS_NOT_READY" enabled
 *       and only GROUP(0/3/4/8) are configured for now
 */
// LD8
#define NCT6116D_GPIO0_MFUNC_LD8_CRE	0xE0
#define NCT6116D_GPIO3_MFUNC_LD8_CRE	0xE3
#define NCT6116D_GPIO4_MFUNC_LD8_CRE	0xE4
#define NCT6116D_GPIO8_MFUNC_LD8_CRE	0xE9
// LDF
#define NCT6116D_GPIO0_PPOD_LDF_CRE		0xE0
#define NCT6116D_GPIO3_PPOD_LDF_CRE		0xE3
#define NCT6116D_GPIO4_PPOD_LDF_CRE		0xE4
#define NCT6116D_GPIO8_PPOD_LDF_CRE		0xE8


void nct6116d_set_gpio_use_sel(int cmd, int pin);
void nct6116d_set_gp_io_sel(int cmd, int pin);
void nct6116d_set_gp_lvl(int cmd, int pin);
void nct6116d_set_gpi_inv(int cmd, int pin);
u8 nct6116d_get_gpio_use_sel(int port);
u8 nct6116d_get_gp_io_sel(int port);
u8 nct6116d_get_gp_lvl(int port);
u8 nct6116d_get_gpi_inv(int port);


#endif /* _NCT6779D_H_ */
