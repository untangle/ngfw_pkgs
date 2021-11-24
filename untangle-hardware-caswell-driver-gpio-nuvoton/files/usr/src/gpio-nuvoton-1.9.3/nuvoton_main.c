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
#include <linux/device.h>
#include <linux/miscdevice.h>
#include <linux/string.h>
#include <linux/pci.h>
#include <linux/hwmon-sysfs.h>
#include <linux/ioport.h>

#include "nct6775f.h"
#include "nct6776f.h"
#include "nct6779d.h"
#include "nct6104d.h"
#include "nct6116d.h"
#include "nct6796d.h"
#include "nct5581d.h"
#include "nuvoton_main.h"

static gpio_priv_t	g_priv;
#define GPIO_NAME "nuvoton GPIO"
#define PFX GPIO_NAME ": "

static struct SIO_DEVICE sio_device_tbl [] = {
	{ SIO_PRIV(0xB47, "NCT6775F", 9) },
	{ SIO_PRIV(0xC33, "NCT6776F", 9) },
	{ SIO_PRIV(0xC56, "NCT6779D", 8) },
	{ SIO_PRIV(0xC45, "NCT6104D", 7) },
	{ SIO_PRIV(0xD28, "NCT6116D", 8) },
	{ SIO_PRIV(0xD42, "NCT6796D", 9) },
	{ SIO_PRIV(0xD42, "NCT5581D", 8) },
	{ 0 },
};

void nuvoton_enter_ext_mode(void)
{
	outb(0x87, EFER);
	outb(0x87, EFER);
}

void nuvoton_leave_ext_mode(void)
{
	outb(0xAA, EFER);
}

void nuvoton_access_device(u8 ld)
{
	outb(CR7, EFIR);
	outb(ld, EFDR);
}

static inline void
superio_outb(int ioreg, int reg, int val)
{
	outb(reg, ioreg);
	outb(val, ioreg + 1);
}

static inline int
superio_inb(int ioreg, int reg)
{
	outb(reg, ioreg);
	return inb(ioreg + 1);
}

static int request_io_port(int io_port)
{
	int request_timeout = 6500;
	int ret = 0;

	do {
		if (request_region(io_port, 1, GPIO_NAME)) {
			break;
		} else if (request_timeout > 0) {
			request_timeout--;
		}
	} while (request_timeout > 0);

	if (request_timeout == 0) {
		printk(KERN_ERR PFX "I/O address 0x%04x already in use\n", io_port);
		ret = -EIO;
	}

	return ret;
}

#if ( LINUX_VERSION_CODE > KERNEL_VERSION(2,6,18) )
static ssize_t nuvoton_gpio_sysfs_store(struct device *dev, struct device_attribute *attr, const char *buf, size_t count)
{
	struct sensor_device_attribute	*sda = to_sensor_dev_attr(attr);
	unsigned long			cmd;
	unsigned long			pin;

	if (request_io_port(EFER)) {
		return -EIO;
	}

	if (*buf != '0' || (buf[1] != 'x' && buf[1] != 'X')) {
		sscanf(buf, "%lu %lu" , &pin, &cmd);
	} else if (buf[1] == 'x') {
		sscanf(buf, "0x%lx 0x%lx", &pin, &cmd);
	} else {
		sscanf(buf, "0X%lx 0X%lx", &pin, &cmd);
	}

	switch (sda->index) {
	case SELECT_OPT:
		g_priv.ops.set_select(cmd, pin);
		break;
	case OUTPUT_OPT:
		g_priv.ops.set_output(cmd, pin);
		break;
	case DIRECTION_OPT:
		g_priv.ops.set_direction(cmd, pin);
		break;
	case INVERSE_OPT:
		g_priv.ops.set_inv(cmd, pin);
		break;
	}

	release_region(EFER, 1);

	return count;
}

