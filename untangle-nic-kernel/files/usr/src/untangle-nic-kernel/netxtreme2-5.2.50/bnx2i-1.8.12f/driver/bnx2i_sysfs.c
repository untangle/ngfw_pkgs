/* bnx2i_sysfs.c: Broadcom NetXtreme II iSCSI driver.
 *
 * Copyright (c) 2006 - 2009 Broadcom Corporation
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation.
 *
 * Written by: Anil Veerabhadrappa (anilgv@broadcom.com)
 */

#include "bnx2i.h"
#include <linux/ethtool.h>

#ifdef _SYSFS_INCL_

#define BNX2I_SYSFS_VERSION	0x2


static ssize_t bnx2i_show_net_if_name(struct class_device *cdev, char *buf)
{
	struct bnx2i_hba *hba =
		container_of(cdev, struct bnx2i_hba, class_dev);

	return sprintf(buf, "%s\n", hba->netdev->name);
}

static ssize_t bnx2i_show_sq_info(struct class_device *cdev, char *buf)
{
	struct bnx2i_hba *hba =
		container_of(cdev, struct bnx2i_hba, class_dev);

	return sprintf(buf, "0x%x\n", hba->max_sqes);
}

static ssize_t bnx2i_set_sq_info(struct class_device *cdev,
				 const char *buf, size_t count)
{
	struct bnx2i_hba *hba =
		container_of(cdev, struct bnx2i_hba, class_dev);
	u32 val;
	int max_sq_size;

	if (test_bit(BNX2I_NX2_DEV_57710, &hba->cnic_dev_type))
		max_sq_size = BNX2I_5770X_SQ_WQES_MAX;
	else
		max_sq_size = BNX2I_570X_SQ_WQES_MAX;

	if (sscanf(buf, " 0x%x ", &val) > 0) {
		if ((val >= BNX2I_SQ_WQES_MIN) && (val <= max_sq_size ))
			hba->max_sqes = val;
	}
	return count;
}

static ssize_t bnx2i_show_rq_info(struct class_device *cdev, char *buf)
{
	struct bnx2i_hba *hba =
		container_of(cdev, struct bnx2i_hba, class_dev);

	return sprintf(buf, "0x%x\n", hba->max_rqes);
}

static ssize_t bnx2i_set_rq_info(struct class_device *cdev, const char *buf,
							size_t count)
{
	u32 val;
	struct bnx2i_hba *hba =
		container_of(cdev, struct bnx2i_hba, class_dev);

	if (sscanf(buf, " 0x%x ", &val) > 0) {
		if ((val >= BNX2I_RQ_WQES_MIN) &&
		    (val <= BNX2I_RQ_WQES_MAX)) {
			hba->max_rqes = val;
		}
	}
	return count;
}


static ssize_t bnx2i_show_ccell_info(struct class_device *cdev, char *buf)
{
	struct bnx2i_hba *hba =
		container_of(cdev, struct bnx2i_hba, class_dev);

	return sprintf(buf, "0x%x\n", hba->num_ccell);
}

static ssize_t bnx2i_set_ccell_info(struct class_device *cdev,
				    const char *buf, size_t count)
{
	u32 val;
	struct bnx2i_hba *hba =
		container_of(cdev, struct bnx2i_hba, class_dev);

	if (sscanf(buf, " 0x%x ", &val) > 0) {
		if ((val >= BNX2I_CCELLS_MIN) &&
		    (val <= BNX2I_CCELLS_MAX)) {
			hba->num_ccell = val;
		}
	}
	return count;
}


static ssize_t bnx2i_read_pci_trigger_reg(struct class_device *cdev,
					  char *buf)
{
	u32 reg_val;
	struct bnx2i_hba *hba =
		container_of(cdev, struct bnx2i_hba, class_dev);

	if (!hba->regview)
		return 0;

#define PCI_EVENT_TRIGGER_REG	0xCAC	/* DMA WCHAN STAT10 REG */
	reg_val = readl(hba->regview + PCI_EVENT_TRIGGER_REG);
	return sprintf(buf, "0x%x\n", reg_val);
}


static CLASS_DEVICE_ATTR (net_if_name, S_IRUGO,
			 bnx2i_show_net_if_name, NULL);
static CLASS_DEVICE_ATTR (sq_size, S_IRUGO | S_IWUSR,
			 bnx2i_show_sq_info, bnx2i_set_sq_info);
static CLASS_DEVICE_ATTR (rq_size, S_IRUGO | S_IWUSR,
			 bnx2i_show_rq_info, bnx2i_set_rq_info);
static CLASS_DEVICE_ATTR (num_ccell, S_IRUGO | S_IWUSR,
			 bnx2i_show_ccell_info, bnx2i_set_ccell_info);
static CLASS_DEVICE_ATTR (pci_trigger, S_IRUGO,
			 bnx2i_read_pci_trigger_reg, NULL);


static struct class_device_attribute *bnx2i_class_attributes[] = {
	&class_device_attr_net_if_name,
	&class_device_attr_sq_size,
	&class_device_attr_rq_size,
	&class_device_attr_num_ccell,
	&class_device_attr_pci_trigger,
};

static void bnx2i_sysfs_release(struct class_device *class_dev)
{
}

struct class_device port_class_dev;


static struct class bnx2i_class = {
	.name	= "bnx2i",
	.release = bnx2i_sysfs_release,
};

int bnx2i_register_sysfs(struct bnx2i_hba *hba)
{
	struct class_device *class_dev = &hba->class_dev;
	char dev_name[BUS_ID_SIZE];
	struct ethtool_drvinfo drv_info;
	u32 bus_no;
	u32 dev_no;
	u32 func_no;
	u32 extra;
	int ret;
	int i;

	if (hba->cnic && hba->cnic->netdev) {
		hba->cnic->netdev->ethtool_ops->get_drvinfo(hba->cnic->netdev,
							    &drv_info);
		sscanf(drv_info.bus_info, "%x:%x:%x.%d",
		       &extra, &bus_no, &dev_no, &func_no);
	}
	class_dev->class = &bnx2i_class;
	class_dev->class_data = hba;
	snprintf(dev_name, BUS_ID_SIZE, "%.2x:%.2x.%.1x",
			 bus_no, dev_no, func_no);
	strlcpy(class_dev->class_id, dev_name, BUS_ID_SIZE);

	ret = class_device_register(class_dev);
	if (ret)
		goto err;

	for (i = 0; i < ARRAY_SIZE(bnx2i_class_attributes); ++i) {
		ret = class_device_create_file(class_dev,
					       bnx2i_class_attributes[i]);
		if (ret)
			goto err_unregister;
	}

	return 0;

err_unregister:
	class_device_unregister(class_dev);
err:
	return ret;
}

void bnx2i_unregister_sysfs(struct bnx2i_hba *hba)
{
	class_device_unregister(&hba->class_dev);
}

int bnx2i_sysfs_setup(void)
{
	int ret;
	ret = class_register(&bnx2i_class);
	return ret;
}

void bnx2i_sysfs_cleanup(void)
{
	class_unregister(&bnx2i_class);
}

#endif