static ssize_t nuvoton_gpio_sysfs_show(struct device *dev, struct device_attribute *attr, char *buf)
{
	struct sensor_device_attribute	*sda = to_sensor_dev_attr(attr);
	u16				val = 0;
	int				i;
	ssize_t				len = 0;

	if (request_io_port(EFER)) {
		return -EIO;
	}

	switch (sda->index) {
	case SELECT_OPT:
		if (g_priv.sio_priv_index == 0) {
			val = (g_priv.ops.get_select(6) & 0x1E) << 5 | (g_priv.ops.get_select(2) & 0x0F) << 2 | (g_priv.ops.get_select(0) & 0x04) >> 2 | (g_priv.ops.get_select(0) & 0x02);
			len += sprintf(buf, "GPIO Ports[9-0]:\t0x%02x\n", val);
		} else if (g_priv.sio_priv_index == 1) {
			val = ((g_priv.ops.get_select(8) & 0x03) << 8) | (g_priv.ops.get_select(1) & 0xFE) | (g_priv.ops.get_select(0) & 0x02) >> 1 ;
			len += sprintf(buf, "GPIO Ports[9-0]:\t0x%02x\n", val);
		} else if (g_priv.sio_priv_index == 2) {
			val = ((g_priv.ops.get_select(8) & 0x01) << 8) | (g_priv.ops.get_select(7) & 0xFE) | ((g_priv.ops.get_select(0) & 0x02) >> 1);
			len += sprintf(buf, "GPIO Ports[8-0]:\t0x%03x\n", val);
		} else if (g_priv.sio_priv_index == 3) {
			val = ((g_priv.ops.get_select(7) & 0xff));
			len += sprintf(buf, "GPIO Ports[7-0]:\t0x%02x\n", val);
		} 
		else if (g_priv.sio_priv_index == 4) {
			val = (g_priv.ops.get_select(8) << 8 | g_priv.ops.get_select(0));
			len += sprintf(buf, "GPIO Ports[8-0]:\t0x%03x\n", val);
		}
		else if (g_priv.sio_priv_index == 5) {
			val = ((g_priv.ops.get_select(0) & 0x02) >> 1) | ((g_priv.ops.get_select(7) & 0x80) >> 7)
                            | ((g_priv.ops.get_select(2) & 0x0f) << 2) | ((g_priv.ops.get_select(0) & 0x07) << 6);
			len += sprintf(buf, "GPIO Ports[8-0]:\t0x%03x\n", val);
		}
		else if (g_priv.sio_priv_index == 6) {
			val = (g_priv.ops.get_select(7) << 4 | g_priv.ops.get_select(2));
			len += sprintf(buf, "GPIO Ports[8-2]:\t0x%03x\n", val);
		}
		break;
	case OUTPUT_OPT:
		for (i = 0; i <= sio_device_tbl[g_priv.sio_priv_index].ports; i++) {
			if (g_priv.sio_priv_index == 6) {
				if (i == 0) {
					i = 2; //Start GPIO is group2
				}
				if (i == 4 || i == 6)
					continue;
			}
			val = g_priv.ops.get_output(i);
			len += sprintf(buf, "%sGPIO Port%d:\t0x%02x\n", buf, i, val);
		}
		break;
	case INPUT_OPT:
		for (i = 0; i <= sio_device_tbl[g_priv.sio_priv_index].ports; i++) {
			if (g_priv.sio_priv_index == 6) {
				if (i == 0) {
					i = 2; //Start GPIO is group2
				}
				if (i == 4 || i == 6)
					continue;
			}
			val = g_priv.ops.get_output(i);
			len += sprintf(buf, "%sGPIO Port%d:\t0x%02x\n", buf, i, val);
		}
		break;
	case DIRECTION_OPT:
		for (i = 0; i <= sio_device_tbl[g_priv.sio_priv_index].ports; i++) {
			if (g_priv.sio_priv_index == 6) {
				if (i == 0) {
					i = 2; //Start GPIO is group2
				}
				if (i == 4 || i == 6)
					continue;
			}
			val = g_priv.ops.get_direction(i);
			len += sprintf(buf, "%sGPIO Port%d:\t0x%02x\n", buf, i, val);
		}
		break;
	case INVERSE_OPT:
		for (i = 0; i <= sio_device_tbl[g_priv.sio_priv_index].ports; i++) {
			if (g_priv.sio_priv_index == 6) {
				if (i == 0) {
					i = 2; //Start GPIO is group2
				}
				if (i == 4 || i == 6)
					continue;
			}
			val = g_priv.ops.get_inv(i);
			len += sprintf(buf, "%sGPIO Port%d:\t0x%02x\n", buf, i, val);
		}
		break;
	}

	release_region(EFER, 1);

	return len;
}

#define GPIO_ENTRY_RO(name, cmd_idx) static SENSOR_DEVICE_ATTR(name, S_IRUGO, nuvoton_gpio_sysfs_show, NULL, cmd_idx)
#define GPIO_ENTRY_RW(name, cmd_idx) static SENSOR_DEVICE_ATTR(name, S_IRUGO | S_IWUSR, nuvoton_gpio_sysfs_show, nuvoton_gpio_sysfs_store, cmd_idx)

GPIO_ENTRY_RW(select, SELECT_OPT);
GPIO_ENTRY_RW(output, OUTPUT_OPT);
GPIO_ENTRY_RO(input, INPUT_OPT);
GPIO_ENTRY_RW(direction, DIRECTION_OPT);
GPIO_ENTRY_RW(inverse, INVERSE_OPT);

static struct attribute *gpio_attributes[] = {
	&sensor_dev_attr_select.dev_attr.attr,
	&sensor_dev_attr_output.dev_attr.attr,
	&sensor_dev_attr_input.dev_attr.attr,
	&sensor_dev_attr_direction.dev_attr.attr,
	&sensor_dev_attr_inverse.dev_attr.attr,
	NULL
};

#else
static ssize_t gpio_sysfs_show_input(struct class_device *dev, char *buf)
{
	u8	val = 0;
	int	i;
	ssize_t	len = 0;

	if (request_io_port(EFER)) {
		return -EIO;
	}

	for (i = 0; i <= sio_device_tbl[g_priv.sio_priv_index].ports; i++) {
		if (g_priv.sio_priv_index == 6) {
			if (i == 0) {
				i = 2; //Start GPIO is group2
			}
			if (i == 4 || i == 6)
				continue;
		}
		val = g_priv.ops.get_output(i);
		len += sprintf(buf, "%sGPIO Port%d:\t0x%02x\n", buf, i, val);
	}

	release_region(EFER, 1);

	return len;
}
static CLASS_DEVICE_ATTR(input, S_IRUGO, gpio_sysfs_show_input, NULL);

static ssize_t gpio_sysfs_show_output(struct class_device *dev, char *buf)
{
	u8	val = 0;
	int	i;
	ssize_t	len = 0;

	if (request_io_port(EFER)) {
		return -EIO;
	}

	for ( i = 0; i <= sio_device_tbl[g_priv.sio_priv_index].ports; i++) {
		if (g_priv.sio_priv_index == 6) {
			if (i == 0) {
				i = 2; //Start GPIO is group2
			}
			if (i == 4 || i == 6)
				continue;
		}
		val = g_priv.ops.get_output(i);
		len += sprintf(buf, "%sGPIO Port%d:\t0x%02x\n", buf, i, val);
	}

	release_region(EFER, 1);

	return len;
}

static ssize_t gpio_sysfs_store_output(struct class_device *dev, const char *buf, size_t count)
{
	unsigned long	cmd;
	unsigned long	pin;
	char		temp[count];
	char		*tok;

	strncpy(temp, buf, count);
	tok = temp;
	pin = simple_strtoul(strsep(&tok, " "), NULL, 0);
	cmd = simple_strtoul(strsep(&tok, " "), NULL, 0);

	if (request_io_port(EFER)) {
		return -EIO;
	}

	g_priv.ops.set_output(cmd, pin);

	release_region(EFER, 1);

	return count;
}
static CLASS_DEVICE_ATTR(output, S_IRUGO|S_IWUSR, gpio_sysfs_show_output, gpio_sysfs_store_output);

static ssize_t gpio_sysfs_show_select(struct class_device *dev, char *buf)
{
	u16	val = 0;
	ssize_t	len = 0;

	if (request_io_port(EFER)) {
		return -EIO;
	}

		if (g_priv.sio_priv_index == 0) {
			val = (g_priv.ops.get_select(6) & 0x1E) << 5 | (g_priv.ops.get_select(2) & 0x0F) << 2 | (g_priv.ops.get_select(0) & 0x04) >> 2 | (g_priv.ops.get_select(0) & 0x02);
			len += sprintf(buf, "GPIO Ports[9-0]:\t0x%02x\n", val);
		} else if (g_priv.sio_priv_index == 1) {
			val = ((g_priv.ops.get_select(8) & 0x03) << 8) | (g_priv.ops.get_select(1) & 0xFE) | (g_priv.ops.get_select(0) & 0x02) >> 1 ;
			len += sprintf(buf, "GPIO Ports[9-0]:\t0x%02x\n", val);
		} else if (g_priv.sio_priv_index == 2) {
			val = ((g_priv.ops.get_select(8) & 0x01) << 8) | (g_priv.ops.get_select(7) & 0xFE) | ((g_priv.ops.get_select(0) & 0x02) >> 1);
			len += sprintf(buf, "GPIO Ports[8-0]:\t0x%03x\n", val);
		} else if (g_priv.sio_priv_index == 3) {
			val = ((g_priv.ops.get_select(7) & 0xff));
			len += sprintf(buf, "GPIO Ports[7-0]:\t0x%02x\n", val);
		}
		else if (g_priv.sio_priv_index == 4) {
			val = ((g_priv.ops.get_select(8) & 0xff));
			len += sprintf(buf, "GPIO Ports[8-0]:\t0x%02x\n", i, val);
		}
		else if (g_priv.sio_priv_index == 5) {
			val = ((g_priv.ops.get_select(0) & 0x02) >> 1) | ((g_priv.ops.get_select(7) & 0x80) >> 7)
                            | ((g_priv.ops.get_select(2) & 0x0f) << 2) | ((g_priv.ops.get_select(0) & 0x07) << 6);
			len += sprintf(buf, "GPIO Ports[8-0]:\t0x%03x\n", val);
		}
		else if (g_priv.sio_priv_index == 6) {
			val = (g_priv.ops.get_select(7) << 4 | g_priv.ops.get_select(2));
			len += sprintf(buf, "GPIO Ports[8-2]:\t0x%03x\n", val);
		}
	release_region(EFER, 1);
	return len;
}

static ssize_t gpio_sysfs_store_select(struct class_device *dev, const char *buf, size_t count)
{
	unsigned long	cmd;
	unsigned long	pin;
	char		temp[count];
	char		*tok;

	strncpy(temp, buf, count);
	tok = temp;
	pin = simple_strtoul(strsep(&tok, " "), NULL, 0);
	cmd = simple_strtoul(strsep(&tok, " "), NULL, 0);

	if (request_io_port(EFER)) {
		return -EIO;
	}

	g_priv.ops.set_select(cmd, pin);

	release_region(EFER, 1);

	return count;
}
static CLASS_DEVICE_ATTR(select, S_IRUGO|S_IWUSR, gpio_sysfs_show_select, gpio_sysfs_store_select);

static ssize_t gpio_sysfs_show_direction(struct class_device *dev, char *buf)
{
	u8	val = 0;
	int	i;
	ssize_t	len = 0;

	if (request_io_port(EFER)) {
		return -EIO;
	}

	for (i = 0; i <= sio_device_tbl[g_priv.sio_priv_index].ports; i++) {
		if (g_priv.sio_priv_index == 6) {
			if (i == 0) {
				i = 2; //Start GPIO is group2
			}
			if (i == 4 || i == 6)
				continue;
		}
		g_priv.ops.get_direction(i);
		len += sprintf(buf, "%sGPIO Port%d:\t0x%02x\n", buf, i,val);
	}

	release_region(EFER, 1);

	return len;
}

static ssize_t gpio_sysfs_store_direction(struct class_device *dev, const char *buf, size_t count)
{
	unsigned long	cmd;
	unsigned long	pin;
	char		temp[count];
	char		*tok;

	strncpy(temp, buf, count);
	tok = temp;
	pin = simple_strtoul(strsep(&tok, " "), NULL, 0);
	cmd = simple_strtoul(strsep(&tok, " "), NULL, 0);

	if (request_io_port(EFER)) {
		return -EIO;
	}

	g_priv.ops.set_direction(cmd, pin);

	release_region(EFER, 1);

	return count;
}
static CLASS_DEVICE_ATTR(direction, S_IRUGO|S_IWUSR, gpio_sysfs_show_direction, gpio_sysfs_store_direction);

static ssize_t gpio_sysfs_show_inverse(struct class_device *dev, char *buf)
{
	u8	val = 0;
	int	i;
	ssize_t	len = 0;

	if (request_io_port(EFER)) {
		return -EIO;
	}

	for (i = 0; i <= sio_device_tbl[g_priv.sio_priv_index].ports; i++) {
		if (g_priv.sio_priv_index == 6) {
			if (i == 0) {
				i = 2; //Start GPIO is group2
			}
			if (i == 4 || i == 6)
				continue;
		}
		val = g_priv.ops.get_inv(i);
		len += sprintf(buf, "%sGPIO Port%d:\t0x%02x\n", buf, i,val);
	}

	release_region(EFER, 1);

	return len;
}

static ssize_t gpio_sysfs_store_inverse(struct class_device *dev, const char *buf, size_t count)
{
	unsigned long	cmd;
	unsigned long	pin;
	char		temp[count];
	char		*tok;

	strncpy(temp, buf, count);
	tok = temp;
	pin = simple_strtoul(strsep(&tok, " "), NULL, 0);
	cmd = simple_strtoul(strsep(&tok, " "), NULL, 0);

	if (request_io_port(EFER)) {
		return -EIO;
	}

	g_priv.ops.set_inv(cmd, pin);

	release_region(EFER, 1);

	return count;
}
static CLASS_DEVICE_ATTR(inverse, S_IRUGO|S_IWUSR, gpio_sysfs_show_inverse, gpio_sysfs_store_inverse);

static struct attribute *gpio_attributes[] = {
	&class_device_attr_input.attr,
	&class_device_attr_output.attr,
	&class_device_attr_select.attr,
	&class_device_attr_direction.attr,
	&class_device_attr_inverse.attr,
	NULL
};
#endif

static struct attribute_group gpio_defattr_group = {
		.attrs = gpio_attributes,
};

#if ( LINUX_VERSION_CODE > KERNEL_VERSION(2,6,18) )
int gpio_register_fs(struct device *dev)
{
	int ret;

	ret = sysfs_create_group(&dev->kobj, &gpio_defattr_group);

	return ret;
}

void gpio_unregister_fs(struct device *dev)
{
	sysfs_remove_group(&dev->kobj, &gpio_defattr_group);
}
#else
int gpio_register_fs(struct class_device *class_dev)
{
	int ret;

	ret = sysfs_create_group(&class_dev->kobj,&gpio_defattr_group);

	return ret;
}

void gpio_unregister_fs(struct class_device *class_dev)
{
	sysfs_remove_group(&class_dev->kobj, &gpio_defattr_group);
}
#endif

/*
 * On older chips, only registers 0x50-0x5f are banked.
 * On more recent chips, all registers are banked.
 * Assume that is the case and set the bank number for each access.
 * Cache the bank number so it only needs to be set if it changes.
 */
static inline void nct6775_set_bank(int addr, u16 reg)
{
	u8 bank = reg >> 8;

	outb_p(NCT6775_REG_BANK, addr + ADDR_REG_OFFSET);
	outb_p(bank, addr + DATA_REG_OFFSET);
}

static u16 nct6775_read_value(int addr, u16 reg)
{
	int res;

	nct6775_set_bank(addr, reg);
	outb_p(reg & 0xff, addr + ADDR_REG_OFFSET);
	res = inb_p(addr + DATA_REG_OFFSET);

	return res;
}

int get_io_mapping_addr(void) {

	u16 val;
	int addr;

	nuvoton_enter_ext_mode();

	/* Find the HWM I/O address */
	nuvoton_access_device(NCT6775_LD_HWM);
	val = (superio_inb(EFER, SIO_REG_ADDR) << 8)
		| superio_inb(EFER, SIO_REG_ADDR + 1);
	addr = val & IOREGION_ALIGNMENT;
	if (addr == 0) {
		printk("Refusing to enable a Super-I/O device with a base I/O port 0\n");
		nuvoton_leave_ext_mode();
		return -ENODEV;
	}

	/* Activate logical device if needed */
	val = superio_inb(EFIR, SIO_REG_ENABLE);
	if (!(val & 0x01)) {
		printk("Forcibly enabling Super-I/O. Sensor is probably unusable.\n");
		superio_outb(EFIR, SIO_REG_ENABLE, val | 0x01);
	}
	/* HWM base address + IOREGION */
	addr = addr + IOREGION_OFFSET;

	nuvoton_leave_ext_mode();

	return addr;
}

u16 nuvoton_get_devid(void)
{
	u16 val = 0;

	nuvoton_enter_ext_mode();

	val = (superio_inb(EFER, SIO_REG_DEVID) << 4) |
		(superio_inb(EFER, SIO_REG_DEVID + 1) >> 4);
	nuvoton_leave_ext_mode();

	return val;
}
EXPORT_SYMBOL(nuvoton_get_devid);

void nct6775f_gpio_init(void)
{
	g_priv.ops.set_select = nct6775f_set_gpio_use_sel;
	g_priv.ops.set_direction = nct6775f_set_gp_io_sel;
	g_priv.ops.set_output = nct6775f_set_gp_lvl;
	g_priv.ops.set_inv = nct6775f_set_gpi_inv;

	g_priv.ops.get_select = nct6775f_get_gpio_use_sel;
	g_priv.ops.get_direction = nct6775f_get_gp_io_sel;
	g_priv.ops.get_output = nct6775f_get_gp_lvl;
	g_priv.ops.get_inv = nct6775f_get_gpi_inv;
}

void nct6776f_gpio_init(void)
{
	g_priv.ops.set_select = nct6776f_set_gpio_use_sel;
	g_priv.ops.set_direction = nct6776f_set_gp_io_sel;
	g_priv.ops.set_output = nct6776f_set_gp_lvl;
	g_priv.ops.set_inv = nct6776f_set_gpi_inv;

	g_priv.ops.get_select = nct6776f_get_gpio_use_sel;
	g_priv.ops.get_direction = nct6776f_get_gp_io_sel;
	g_priv.ops.get_output = nct6776f_get_gp_lvl;
	g_priv.ops.get_inv = nct6776f_get_gpi_inv;
}

void nct6779d_gpio_init(void)
{
	g_priv.ops.set_select = nct6779d_set_gpio_use_sel;
	g_priv.ops.set_direction = nct6779d_set_gp_io_sel;
	g_priv.ops.set_output = nct6779d_set_gp_lvl;
	g_priv.ops.set_inv = nct6779d_set_gpi_inv;

	g_priv.ops.get_select = nct6779d_get_gpio_use_sel;
	g_priv.ops.get_direction = nct6779d_get_gp_io_sel;
	g_priv.ops.get_output = nct6779d_get_gp_lvl;
	g_priv.ops.get_inv = nct6779d_get_gpi_inv;
}

void nct6104d_gpio_init(void)
{
	g_priv.ops.set_select = nct6104d_set_gpio_use_sel;
	g_priv.ops.set_direction = nct6104d_set_gp_io_sel;
	g_priv.ops.set_output = nct6104d_set_gp_lvl;
	g_priv.ops.set_inv = nct6104d_set_gpi_inv;

	g_priv.ops.get_select = nct6104d_get_gpio_use_sel;
	g_priv.ops.get_direction = nct6104d_get_gp_io_sel;
	g_priv.ops.get_output = nct6104d_get_gp_lvl;
	g_priv.ops.get_inv = nct6104d_get_gpi_inv;
}

void nct6116d_gpio_init(void)
{
	g_priv.ops.set_select = nct6116d_set_gpio_use_sel;
	g_priv.ops.set_direction = nct6116d_set_gp_io_sel;
	g_priv.ops.set_output = nct6116d_set_gp_lvl;
	g_priv.ops.set_inv = nct6116d_set_gpi_inv;

	g_priv.ops.get_select = nct6116d_get_gpio_use_sel;
	g_priv.ops.get_direction = nct6116d_get_gp_io_sel;
	g_priv.ops.get_output = nct6116d_get_gp_lvl;
	g_priv.ops.get_inv = nct6116d_get_gpi_inv;
}

void nct6796d_gpio_init(void)
{
	g_priv.ops.set_select = nct6796d_set_gpio_use_sel;
	g_priv.ops.set_direction = nct6796d_set_gp_io_sel;
	g_priv.ops.set_output = nct6796d_set_gp_lvl;
	g_priv.ops.set_inv = nct6796d_set_gpi_inv;

	g_priv.ops.get_select = nct6796d_get_gpio_use_sel;
	g_priv.ops.get_direction = nct6796d_get_gp_io_sel;
	g_priv.ops.get_output = nct6796d_get_gp_lvl;
	g_priv.ops.get_inv = nct6796d_get_gpi_inv;
}

void nct5581d_gpio_init(void)
{
	g_priv.ops.set_select = nct5581d_set_gpio_use_sel;
	g_priv.ops.set_direction = nct5581d_set_gp_io_sel;
	g_priv.ops.set_output = nct5581d_set_gp_lvl;
	g_priv.ops.set_inv = nct5581d_set_gpi_inv;

	g_priv.ops.get_select = nct5581d_get_gpio_use_sel;
	g_priv.ops.get_direction = nct5581d_get_gp_io_sel;
	g_priv.ops.get_output = nct5581d_get_gp_lvl;
	g_priv.ops.get_inv = nct5581d_get_gpi_inv;
}

int nuvoton_match(void)
{
	u8 cr_fb;
	u16 val;
	int i;
	int addr;

	val = nuvoton_get_devid();

	for (i = 0; i < sizeof(sio_device_tbl)/sizeof(struct SIO_DEVICE); i++) {
		if (val == sio_device_tbl[i].devid) {
			/* NCT5581D and NCT6796D has same device id
			 * So Nuvoton FAE say Bank 0 FBh value can judge two chipsets
			 * NCT6796D Bank 0 FBh Bit3=0 Bit4=0
			 * NCT5581D Bank 0 FBh Bit3=1 Bit4=1
			 */
			if (val == 0xD42) {
				/* Get Bank 0 FBh value */
				addr = get_io_mapping_addr();
				cr_fb = nct6775_read_value(addr, 0xFB);
				if (cr_fb & NCT5581D_MASK) {
					g_priv.sio_priv_index = 6;
				} else {
					g_priv.sio_priv_index = 5;
				}
			} else {
				g_priv.sio_priv_index = i;
			}
		}
	}
	printk("[GPIO-NUVOTON]: %s detect !\n", sio_device_tbl[g_priv.sio_priv_index].devname);

	switch (g_priv.sio_priv_index) {
	case 0:
		nct6775f_gpio_init();
		break;
	case 1:
		nct6776f_gpio_init();
		break;
	case 2:
		nct6779d_gpio_init();
		break;
	case 3:
		nct6104d_gpio_init();
		break;
	case 4:
		nct6116d_gpio_init();
		break;
	case 5:
		nct6796d_gpio_init();
		break;
	case 6:
		nct5581d_gpio_init();
		break;
	default:
		return -1;
	}

	return val;
}
EXPORT_SYMBOL(nuvoton_match);

static int __init nuvoton_gpio_init(void)
{
	int			ret = 0;
	struct miscdevice	*mdev;

	printk("[GPIO-NUVOTON]: CASwell Nuvoton Super I/O GPIO Driver (%s) Initialized...\n", DRV_VERSION);

	ret = nuvoton_match();
	if (ret == -1){
		printk("[GPIO-NUVOTON]: Can't Detect Match Device\n");
		goto err_match;
	}

	mdev = kzalloc(sizeof(struct miscdevice), GFP_KERNEL);
	mdev->name = DRIVERNAME;
	mdev->minor = MISC_DYNAMIC_MINOR;
	mdev->fops = NULL;
	ret = misc_register(mdev);

	if (ret) {
		printk("[GPIO-NUVOTON]: Unable to register misc device\n");
		goto err_misc;
	}

	g_priv.mdev = mdev;
#if ( LINUX_VERSION_CODE > KERNEL_VERSION(2,6,18) )
	gpio_register_fs(g_priv.mdev->this_device);
#else
	gpio_register_fs(g_priv.mdev->class);
#endif

	return ret;

err_misc:
	misc_deregister(mdev);
err_match:
	return -ENODEV;;
}

static void __exit nuvoton_gpio_exit(void)
{
#if ( LINUX_VERSION_CODE > KERNEL_VERSION(2,6,18) )
	gpio_unregister_fs(g_priv.mdev->this_device);
#else
	gpio_unregister_fs(g_priv.mdev->class);
#endif
	misc_deregister(g_priv.mdev);
}

/*
 * 2-Wire bus emulation using GPIO 
 */
int cw_gpio_get_value_by_nctsio(int __pin)
{
	int buf, ret = 0xff;
	int related_port = __pin / 10;
	int related_pin = __pin % 10;

	buf = (int) g_priv.ops.get_output(related_port);

	ret = (0x00000001 & (buf >> related_pin));

	// printk("%s: pin=%d/%d, buf/ret=%d/%d\n", __func__, __pin, related_pin, buf, ret);

	return ret;
}

int cw_gpio_get_direction_by_nctsio(int __pin)
{
	int buf, ret = 0xff;
	int related_port = __pin / 10;
	int related_pin = __pin % 10;

	buf = (int) g_priv.ops.get_direction(related_port);

	ret = (0x00000001 & (buf >> related_pin));

	// printk("%s: pin=%d/%d, buf/ret=%d/%d\n", __func__, __pin, related_pin, buf, ret);

	return ret;
}

void cw_gpio_set_value_by_nctsio(int __pin, int __val)
{
	g_priv.ops.set_output(__val, __pin);
}

void cw_gpio_set_direction_by_nctsio(int __pin, int __val)
{
	g_priv.ops.set_direction(__val, __pin);
}

EXPORT_SYMBOL(cw_gpio_set_value_by_nctsio);
EXPORT_SYMBOL(cw_gpio_get_value_by_nctsio);
EXPORT_SYMBOL(cw_gpio_set_direction_by_nctsio);
EXPORT_SYMBOL(cw_gpio_get_direction_by_nctsio);
/* END of bitbanging */

MODULE_AUTHOR("Alan Yu <alan.yu@cas-well.com>");
MODULE_DESCRIPTION("Nuvoton Super I/O GPIO Driver");
MODULE_LICENSE("GPL");

module_init(nuvoton_gpio_init);
module_exit(nuvoton_gpio_exit);
