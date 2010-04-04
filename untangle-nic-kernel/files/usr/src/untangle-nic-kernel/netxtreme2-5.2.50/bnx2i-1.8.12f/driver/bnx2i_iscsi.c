/* bnx2i_iscsi.c: Broadcom NetXtreme II iSCSI driver.
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
#ifdef __VMKLNX__
#include <vmklinux26/vmklinux26_scsi.h>
#include <scsi/iscsi_linux.h>
#endif
#include <scsi/scsi_transport.h>
#ifdef __RHEL54_DUAL_ISCSI_STACK__

#include <scsi/iscsi_if.h>
#include <scsi/iscsi_proto2.h>
#include <scsi/scsi_transport_iscsi2.h>
#include <scsi/libiscsi2.h>
#else
#include <scsi/iscsi_proto.h>
#include <scsi/scsi_transport_iscsi.h>
#endif

#ifdef __RHEL54_DUAL_ISCSI_STACK__
extern struct iscsi_conn;
#endif
static struct bnx2i_conn *bnx2i_get_conn_from_cls_conn(
				struct iscsi_cls_conn *cls_conn)
{
#ifdef __RHEL54_DUAL_ISCSI_STACK__
	struct iscsi_conn *conn = cls_conn->dd_data;
        return (struct bnx2i_conn *) conn->dd_data;
#else
	return (struct bnx2i_conn *) cls_conn->dd_data;
#endif
}

static struct bnx2i_sess *bnx2i_get_sess_from_shost(struct Scsi_Host *shost)
{
#ifdef __RHEL54_DUAL_ISCSI_STACK__
	return (struct bnx2i_sess *) iscsi_host_priv(shost);
#else
	return (struct bnx2i_sess *) iscsi_hostdata(shost->hostdata);
#endif
}

struct scsi_host_template bnx2i_host_template;
struct iscsi_transport bnx2i_iscsi_transport;
struct file_operations bnx2i_mgmt_fops;
extern unsigned int bnx2i_nopout_when_cmds_active;
extern unsigned int tcp_buf_size;
extern unsigned int en_tcp_dack;
extern unsigned int time_stamps;

/*
 * Global endpoint resource info
 */
static void *bnx2i_ep_pages[MAX_PAGES_PER_CTRL_STRUCT_POOL];
static struct list_head bnx2i_free_ep_list;
static struct list_head bnx2i_unbound_ep;
static u32 bnx2i_num_free_ep;
static u32 bnx2i_max_free_ep;
static DEFINE_SPINLOCK(bnx2i_resc_lock); /* protects global resources */
struct tcp_port_mngt bnx2i_tcp_port_tbl;

extern unsigned int sq_size;
extern unsigned int rq_size;


int use_poll_timer = 1;

/* Char device major number */
static int bnx2i_major_no;

static struct io_bdt *bnx2i_alloc_bd_table(struct bnx2i_sess *sess,
					   struct bnx2i_cmd *);

static struct scsi_host_template *
bnx2i_alloc_scsi_host_template(struct bnx2i_hba *hba, struct cnic_dev *cnic);
static void
bnx2i_free_scsi_host_template(struct scsi_host_template *scsi_template);
static struct iscsi_transport *
bnx2i_alloc_iscsi_transport(struct bnx2i_hba *hba, struct cnic_dev *cnic, struct scsi_host_template *);
static void bnx2i_free_iscsi_transport(struct iscsi_transport *iscsi_transport);
static void bnx2i_release_session_resc(struct iscsi_cls_session *cls_session);

#ifdef __VMKLNX__
static void bnx2i_conn_main_worker(unsigned long data);
vmk_int32 bnx2i_get_570x_limit(enum iscsi_param param,
			       TransportParamLimit *limit, vmk_int32 maxListLen);
vmk_int32 bnx2i_get_5771x_limit(enum iscsi_param param,
			        TransportParamLimit *limit,
			        vmk_int32 maxListLen);
extern int bnx2i_cqe_work_pending(struct bnx2i_conn *conn);
#else
#if defined(INIT_DELAYED_WORK_DEFERRABLE) || defined(INIT_WORK_NAR)
static void bnx2i_conn_main_worker(struct work_struct *work);
#else
static void bnx2i_conn_main_worker(void *data);
extern int bnx2i_cqe_work_pending(struct bnx2i_conn *conn);
#endif
#endif	/*__VMKLNX__ */
static void bnx2i_xmit_work_send_cmd(struct bnx2i_conn *conn, struct bnx2i_cmd *cmd);
static void bnx2i_cleanup_task_context(struct bnx2i_sess *sess,
					struct bnx2i_cmd *cmd, int reason);


#ifdef __VMKLNX__
extern int bnx2i_bind_adapter_devices(struct bnx2i_hba *hba);
#endif
void bnx2i_unbind_adapter_devices(struct bnx2i_hba *hba);
static void bnx2i_conn_poll(unsigned long data);

/*
 * iSCSI Session's hostdata organization:
 *
 *    *------------------* <== hostdata_session(host->hostdata)
 *    | ptr to class sess|
 *    |------------------| <== iscsi_hostdata(host->hostdata)
 *    | iscsi_session    |
 *    *------------------*
 */

#define hostdata_privsize(_sz)	(sizeof(unsigned long) + _sz + \
				 _sz % sizeof(unsigned long))
#define hostdata_session(_hostdata) (iscsi_ptr(*(unsigned long *)_hostdata))

#define session_to_cls(_sess) 	hostdata_session(_sess->shost->hostdata)

/**
 * bnx2i_alloc_tcp_port - allocates a tcp port from the free list
 *
 * assumes this function is called with 'bnx2i_resc_lock' held
 **/
#ifndef __VMKLNX__
static u16 bnx2i_alloc_tcp_port(void)
{
	u16 tcp_port;

	if (!bnx2i_tcp_port_tbl.num_free_ports || !bnx2i_tcp_port_tbl.free_q)
		return 0;

	tcp_port = bnx2i_tcp_port_tbl.free_q[bnx2i_tcp_port_tbl.cons_idx];
	bnx2i_tcp_port_tbl.cons_idx++;
	bnx2i_tcp_port_tbl.cons_idx %= bnx2i_tcp_port_tbl.max_idx;
	bnx2i_tcp_port_tbl.num_free_ports--;

	return tcp_port;
}
#endif


/**
 * bnx2i_free_tcp_port - Frees the given tcp port back to free pool
 *
 * @port: 		tcp port number being freed
 *
 * assumes this function is called with 'bnx2i_resc_lock' held
 **/
static void bnx2i_free_tcp_port(u16 port)
{
	if (!bnx2i_tcp_port_tbl.free_q)
		return;

	bnx2i_tcp_port_tbl.free_q[bnx2i_tcp_port_tbl.prod_idx] = port;
	bnx2i_tcp_port_tbl.prod_idx++;
	bnx2i_tcp_port_tbl.prod_idx %= bnx2i_tcp_port_tbl.max_idx;
	bnx2i_tcp_port_tbl.num_free_ports++;
}

/**
 * bnx2i_tcp_port_new_entry - place 'bnx2id' allocated tcp port number
 *		to free list
 *
 * @port: 		tcp port number being added to free pool
 *
 * 'bnx2i_resc_lock' is held while operating on global tcp port table
 **/
void bnx2i_tcp_port_new_entry(u16 tcp_port)
{
	u32 idx = bnx2i_tcp_port_tbl.prod_idx;

	spin_lock(&bnx2i_resc_lock);
	bnx2i_tcp_port_tbl.free_q[idx] = tcp_port;
	bnx2i_tcp_port_tbl.prod_idx++;
	bnx2i_tcp_port_tbl.prod_idx %= bnx2i_tcp_port_tbl.max_idx;
	bnx2i_tcp_port_tbl.num_free_ports++;
	bnx2i_tcp_port_tbl.num_required--;
	spin_unlock(&bnx2i_resc_lock);
}

/**
 * bnx2i_init_tcp_port_mngr - initializes tcp port manager
 *
 */
int bnx2i_init_tcp_port_mngr(void)
{
	int mem_size;
	int rc = 0;

	bnx2i_tcp_port_tbl.num_free_ports = 0;
	bnx2i_tcp_port_tbl.prod_idx = 0;
	bnx2i_tcp_port_tbl.cons_idx = 0;
	bnx2i_tcp_port_tbl.max_idx = 0;
	bnx2i_tcp_port_tbl.num_required = 0;

#define BNX2I_MAX_TCP_PORTS	1024

	bnx2i_tcp_port_tbl.port_tbl_size = BNX2I_MAX_TCP_PORTS;

	mem_size = sizeof(u16) * bnx2i_tcp_port_tbl.port_tbl_size;
	if (bnx2i_tcp_port_tbl.port_tbl_size) {
		bnx2i_tcp_port_tbl.free_q = kmalloc(mem_size, GFP_KERNEL);

		if (bnx2i_tcp_port_tbl.free_q)
			bnx2i_tcp_port_tbl.max_idx =
				bnx2i_tcp_port_tbl.port_tbl_size;
		else
			rc = -ENOMEM;
	}

	return rc;
}


/**
 * bnx2i_cleanup_tcp_port_mngr - frees memory held by global tcp port table
 *
 */
void bnx2i_cleanup_tcp_port_mngr(void)
{
	kfree(bnx2i_tcp_port_tbl.free_q);
	bnx2i_tcp_port_tbl.free_q = NULL;
	bnx2i_tcp_port_tbl.num_free_ports = 0;
}

static int bnx2i_adapter_ready(struct bnx2i_hba *hba)
{
	int retval = 0;

	if (!hba || !test_bit(ADAPTER_STATE_UP, &hba->adapter_state) ||
	    test_bit(ADAPTER_STATE_GOING_DOWN, &hba->adapter_state) ||
	    test_bit(ADAPTER_STATE_LINK_DOWN, &hba->adapter_state))
		retval = -EPERM;
	return retval;
}


/**
 * bnx2i_get_write_cmd_bd_idx - identifies various BD bookmarks for a
 *			scsi write command
 *
 * @cmd:		iscsi cmd struct pointer
 * @buf_off:		absolute buffer offset
 * @start_bd_off:	u32 pointer to return the offset within the BD
 *			indicated by 'start_bd_idx' on which 'buf_off' falls
 * @start_bd_idx:	index of the BD on which 'buf_off' falls
 *
 * identifies & marks various bd info for imm data, unsolicited data
 *	and the first solicited data seq.
 */
static void bnx2i_get_write_cmd_bd_idx(struct bnx2i_cmd *cmd, u32 buf_off,
				       u32 *start_bd_off, u32 *start_bd_idx)
{
	u32 cur_offset = 0;
	u32 cur_bd_idx = 0;
	struct iscsi_bd *bd_tbl;

	if (!cmd->bd_tbl || !cmd->bd_tbl->bd_tbl)
		return;

	bd_tbl = cmd->bd_tbl->bd_tbl;
	if (buf_off) {
		while (buf_off >= (cur_offset + bd_tbl->buffer_length)) {
			cur_offset += bd_tbl->buffer_length;
			cur_bd_idx++;
			bd_tbl++;
		}
	}

	*start_bd_off = buf_off - cur_offset;
	*start_bd_idx = cur_bd_idx;
}

/**
 * bnx2i_setup_write_cmd_bd_info - sets up BD various information for
 *			scsi write command
 *
 * @cmd:		iscsi cmd struct pointer
 *
 * identifies & marks various bd info for immediate data, unsolicited data
 *	and first solicited data seq which includes BD start index & BD buf off
 *	This function takes into account iscsi parameter such as immediate data
 *	and unsolicited data is support on this connection
 *	
 */
static void bnx2i_setup_write_cmd_bd_info(struct bnx2i_cmd *cmd)
{
	struct bnx2i_sess *sess;
	u32 start_bd_offset;
	u32 start_bd_idx; 
	u32 buffer_offset = 0;
	u32 seq_len = 0;
	u32 fbl, mrdsl;
	u32 cmd_len = cmd->req.total_data_transfer_length;

	sess = cmd->conn->sess;

	/* if ImmediateData is turned off & IntialR2T is turned on,
	 * there will be no immediate or unsolicited data, just return.
	 */
	if (sess->initial_r2t && !sess->imm_data)
		return;

	fbl = sess->first_burst_len;
	mrdsl = cmd->conn->max_data_seg_len_xmit;

	/* Immediate data */
	if (sess->imm_data) {
		seq_len = min(mrdsl, fbl);
		seq_len = min(cmd_len, seq_len);
		buffer_offset += seq_len;
	}

	if (seq_len == cmd_len)
		return;

	if (!sess->initial_r2t) {
		if (seq_len >= fbl)
			goto r2t_data;
		seq_len = min(fbl, cmd_len) - seq_len;
		bnx2i_get_write_cmd_bd_idx(cmd, buffer_offset,
					   &start_bd_offset, &start_bd_idx);
		cmd->req.ud_buffer_offset = start_bd_offset;
		cmd->req.ud_start_bd_index = start_bd_idx;
		buffer_offset += seq_len;
	}
r2t_data:
	if (buffer_offset != cmd_len) {
		bnx2i_get_write_cmd_bd_idx(cmd, buffer_offset,
					   &start_bd_offset, &start_bd_idx);
		if ((start_bd_offset > fbl) ||
		    (start_bd_idx > scsi_sg_count(cmd->scsi_cmd))) {
			int i = 0;

			printk(KERN_ALERT "bnx2i- error, buf offset 0x%x "
					  "bd_valid %d use_sg %d\n",
					  buffer_offset, cmd->bd_tbl->bd_valid,
					  scsi_sg_count(cmd->scsi_cmd));
			for (i = 0; i < cmd->bd_tbl->bd_valid; i++)
				printk(KERN_ALERT "bnx2i err, bd[%d]: len %x\n",
						  i, cmd->bd_tbl->bd_tbl[i].\
						  buffer_length);
		}
		cmd->req.sd_buffer_offset = start_bd_offset;
		cmd->req.sd_start_bd_index = start_bd_idx;
	}
}


/**
 * bnx2i_split_bd - splits buffer > 64KB into 32KB chunks
 *
 * @cmd:		iscsi cmd struct pointer
 * @addr: 		base address of the buffer
 * @sg_len: 		buffer length
 * @bd_index: 		starting index into BD table
 *
 * This is not required as driver limits max buffer size of less than 64K by
 *	advertising 'max_sectors' within this limit. 5706/5708 hardware limits
 *	BD length to less than or equal to 0xFFFF 
 **/
static int bnx2i_split_bd(struct bnx2i_cmd *cmd, u64 addr, int sg_len,
			  int bd_index)
{
	struct iscsi_bd *bd = cmd->bd_tbl->bd_tbl;
	int frag_size, sg_frags;

	sg_frags = 0;
	while (sg_len) {
		if (sg_len >= BD_SPLIT_SIZE)
			frag_size = BD_SPLIT_SIZE;
		else
			frag_size = sg_len;
		bd[bd_index + sg_frags].buffer_addr_lo = (u32) addr;
		bd[bd_index + sg_frags].buffer_addr_hi = addr >> 32;
		bd[bd_index + sg_frags].buffer_length = frag_size;
		bd[bd_index + sg_frags].flags = 0;
		if ((bd_index + sg_frags) == 0)
			bd[0].flags = ISCSI_BD_FIRST_IN_BD_CHAIN;
		addr += (u64) frag_size;
		sg_frags++;
		sg_len -= frag_size;
	}
	return sg_frags;
}


/**
 * bnx2i_map_single_buf - maps a single buffer and updates the BD table
 *
 * @hba: 		adapter instance
 * @cmd:		iscsi cmd struct pointer
 *
 */
static int bnx2i_map_single_buf(struct bnx2i_hba *hba,
				       struct bnx2i_cmd *cmd)
{
	struct scsi_cmnd *sc = cmd->scsi_cmd;
	struct iscsi_bd *bd = cmd->bd_tbl->bd_tbl;
	int byte_count;
	int bd_count;
	u64 addr;

	byte_count = scsi_bufflen(sc);
	sc->SCp.dma_handle =
		pci_map_single(hba->pcidev, scsi_sglist(sc),
			       scsi_bufflen(sc), sc->sc_data_direction);
	addr = sc->SCp.dma_handle;

	if (byte_count > MAX_BD_LENGTH) {
		bd_count = bnx2i_split_bd(cmd, addr, byte_count, 0);
	} else {
		bd_count = 1;
		bd[0].buffer_addr_lo = addr & 0xffffffff;
		bd[0].buffer_addr_hi = addr >> 32;
		bd[0].buffer_length = scsi_bufflen(sc);
		bd[0].flags = ISCSI_BD_FIRST_IN_BD_CHAIN |
			      ISCSI_BD_LAST_IN_BD_CHAIN;
	}
	bd[bd_count - 1].flags |= ISCSI_BD_LAST_IN_BD_CHAIN;

	return bd_count;
}


/**
 * bnx2i_map_sg - maps IO buffer and prepares the BD table
 *
 * @hba: 		adapter instance
 * @cmd:		iscsi cmd struct pointer
 *
 * map SG list
 */
static int bnx2i_map_sg(struct bnx2i_hba *hba, struct bnx2i_cmd *cmd)
{
	struct scsi_cmnd *sc = cmd->scsi_cmd;
	struct iscsi_bd *bd = cmd->bd_tbl->bd_tbl;
	struct scatterlist *sg;
	int byte_count = 0;
	int sg_frags;
	int bd_count = 0;
	int sg_count;
	int sg_len;
	u64 addr;
	int i;

	sg = scsi_sglist(sc);
#ifdef __VMKLNX__
	sg_count = scsi_sg_count(sc);
#else
	sg_count = pci_map_sg(hba->pcidev, sg, scsi_sg_count(sc),
			      sc->sc_data_direction);
#endif

	for (i = 0; i < sg_count; i++) {
		sg_len = sg_dma_len(sg);
		addr = sg_dma_address(sg);
		if (sg_len > MAX_BD_LENGTH)
			sg_frags = bnx2i_split_bd(cmd, addr, sg_len,
						  bd_count);
		else {
			sg_frags = 1;
			bd[bd_count].buffer_addr_lo = addr & 0xffffffff;
			bd[bd_count].buffer_addr_hi = addr >> 32;
			bd[bd_count].buffer_length = sg_len;
			bd[bd_count].flags = 0;
			if (bd_count == 0)
				bd[bd_count].flags =
					ISCSI_BD_FIRST_IN_BD_CHAIN;
		}
		byte_count += sg_len;
		sg++;
		bd_count += sg_frags;
	}
	bd[bd_count - 1].flags |= ISCSI_BD_LAST_IN_BD_CHAIN;

	BUG_ON(byte_count != scsi_bufflen(sc));
	return bd_count;
}

/**
 * bnx2i_iscsi_map_sg_list - maps SG list
 *
 * @cmd:		iscsi cmd struct pointer
 *
 * creates BD list table for the command
 */
static void bnx2i_iscsi_map_sg_list(struct bnx2i_hba *hba, struct bnx2i_cmd *cmd)
{
	struct scsi_cmnd *sc = cmd->scsi_cmd;
	int bd_count;

	if (scsi_bufflen(sc)) {
		if (scsi_sg_count(sc))
			bd_count = bnx2i_map_sg(hba, cmd);
		else if (scsi_bufflen(sc))
			bd_count = bnx2i_map_single_buf(hba, cmd);
		else {
			struct iscsi_bd *bd = cmd->bd_tbl->bd_tbl;

			bd_count  = 0;
			bd[0].buffer_addr_lo = bd[0].buffer_addr_hi = 0;
			bd[0].buffer_length = bd[0].flags = 0;
		}
	} else {
		struct iscsi_bd *bd = cmd->bd_tbl->bd_tbl;

		bd_count  = 0;
		bd[0].buffer_addr_lo = bd[0].buffer_addr_hi = 0;
		bd[0].buffer_length = bd[0].flags = 0;
	}

	cmd->bd_tbl->bd_valid = bd_count;
}


/**
 * bnx2i_iscsi_unmap_sg_list - unmaps SG list
 *
 * @cmd:		iscsi cmd struct pointer
 *
 * unmap IO buffers and invalidate the BD table
 */
void bnx2i_iscsi_unmap_sg_list(struct bnx2i_hba *hba, struct bnx2i_cmd *cmd)
{
	struct scsi_cmnd *sc = cmd->scsi_cmd;
#ifndef __VMKLNX__
	struct scatterlist *sg;
#endif

	if (cmd->bd_tbl->bd_valid && sc) {
#ifndef __VMKLNX__
		if (scsi_sg_count(sc)) {
			sg = scsi_sglist(sc);
			pci_unmap_sg(hba->pcidev, sg, scsi_sg_count(sc),
				     sc->sc_data_direction);
		} else {
			pci_unmap_single(hba->pcidev, sc->SCp.dma_handle,
					 scsi_bufflen(sc),
					 sc->sc_data_direction);
		}
#endif
		cmd->bd_tbl->bd_valid = 0;
	}
}



static void bnx2i_setup_cmd_wqe_template(struct bnx2i_cmd *cmd)
{
	memset(&cmd->req, 0x00, sizeof(cmd->req));
	cmd->req.op_code = 0xFF;
	cmd->req.bd_list_addr_lo = (u32) cmd->bd_tbl->bd_tbl_dma;
	cmd->req.bd_list_addr_hi =
		(u32) ((u64) cmd->bd_tbl->bd_tbl_dma >> 32);

}


/**
 * bnx2i_bind_conn_to_iscsi_cid - bind conn structure to 'iscsi_cid'
 *
 * @conn: 		pointer to iscsi connection
 * @iscsi_cid:		iscsi context ID, range 0 - (MAX_CONN - 1)
 *
 * update iscsi cid table entry with connection pointer. This enables
 *	driver to quickly get hold of connection structure pointer in
 *	completion/interrupt thread using iscsi context ID
 */
static int bnx2i_bind_conn_to_iscsi_cid(struct bnx2i_conn *conn,
					 u32 iscsi_cid)
{
	struct bnx2i_hba *hba;

	if (!conn || !conn->sess)
		return -EINVAL;

	hba = conn->sess->hba;

	if (hba && hba->cid_que.conn_cid_tbl[iscsi_cid]) {
		printk(KERN_ERR "bnx2i: conn bind - entry #%d not free\n",
				iscsi_cid);
		return -EBUSY;
	}

	hba->cid_que.conn_cid_tbl[iscsi_cid] = conn;
	return 0;
}


/**
 * bnx2i_get_conn_from_id - maps an iscsi cid to corresponding conn ptr
 * 
 * @hba: 		pointer to adapter instance
 * @iscsi_cid:		iscsi context ID, range 0 - (MAX_CONN - 1)
 */
struct bnx2i_conn *bnx2i_get_conn_from_id(struct bnx2i_hba *hba,
						 u16 iscsi_cid)
{
	if (!hba->cid_que.conn_cid_tbl) {
		printk(KERN_ERR "bnx2i: ERROR - missing conn<->cid table\n");
		return NULL;

	} else if (iscsi_cid >= hba->max_active_conns) {
		printk(KERN_ERR "bnx2i: wrong cid #%d\n", iscsi_cid);
		return NULL;
	}
	return hba->cid_que.conn_cid_tbl[iscsi_cid];
}


/**
 * bnx2i_alloc_iscsi_cid - allocates a iscsi_cid from free pool
 *
 * @hba: 		pointer to adapter instance
 */
static u32 bnx2i_alloc_iscsi_cid(struct bnx2i_hba *hba)
{
	int idx;

	if (!hba->cid_que.cid_free_cnt)
		return ISCSI_RESERVED_TAG;

	idx = hba->cid_que.cid_q_cons_idx;
	hba->cid_que.cid_q_cons_idx++;
	if (hba->cid_que.cid_q_cons_idx == hba->cid_que.cid_q_max_idx)
		hba->cid_que.cid_q_cons_idx = 0;

	hba->cid_que.cid_free_cnt--;
	return hba->cid_que.cid_que[idx];
}


/**
 * bnx2i_free_iscsi_cid - returns tcp port to free list
 *
 * @hba: 		pointer to adapter instance
 * @iscsi_cid:		iscsi context ID to free
 */
static void bnx2i_free_iscsi_cid(struct bnx2i_hba *hba, u16 iscsi_cid)
{
	int idx;

	if (iscsi_cid == (u16)ISCSI_RESERVED_TAG)
		return;

	hba->cid_que.cid_free_cnt++;

	idx = hba->cid_que.cid_q_prod_idx;
	hba->cid_que.cid_que[idx] = iscsi_cid;
	hba->cid_que.conn_cid_tbl[iscsi_cid] = NULL;
	hba->cid_que.cid_q_prod_idx++;
	if (hba->cid_que.cid_q_prod_idx == hba->cid_que.cid_q_max_idx)
		hba->cid_que.cid_q_prod_idx = 0;
}


/**
 * bnx2i_setup_free_cid_que - sets up free iscsi cid queue
 *
 * @hba: 		pointer to adapter instance
 *
 * allocates memory for iscsi cid queue & 'cid - conn ptr' mapping table,
 * 	and initialize table attributes
 */
static int bnx2i_setup_free_cid_que(struct bnx2i_hba *hba)
{
	int mem_size;
	int i;

	mem_size = hba->max_active_conns * sizeof(u32);
	mem_size = (mem_size + (PAGE_SIZE - 1)) & PAGE_MASK;

	hba->cid_que.cid_que_base = kmalloc(mem_size, GFP_KERNEL);
	if (!hba->cid_que.cid_que_base)
		return -ENOMEM;

	mem_size = hba->max_active_conns * sizeof(struct bnx2i_conn *);
	mem_size = (mem_size + (PAGE_SIZE - 1)) & PAGE_MASK;
	hba->cid_que.conn_cid_tbl = kmalloc(mem_size, GFP_KERNEL);
	if (!hba->cid_que.conn_cid_tbl) {
		kfree(hba->cid_que.cid_que_base);
		hba->cid_que.cid_que_base = NULL;
		return -ENOMEM;
	}

	hba->cid_que.cid_que = (u32 *)hba->cid_que.cid_que_base;
	hba->cid_que.cid_q_prod_idx = 0;
	hba->cid_que.cid_q_cons_idx = 0;
	hba->cid_que.cid_q_max_idx = hba->max_active_conns;
	hba->cid_que.cid_free_cnt = hba->max_active_conns;

	for (i = 0; i < hba->max_active_conns; i++) {
		hba->cid_que.cid_que[i] = i;
		hba->cid_que.conn_cid_tbl[i] = NULL;
	}
	return 0;
}


/**
 * bnx2i_release_free_cid_que - releases 'iscsi_cid' queue resources
 *
 * @hba: 		pointer to adapter instance
 */
static void bnx2i_release_free_cid_que(struct bnx2i_hba *hba)
{
	kfree(hba->cid_que.cid_que_base);
	hba->cid_que.cid_que_base = NULL;

	kfree(hba->cid_que.conn_cid_tbl);
	hba->cid_que.conn_cid_tbl = NULL;
}

static void bnx2i_setup_bd_tbl(struct bnx2i_hba *hba, struct bnx2i_dma *dma)
{
	struct iscsi_bd *mp_bdt;
	int pages = dma->size / PAGE_SIZE;
	u64 addr;

	mp_bdt = (struct iscsi_bd *) dma->pgtbl;
	addr = (unsigned long) dma->mem;
	mp_bdt->flags = ISCSI_BD_FIRST_IN_BD_CHAIN;
	do {
		mp_bdt->buffer_addr_lo = addr & 0xffffffff;
		mp_bdt->buffer_addr_hi = addr >> 32;
		mp_bdt->buffer_length = PAGE_SIZE;

		pages--;
		if (!pages)
			break;

		addr += PAGE_SIZE;
		mp_bdt++;
		mp_bdt->flags = 0;
	} while (1);
	mp_bdt->flags |= ISCSI_BD_LAST_IN_BD_CHAIN;
}


/**
 * bnx2i_setup_570x_pgtbl - iscsi QP page table setup function
 *
 * @ep: 		endpoint (transport indentifier) structure
 *
 * Sets up page tables for SQ/RQ/CQ, 1G/sec (5706/5708/5709) devices requires
 * 	64-bit address in big endian format. Whereas 10G/sec (57710) requires
 * 	PT in little endian format
 */
void bnx2i_setup_570x_pgtbl(struct bnx2i_hba *hba, struct bnx2i_dma *dma, int pgtbl_off)
{
	int num_pages;
	u32 *ptbl;
	dma_addr_t page;
	char *pgtbl_virt;

	/* SQ page table */
	pgtbl_virt = dma->pgtbl;
	memset(pgtbl_virt, 0, dma->pgtbl_size);
	num_pages = dma->size / PAGE_SIZE;
	page = dma->mapping;

	ptbl = (u32 *) ((u8 *) dma->pgtbl + pgtbl_off);
	while (num_pages--) {
		/* PTE is written in big endian format for
		 * 5706/5708/5709 devices */
		*ptbl = (u32) ((u64) page >> 32);
		ptbl++;
		*ptbl = (u32) page;
		ptbl++;
		page += PAGE_SIZE;
	}
}

/**
 * bnx2i_setup_5771x_pgtbl - iscsi QP page table setup function
 *
 * @ep: 		endpoint (transport indentifier) structure
 *
 * Sets up page tables for SQ/RQ/CQ, 1G/sec (5706/5708/5709) devices requires
 * 	64-bit address in big endian format. Whereas 10G/sec (57710) requires
 * 	PT in little endian format
 */
void bnx2i_setup_5771x_pgtbl(struct bnx2i_hba *hba, struct bnx2i_dma *dma, int pgtbl_off)
{
	int num_pages;
	u32 *ptbl;
	dma_addr_t page;
	char *pgtbl_virt;

	/* SQ page table */
	pgtbl_virt = dma->pgtbl;
	memset(pgtbl_virt, 0, dma->pgtbl_size);
	num_pages = dma->size / PAGE_SIZE;
	page = dma->mapping;

	ptbl = (u32 *) ((u8 *) dma->pgtbl + pgtbl_off);
	while (num_pages--) {
		/* PTE is written in little endian format for 57710 */
		*ptbl = (u32) page;
		ptbl++;
		*ptbl = (u32) ((u64) page >> 32);
		ptbl++;
		page += PAGE_SIZE;
	}
}


void bnx2i_free_dma(struct bnx2i_hba *hba, struct bnx2i_dma *dma)
{
	if (dma->mem) {
		pci_free_consistent(hba->pcidev, dma->size, dma->mem, dma->mapping);
		dma->mem = NULL;
	}
	if (dma->pgtbl && dma->pgtbl_type) {
		pci_free_consistent(hba->pcidev, dma->pgtbl_size,
				    dma->pgtbl, dma->pgtbl_map);
		dma->pgtbl = NULL;
	}
}


int bnx2i_alloc_dma(struct bnx2i_hba *hba, struct bnx2i_dma *dma,
		    int size, int pgtbl_type, int pgtbl_off)
{
	int pages = (size + PAGE_SIZE - 1) / PAGE_SIZE;

	dma->size = size;
	dma->pgtbl_type = pgtbl_type;

	dma->mem = pci_alloc_consistent(hba->pcidev, size, &dma->mapping);
	if (dma->mem == NULL)
		goto mem_err;

        if (!pgtbl_type)
                return 0;

        dma->pgtbl_size = ((pages * 8) + PAGE_SIZE - 1) & ~(PAGE_SIZE - 1);
        dma->pgtbl = pci_alloc_consistent(hba->pcidev, dma->pgtbl_size,
                                          &dma->pgtbl_map);
        if (dma->pgtbl == NULL)
                goto mem_err;

	if (pgtbl_type == BNX2I_TBL_TYPE_PG)
        	hba->setup_pgtbl(hba, dma, pgtbl_off);
	if (pgtbl_type == BNX2I_TBL_TYPE_BD)
		bnx2i_setup_bd_tbl(hba, dma);

        return 0;

mem_err:
        bnx2i_free_dma(hba, dma);
        return -ENOMEM;
}



/**
 * bnx2i_alloc_ep - allocates ep structure from global pool
 *
 * @hba: 		pointer to adapter instance
 *
 * routine allocates a free endpoint structure from global pool and
 *	a tcp port to be used for this connection.  Global resource lock,
 *	'bnx2i_resc_lock' is held while accessing shared global data structures
 */
#ifdef __RHEL54_DUAL_ISCSI_STACK__
static struct iscsi_endpoint *bnx2i_alloc_ep(struct bnx2i_hba *hba)
#else
static struct bnx2i_endpoint *bnx2i_alloc_ep(struct bnx2i_hba *hba)
#endif
{
	struct bnx2i_endpoint *endpoint;
#ifdef __RHEL54_DUAL_ISCSI_STACK__
	struct iscsi_endpoint *cls_ep;
#else
	struct list_head *listp;
#endif
	u16 tcp_port;
	unsigned long flags;

	spin_lock_irqsave(&bnx2i_resc_lock, flags);

#ifdef __VMKLNX__
	tcp_port = 0;
#else
	tcp_port = bnx2i_alloc_tcp_port();
	if (!tcp_port) {
		printk(KERN_ERR "bnx2i: unable to allocate tcp ports, "
				"make sure 'bnx2id' is running\n");
		spin_unlock_irqrestore(&bnx2i_resc_lock, flags);
		return NULL;
	}
#endif
#ifdef __RHEL54_DUAL_ISCSI_STACK__
	cls_ep = iscsi2_create_endpoint(sizeof(*endpoint));
	if (!cls_ep) {
		printk(KERN_ERR "bnx2i: Could not allocate ep\n");
		bnx2i_free_tcp_port(tcp_port);
		return NULL;
        }

        endpoint = cls_ep->dd_data;
        endpoint->cls_ep = cls_ep;
	INIT_LIST_HEAD(&endpoint->link);
#else
	if (list_empty(&bnx2i_free_ep_list)) {
#ifndef __VMKLNX__
		bnx2i_free_tcp_port(tcp_port);
#endif	/* __VMKLNX__ */
		spin_unlock_irqrestore(&bnx2i_resc_lock, flags);
		printk(KERN_ERR "bnx2i: ep struct pool empty\n");
		return NULL;
	}
	listp = (struct list_head *) bnx2i_free_ep_list.next;
	list_del_init(listp);
	bnx2i_num_free_ep--;

	endpoint = (struct bnx2i_endpoint *) listp;
#endif	/* __RHEL54_DUAL_ISCSI_STACK__ */
	endpoint->state = EP_STATE_IDLE;
	endpoint->hba = hba;
	endpoint->hba_age = hba->age;
	hba->ofld_conns_active++;
	endpoint->tcp_port = tcp_port;
	init_waitqueue_head(&endpoint->ofld_wait);

	spin_unlock_irqrestore(&bnx2i_resc_lock, flags);
#ifdef __RHEL54_DUAL_ISCSI_STACK__
	return cls_ep;
#else
	return endpoint;
#endif
}


/**
 * bnx2i_free_ep - returns endpoint struct and tcp port to free pool
 *
 * @endpoint:		pointer to endpoint structure
 *
 */
#ifdef __RHEL54_DUAL_ISCSI_STACK__
static void bnx2i_free_ep(struct iscsi_endpoint *cls_ep)
#else
static void bnx2i_free_ep(struct bnx2i_endpoint *endpoint)
#endif
{
#ifdef __RHEL54_DUAL_ISCSI_STACK__
        struct bnx2i_endpoint *endpoint = cls_ep->dd_data;
#endif
	unsigned long flags;

	spin_lock_irqsave(&bnx2i_resc_lock, flags);
	endpoint->state = EP_STATE_IDLE;
	endpoint->hba->ofld_conns_active--;

	bnx2i_free_iscsi_cid(endpoint->hba, endpoint->ep_iscsi_cid);
	if (endpoint->conn) {
		endpoint->conn->ep = NULL;
		endpoint->conn = NULL;
	}
	endpoint->sess = NULL;

	if (endpoint->tcp_port)
		bnx2i_free_tcp_port(endpoint->tcp_port);

	endpoint->hba = NULL;
#ifndef __RHEL54_DUAL_ISCSI_STACK__
	list_add_tail(&endpoint->link, &bnx2i_free_ep_list);
#endif
	bnx2i_num_free_ep++;
	spin_unlock_irqrestore(&bnx2i_resc_lock, flags);
#ifdef __RHEL54_DUAL_ISCSI_STACK__
        iscsi2_destroy_endpoint(cls_ep);
#endif
}


/**
 * bnx2i_alloc_ep_pool - alloccates a pool of endpoint structures
 *
 * allocates free pool of endpoint structures, which is used to store
 *	QP related control & PT info and other option-2 information
 */
int bnx2i_alloc_ep_pool(void)
{
	struct bnx2i_endpoint *endpoint;
	int index;
	int ret_val = 0;
	int total_endpoints;
	int page_count = 0;
	void *mem_ptr;
	int mem_size;

	spin_lock_init(&bnx2i_resc_lock);
	INIT_LIST_HEAD(&bnx2i_free_ep_list);
	INIT_LIST_HEAD(&bnx2i_unbound_ep);

	for (index = 0; index < MAX_PAGES_PER_CTRL_STRUCT_POOL; index++) {
		bnx2i_ep_pages[index] = NULL;
	}

	total_endpoints = ISCSI_MAX_CONNS_PER_HBA * ISCSI_MAX_ADAPTERS;
	bnx2i_num_free_ep = 0;
	mem_size = total_endpoints * sizeof(struct bnx2i_endpoint);
	mem_ptr = vmalloc(mem_size);
	if (!mem_ptr) {
		printk(KERN_ERR "ep_pool: mem alloc failed\n");
		goto mem_alloc_err;
	}
	memset(mem_ptr, 0, mem_size);

	bnx2i_ep_pages[page_count++] = mem_ptr;
	endpoint = mem_ptr;

	for (index = 0; index < total_endpoints; index++) {
		INIT_LIST_HEAD(&endpoint->link);
		list_add_tail(&endpoint->link, &bnx2i_free_ep_list);
		endpoint++;
		bnx2i_num_free_ep++;
	}
mem_alloc_err:
	if (bnx2i_num_free_ep == 0)
		ret_val = -ENOMEM;

	bnx2i_max_free_ep = bnx2i_num_free_ep;
	return ret_val;
}


/**
 * bnx2i_release_ep_pool - releases memory resources held by endpoint structs
 */
void bnx2i_release_ep_pool(void)
{
	int index;
	void *mem_ptr;

	for (index = 0; index < MAX_PAGES_PER_CTRL_STRUCT_POOL; index++) {
		mem_ptr = bnx2i_ep_pages[index];
		vfree(mem_ptr);
		bnx2i_ep_pages[index] = NULL;
	}
	bnx2i_num_free_ep = 0;
	return;
}

/**
 * bnx2i_alloc_cmd - allocates a command structure from free pool
 *
 * @sess:		iscsi session pointer
 *
 * allocates a command structures and ITT from free pool
 */
struct bnx2i_cmd *bnx2i_alloc_cmd(struct bnx2i_sess *sess)
{
	struct bnx2i_cmd *cmd;
	struct list_head *listp;

	if (unlikely(!sess || (sess->num_free_cmds == 0))) {
		return NULL;
	}

	if (list_empty(&sess->free_cmds) && sess->num_free_cmds) {
		/* this is wrong */
		printk("%s: WaTcH - num_free %d\n", __FUNCTION__, sess->num_free_cmds);
		return NULL;
	}

	listp = (struct list_head *) sess->free_cmds.next;
	list_del_init(listp);
	sess->num_free_cmds--;
	cmd = (struct bnx2i_cmd *) listp;
	cmd->scsi_status_rcvd = 0;

	INIT_LIST_HEAD(&cmd->link);
	bnx2i_setup_cmd_wqe_template(cmd);

	cmd->req.itt = cmd->itt;

	return cmd;
}


/**
 * bnx2i_free_cmd - releases iscsi cmd struct & ITT to respective free pool
 *
 * @sess:		iscsi session pointer
 * @cmd:		iscsi cmd pointer
 *
 * return command structure and ITT back to free pool.
 */
void bnx2i_free_cmd(struct bnx2i_sess *sess, struct bnx2i_cmd *cmd)
{
	if (atomic_read(&cmd->cmd_state) == ISCSI_CMD_STATE_FREED) {
		printk(KERN_ALERT "bnx2i: double freeing cmd %p\n", cmd);
		return;
	}
	list_del_init(&cmd->link);
	list_add_tail(&cmd->link, &sess->free_cmds);
	sess->num_free_cmds++;
	atomic_set(&cmd->cmd_state, ISCSI_CMD_STATE_FREED);
}


/**
 * bnx2i_alloc_cmd_pool - allocates and initializes iscsi command pool
 *
 * @sess:		iscsi session pointer
 *
 * Allocate command structure pool for a given iSCSI session. Return 'ENOMEM'
 *	if memory allocation fails
 */
int bnx2i_alloc_cmd_pool(struct bnx2i_sess *sess)
{
	struct bnx2i_cmd *cmdp;
	int index, count;
	int ret_val = 0;
	int total_cmds;
	int num_cmds;
	int page_count;
	int num_cmds_per_page;
	void *mem_ptr;
	u32 mem_size;
	int cmd_i;

	INIT_LIST_HEAD(&sess->free_cmds);
	for (index = 0; index < MAX_PAGES_PER_CTRL_STRUCT_POOL; index++)
		sess->cmd_pages[index] = NULL;

	num_cmds_per_page = PAGE_SIZE / sizeof(struct bnx2i_cmd);

	total_cmds = sess->sq_size;
	mem_size = sess->sq_size * sizeof(struct bnx2i_cmd *);
	mem_size = (mem_size + (PAGE_SIZE - 1)) & PAGE_MASK;
	sess->itt_cmd = kmalloc(mem_size, GFP_KERNEL);
	if (!sess->itt_cmd)
		return -ENOMEM;

	memset(sess->itt_cmd, 0x00, mem_size);

	cmd_i = 0;
	page_count = 0;
	for (index = 0; index < total_cmds;) {
		mem_ptr = kmalloc(PAGE_SIZE, GFP_KERNEL);
		if (mem_ptr == NULL)
			break;

		sess->cmd_pages[page_count++] = mem_ptr;
		num_cmds = num_cmds_per_page;
		if ((total_cmds - index) < num_cmds_per_page)
			num_cmds = (total_cmds - index);

		memset(mem_ptr, 0, PAGE_SIZE);
		cmdp = mem_ptr;
		for (count = 0; count < num_cmds; count++) {
			cmdp->req.itt = ITT_INVALID_SIGNATURE;
			INIT_LIST_HEAD(&cmdp->link);
			cmdp->itt = cmd_i;
			sess->itt_cmd[cmd_i] = cmdp;
			cmd_i++;

			/* Allocate BD table */
			cmdp->bd_tbl = bnx2i_alloc_bd_table(sess, cmdp);
			if (!cmdp->bd_tbl) {
				/* should never fail, as it's guaranteed to have
				 * (ISCSI_MAX_CMDS_PER_SESS + 1) BD tables
				 * allocated before calling this function.
				 */
				printk(KERN_ERR "no BD table cmd %p\n", cmdp);
				goto bd_table_failed;
			}
			list_add_tail(&cmdp->link, &sess->free_cmds);
			cmdp++;
		}

		sess->num_free_cmds += num_cmds;
		index += num_cmds;
	}
	sess->allocated_cmds = sess->num_free_cmds;

	if (sess->num_free_cmds == 0)
		ret_val = -ENOMEM;
	return ret_val;

bd_table_failed:
	return -ENOMEM;
}


/**
 * bnx2i_free_cmd_pool - releases memory held by free iscsi cmd pool
 *
 * @sess:		iscsi session pointer
 *
 * Release memory held by command struct pool.
 */
void bnx2i_free_cmd_pool(struct bnx2i_sess *sess)
{
	int index;
	void *mem_ptr;

	if (sess->num_free_cmds != sess->allocated_cmds) {
		/*
		 * WARN: either there is some command struct leak or
		 * still some SCSI commands are pending.
		 */
		printk(KERN_ERR "bnx2i: missing cmd structs - %d, %d\n",
				 sess->num_free_cmds, sess->allocated_cmds);
	}
	for (index = 0; index < MAX_PAGES_PER_CTRL_STRUCT_POOL; index++) {
		mem_ptr = sess->cmd_pages[index];
		kfree(mem_ptr);
		sess->cmd_pages[index] = NULL;
	}
	sess->num_free_cmds = sess->allocated_cmds = 0;

	kfree(sess->itt_cmd);
	sess->itt_cmd = NULL;

	return;
}

static struct bnx2i_scsi_task *bnx2i_alloc_scsi_task(struct bnx2i_sess *sess)
{
	struct list_head *listp;
	if (list_empty(&sess->scsi_task_list)) {
		return NULL;
	}
	listp = (struct list_head *) sess->scsi_task_list.next;
	list_del_init(listp);
	return (struct bnx2i_scsi_task *)listp;
}

static void bnx2i_free_scsi_task(struct bnx2i_sess *sess,
				 struct bnx2i_scsi_task *scsi_task)
{
	list_del_init((struct list_head *)scsi_task);
	scsi_task->scsi_cmd = NULL;
	list_add_tail(&scsi_task->link, &sess->scsi_task_list);
}

static int bnx2i_alloc_scsi_task_pool(struct bnx2i_sess *sess)
{
	struct bnx2i_scsi_task *scsi_task;
	int mem_size = 2 * PAGE_SIZE;
	int task_count;
	int i;

	INIT_LIST_HEAD(&sess->scsi_task_list);
	sess->task_list_mem = kmalloc(mem_size, GFP_KERNEL);
	if (!sess->task_list_mem)
		return -ENOMEM;

	scsi_task = (struct bnx2i_scsi_task *)sess->task_list_mem;
	task_count = mem_size / sizeof(struct bnx2i_scsi_task);
	for (i = 0; i < task_count; i++, scsi_task++) {
		INIT_LIST_HEAD(&scsi_task->link);
		scsi_task->scsi_cmd = NULL;
		list_add_tail(&scsi_task->link, &sess->scsi_task_list);
	}
	return 0;
}

static void bnx2i_free_scsi_task_pool(struct bnx2i_sess *sess)
{
	kfree(sess->task_list_mem);
	sess->task_list_mem = NULL;
	INIT_LIST_HEAD(&sess->scsi_task_list);
/*TODO - clear pend list too */
}

/**
 * bnx2i_alloc_bd_table - Alloc BD table to associate with this iscsi cmd 
 *
 * @sess:		iscsi session pointer
 * @cmd:		iscsi cmd pointer
 *
 * allocates a BD table and assigns it to given command structure. There is
 *	no synchronization issue as this code is executed in initialization
 *	thread
 */
static struct io_bdt *bnx2i_alloc_bd_table(struct bnx2i_sess *sess,
					   struct bnx2i_cmd *cmd)
{
	struct io_bdt *bd_tbl;

	if (list_empty(&sess->bd_tbl_list))
		return NULL;

	bd_tbl = (struct io_bdt *)sess->bd_tbl_list.next;
	list_del(&bd_tbl->link);
	list_add_tail(&bd_tbl->link, &sess->bd_tbl_active);
	bd_tbl->bd_valid = 0;
	bd_tbl->cmdp = cmd;

	return bd_tbl;
}


/**
 * bnx2i_free_all_bdt_resc_pages - releases memory held by BD memory tracker tbl
 *
 * @sess:		iscsi session pointer
 *
 * Free up memory pages allocated held by BD resources
 */
static void bnx2i_free_all_bdt_resc_pages(struct bnx2i_sess *sess)
{
	int i;
	struct bd_resc_page *resc_page;

	spin_lock_bh(&sess->lock);
	while (!list_empty(&sess->bd_resc_page)) {
		resc_page = (struct bd_resc_page *)sess->bd_resc_page.prev;
		list_del(sess->bd_resc_page.prev);
		for(i = 0; i < resc_page->num_valid; i++)
			kfree(resc_page->page[i]);
		kfree(resc_page);
	}
	spin_unlock_bh(&sess->lock);
}



/**
 * bnx2i_alloc_bdt_resc_page - allocated a page to track BD table memory
 *
 * @sess:		iscsi session pointer
 *
 * allocated a page to track BD table memory
 */
struct bd_resc_page *bnx2i_alloc_bdt_resc_page(struct bnx2i_sess *sess)
{
	void *mem_ptr;
	struct bd_resc_page *resc_page;

	mem_ptr = kmalloc(PAGE_SIZE, GFP_KERNEL);
	if (!mem_ptr)
		return NULL;

	resc_page = mem_ptr;
	list_add_tail(&resc_page->link, &sess->bd_resc_page);
	resc_page->max_ptrs = (PAGE_SIZE -
		(u32) &((struct bd_resc_page *) 0)->page[0]) / sizeof(void *);
	resc_page->num_valid = 0;

	return resc_page;
}


/**
 * bnx2i_add_bdt_resc_page - add newly allocated memory page to list
 *
 * @sess:		iscsi session pointer
 * @bd_page:		pointer to page memory
 *
 * link newly allocated memory page to tracker list
 */
int bnx2i_add_bdt_resc_page(struct bnx2i_sess *sess, void *bd_page)
{
	struct bd_resc_page *resc_page;

#define is_resc_page_full(_resc_pg) (_resc_pg->num_valid == _resc_pg->max_ptrs)
#define active_resc_page(_resc_list) 	\
			(list_empty(_resc_list) ? NULL : (_resc_list)->prev)
	if (list_empty(&sess->bd_resc_page)) {
		resc_page = bnx2i_alloc_bdt_resc_page(sess);
	} else {
		resc_page = (struct bd_resc_page *)
					active_resc_page(&sess->bd_resc_page);
	}

	if (!resc_page)
		return -ENOMEM;

	resc_page->page[resc_page->num_valid++] = bd_page;
	if (is_resc_page_full(resc_page)) {
		resc_page = bnx2i_alloc_bdt_resc_page(sess);
	}
	return 0;
}


/**
 * bnx2i_alloc_bd_table_pool - Allocates buffer descriptor (BD) pool
 *
 * @sess:		iscsi session pointer
 *
 * Allocate a pool of buffer descriptor tables and associated DMA'able memory
 *	to be used with the session.
 */
static int bnx2i_alloc_bd_table_pool(struct bnx2i_sess *sess)
{
	int index, count;
	int ret_val = 0;
	int num_elem_per_page;
	int num_pages;
	struct io_bdt *bdt_info;
	void *mem_ptr;
	int bd_tbl_size;
	u32 mem_size;
	int total_bd_tbl;
	struct bnx2i_dma *dma;

	INIT_LIST_HEAD(&sess->bd_resc_page);
	INIT_LIST_HEAD(&sess->bd_tbl_list);
	INIT_LIST_HEAD(&sess->bd_tbl_active);

	total_bd_tbl = sess->sq_size;
	mem_size = total_bd_tbl * sizeof(struct io_bdt);
	num_elem_per_page = PAGE_SIZE / sizeof(struct io_bdt);

	for (index = 0; index < total_bd_tbl; index += num_elem_per_page) {
		if (((total_bd_tbl - index) * sizeof(struct io_bdt))
		    >= PAGE_SIZE) {
			mem_size = PAGE_SIZE;
			num_elem_per_page = PAGE_SIZE / sizeof(struct io_bdt);
		} else {
			mem_size =
				(total_bd_tbl - index) * sizeof(struct io_bdt);
			num_elem_per_page = (total_bd_tbl - index);
		}
		mem_ptr = kmalloc(mem_size, GFP_KERNEL);
		if (mem_ptr == NULL) {
			printk(KERN_ERR "alloc_bd_tbl: mem alloc failed\n");
			ret_val = -ENOMEM;
			goto resc_alloc_failed;
		}
		bnx2i_add_bdt_resc_page(sess, mem_ptr);

		memset(mem_ptr, 0, mem_size);
		bdt_info = mem_ptr;
		for (count = 0; count < num_elem_per_page; count++) {
			INIT_LIST_HEAD(&bdt_info->link);
			list_add_tail(&bdt_info->link, &sess->bd_tbl_list);
			bdt_info++;
		}
	}


	INIT_LIST_HEAD(&sess->bdt_dma_resc);

	bd_tbl_size = ISCSI_MAX_BDS_PER_CMD * sizeof(struct iscsi_bd);
	bdt_info = (struct io_bdt *)sess->bd_tbl_list.next;
	num_elem_per_page = PAGE_SIZE / bd_tbl_size;

	num_pages = ((sess->sq_size * bd_tbl_size) + PAGE_SIZE - 1) &
		    ~(PAGE_SIZE - 1);
	num_pages /= PAGE_SIZE;

	/* MPP driver workaround - allocate sess->sq_size number of bnx2i_dma elements */
	sess->bdt_dma_info = kmalloc(sizeof(*dma) * sess->sq_size, GFP_KERNEL);
	if (sess->bdt_dma_info == NULL)
		goto resc_alloc_failed;

	memset(sess->bdt_dma_info, 0, sess->sq_size * sizeof(*dma));
	dma = (struct bnx2i_dma *)sess->bdt_dma_info;
	while (bdt_info && (bdt_info != (struct io_bdt *)&sess->bd_tbl_list)) {
		if (bnx2i_alloc_dma(sess->hba, dma, PAGE_SIZE, 0, 0)) {
			printk(KERN_ERR "bd_tbl: DMA mem alloc failed\n");
			ret_val = -ENOMEM;
			goto dma_alloc_failed;
		}
		list_add_tail(&dma->link, &sess->bdt_dma_resc);

		/* Workaround for MPP driver issue - allocate 4KB memory per BD table */
		num_elem_per_page = 1;

		for (count = 0; count < num_elem_per_page; count++) {
			bdt_info->bd_tbl = (struct iscsi_bd *)(dma->mem +
						(count * bd_tbl_size));
			bdt_info->bd_tbl_dma = dma->mapping + count * bd_tbl_size;
			bdt_info->max_bd_cnt = ISCSI_MAX_BDS_PER_CMD;
			bdt_info->bd_valid = 0;
			bdt_info->cmdp = NULL;
			bdt_info = (struct io_bdt *)bdt_info->link.next;
			if (bdt_info == (struct io_bdt *)&sess->bd_tbl_list)
				break;
		}
		dma++;
	}
	return ret_val;

resc_alloc_failed:
dma_alloc_failed:
	return ret_val;
}


/**
 * bnx2i_free_bd_table_pool - releases resources held by BD table pool
 *
 * @sess:		iscsi session pointer
 *
 * releases BD table pool memory
 */
void bnx2i_free_bd_table_pool(struct bnx2i_sess *sess)
{
	struct list_head *list;
	struct bnx2i_dma *dma;

	list_for_each(list, &sess->bdt_dma_resc) {
		dma = list_entry(list, struct bnx2i_dma, link);
		bnx2i_free_dma(sess->hba, dma);
	}

	kfree(sess->bdt_dma_info);
}


/**
 * bnx2i_setup_mp_bdt - allocated BD table resources to be used as
 *			the dummy buffer for '0' payload length iscsi requests
 *
 * @hba: 		pointer to adapter structure
 *
 * allocate memory for dummy buffer and associated BD table to be used by
 *	middle path (MP) requests
 */
int bnx2i_setup_mp_bdt(struct bnx2i_hba *hba)
{
	int rc = 0;

	if (bnx2i_alloc_dma(hba, &hba->mp_dma_buf, PAGE_SIZE, BNX2I_TBL_TYPE_BD, 0)) {
		printk(KERN_ERR "unable to allocate Middle Path BDT\n");
		rc = -1;
	}
	return rc;
}


/**
 * bnx2i_free_mp_bdt - releases ITT back to free pool
 *
 * @hba: 		pointer to adapter instance
 *
 * free MP dummy buffer and associated BD table
 */
void bnx2i_free_mp_bdt(struct bnx2i_hba *hba)
{
	bnx2i_free_dma(hba, &hba->mp_dma_buf);
}


/**
 * bnx2i_start_iscsi_hba_shutdown - start hba shutdown by cleaning up
 *			all active sessions
 *
 * @hba: 		pointer to adapter instance
 *
 *  interface is being brought down by the user, fail all active iSCSI sessions
 *	belonging to this adapter
 */
void bnx2i_start_iscsi_hba_shutdown(struct bnx2i_hba *hba)
{
	struct list_head *list;
	struct list_head *tmp;
	struct bnx2i_sess *sess;
	int timeout_secs = hba->hba_shutdown_tmo;
	unsigned long flags;
	int lpcnt;
	int rc;

	spin_lock_irqsave(&hba->lock, flags);
	list_for_each_safe(list, tmp, &hba->active_sess) {
		sess = (struct bnx2i_sess *)list;
		spin_unlock_irqrestore(&hba->lock, flags);
		lpcnt = 4;
		rc = bnx2i_do_iscsi_sess_recovery(sess, DID_NO_CONNECT);
		while ((rc != SUCCESS) && lpcnt--) {
			msleep(1000);
			rc = bnx2i_do_iscsi_sess_recovery(sess, DID_NO_CONNECT);
		}
		spin_lock_irqsave(&hba->lock, flags);
	}
	spin_unlock_irqrestore(&hba->lock, flags);

	wait_event_interruptible_timeout(hba->eh_wait,
					 (hba->ofld_conns_active == 0),
					 timeout_secs);
}


/**
 * bnx2i_iscsi_handle_ip_event - inetdev callback to handle ip address change
 *
 * @hba: 		pointer to adapter instance
 *
 * IP address change indication, fail all iSCSI connections on this adapter
 *	and let 'iscsid' reinstate the connections
 */
void bnx2i_iscsi_handle_ip_event(struct bnx2i_hba *hba)
{
	struct list_head *list;
	struct list_head *tmp;
	struct bnx2i_sess *sess;
	unsigned long flags;

	spin_lock_irqsave(&hba->lock, flags);
	list_for_each_safe(list, tmp, &hba->active_sess) {
		sess = (struct bnx2i_sess *)list;
		spin_unlock_irqrestore(&hba->lock, flags);
		bnx2i_do_iscsi_sess_recovery(sess, DID_RESET);
		spin_lock_irqsave(&hba->lock, flags);
	}
	spin_unlock_irqrestore(&hba->lock, flags);
}


static void bnx2i_withdraw_sess_recovery(struct bnx2i_sess *sess)
{
	struct bnx2i_hba *hba = sess->hba;
	int cons_idx = hba->sess_recov_cons_idx;
	unsigned int long flags;

	spin_lock_irqsave(&hba->lock, flags);
	while (hba->sess_recov_prod_idx != cons_idx) {
		if (sess == hba->sess_recov_list[cons_idx]) {
			hba->sess_recov_list[cons_idx] = NULL;
			break;
		}
		if (cons_idx == hba->sess_recov_max_idx)
			cons_idx = 0;
		else
			cons_idx++;
	}
	spin_unlock_irqrestore(&hba->lock, flags);
}

/**
 * conn_err_recovery_task - does recovery on all queued sessions
 *
 * @work:		pointer to work struct
 *
 * iSCSI Session recovery queue manager
 */
static void
#if defined(INIT_DELAYED_WORK_DEFERRABLE) || defined(INIT_WORK_NAR)
conn_err_recovery_task(struct work_struct *work)
#else
conn_err_recovery_task(void *data)
#endif
{
#if defined(INIT_DELAYED_WORK_DEFERRABLE) || defined(INIT_WORK_NAR)
	struct bnx2i_hba *hba = container_of(work, struct bnx2i_hba,
					     err_rec_task);
#else
	struct bnx2i_hba *hba = data;
#endif
	struct bnx2i_sess *sess;
	int cons_idx = hba->sess_recov_cons_idx;
	unsigned int long flags;

	spin_lock_irqsave(&hba->lock, flags);
	while (hba->sess_recov_prod_idx != cons_idx) {
		sess = hba->sess_recov_list[cons_idx];
		if (cons_idx == hba->sess_recov_max_idx)
			cons_idx = 0;
		else
			cons_idx++;
		spin_unlock_irqrestore(&hba->lock, flags);
		if (sess) {
			if (sess->state == BNX2I_SESS_IN_LOGOUT)
				bnx2i_do_iscsi_sess_recovery(sess, DID_NO_CONNECT);
			else
				bnx2i_do_iscsi_sess_recovery(sess, DID_RESET);
		}
		spin_lock_irqsave(&hba->lock, flags);
	}
	hba->sess_recov_cons_idx = cons_idx;
	spin_unlock_irqrestore(&hba->lock, flags);
}

/**
 * bnx2i_ep_destroy_list_add - add an entry to EP destroy list
 *
 * @hba: 		pointer to adapter instance
 * @ep: 		pointer to endpoint (transport indentifier) structure
 *
 * EP destroy queue manager
 */
static int bnx2i_ep_destroy_list_add(struct bnx2i_hba *hba,
				  struct bnx2i_endpoint *ep)
{
#ifdef __VMKLNX__
	spin_lock(&hba->lock);
#else
	write_lock(&hba->ep_rdwr_lock);
#endif
	list_add_tail(&ep->link, &hba->ep_destroy_list);
#ifdef __VMKLNX__
	spin_unlock(&hba->lock);
#else
	write_unlock(&hba->ep_rdwr_lock);
#endif
	return 0;
}

/**
 * bnx2i_ep_destroy_list_del - add an entry to EP destroy list
 *
 * @hba: 		pointer to adapter instance
 * @ep: 		pointer to endpoint (transport indentifier) structure
 *
 * EP destroy queue manager
 */
static int bnx2i_ep_destroy_list_del(struct bnx2i_hba *hba,
				     struct bnx2i_endpoint *ep)
{
#ifdef __VMKLNX__
	spin_lock(&hba->lock);
#else
	write_lock(&hba->ep_rdwr_lock);
#endif
	list_del_init(&ep->link);
#ifdef __VMKLNX__
	spin_unlock(&hba->lock);
#else
	write_unlock(&hba->ep_rdwr_lock);
#endif

	return 0;
}

/**
 * bnx2i_ep_ofld_list_add - add an entry to ep offload pending list
 *
 * @hba: 		pointer to adapter instance
 * @ep: 		pointer to endpoint (transport indentifier) structure
 *
 * pending conn offload completion queue manager
 */
static int bnx2i_ep_ofld_list_add(struct bnx2i_hba *hba,
				  struct bnx2i_endpoint *ep)
{
#ifdef __VMKLNX__
	spin_lock(&hba->lock);
#else
	write_lock(&hba->ep_rdwr_lock);
#endif
	list_add_tail(&ep->link, &hba->ep_ofld_list);
#ifdef __VMKLNX__
	spin_unlock(&hba->lock);
#else
	write_unlock(&hba->ep_rdwr_lock);
#endif
	return 0;
}

/**
 * bnx2i_ep_ofld_list_del - add an entry to ep offload pending list
 *
 * @hba: 		pointer to adapter instance
 * @ep: 		pointer to endpoint (transport indentifier) structure
 *
 * pending conn offload completion queue manager
 */
static int bnx2i_ep_ofld_list_del(struct bnx2i_hba *hba,
				  struct bnx2i_endpoint *ep)
{
#ifdef __VMKLNX__
	spin_lock(&hba->lock);
#else
	write_lock(&hba->ep_rdwr_lock);
#endif
	list_del_init(&ep->link);
#ifdef __VMKLNX__
	spin_unlock(&hba->lock);
#else
	write_unlock(&hba->ep_rdwr_lock);
#endif

	return 0;
}


/**
 * bnx2i_find_ep_in_ofld_list - find iscsi_cid in pending list of endpoints
 *
 * @hba: 		pointer to adapter instance
 * @iscsi_cid:		iscsi context ID to find
 *
 */
struct bnx2i_endpoint *
bnx2i_find_ep_in_ofld_list(struct bnx2i_hba *hba, u32 iscsi_cid)
{
	struct list_head *list;
	struct list_head *tmp;
	struct bnx2i_endpoint *ep;

#ifdef __VMKLNX__
	spin_lock(&hba->lock);
#else
	read_lock(&hba->ep_rdwr_lock);
#endif
	list_for_each_safe(list, tmp, &hba->ep_ofld_list) {
		ep = (struct bnx2i_endpoint *)list;

		if (ep->ep_iscsi_cid == iscsi_cid)
			break;
		ep = NULL;
	}
#ifdef __VMKLNX__
	spin_unlock(&hba->lock);
#else
	read_unlock(&hba->ep_rdwr_lock);
#endif

	if (!ep)
		printk("bnx2i: ofld_list - icid %d not found\n", iscsi_cid);
	return ep;
}


/**
 * bnx2i_find_ep_in_destroy_list - find iscsi_cid in destroy list
 *
 * @hba: 		pointer to adapter instance
 * @iscsi_cid:		iscsi context ID to find
 *
 */
struct bnx2i_endpoint *
bnx2i_find_ep_in_destroy_list(struct bnx2i_hba *hba, u32 iscsi_cid)
{
	struct list_head *list;
	struct list_head *tmp;
	struct bnx2i_endpoint *ep;

#ifdef __VMKLNX__
	spin_lock(&hba->lock);
#else
	read_lock(&hba->ep_rdwr_lock);
#endif
	list_for_each_safe(list, tmp, &hba->ep_destroy_list) {
		ep = (struct bnx2i_endpoint *)list;

		if (ep->ep_iscsi_cid == iscsi_cid)
			break;
		ep = NULL;
	}
#ifdef __VMKLNX__
	spin_unlock(&hba->lock);
#else
	read_unlock(&hba->ep_rdwr_lock);
#endif

	if (!ep)
		printk("bnx2i: destroy_list - icid %d not found\n", iscsi_cid);

	return ep;
}


#ifdef __VMKLNX__
struct Scsi_Host *bnx2i_alloc_shost(int priv_sz)
{
	struct Scsi_Host *shost;

	shost = scsi_host_alloc(&bnx2i_host_template, priv_sz);
	if (!shost)
		return NULL;

	/* Vmware suggested values */
	shost->max_id = 256;
	shost->max_channel = 64;
	shost->max_lun = bnx2i_iscsi_transport.max_lun;

	return shost;
}
#endif


/**
 * bnx2i_alloc_hba - allocate and init adapter instance
 *
 * @cnic:		cnic device pointer
 *
 * allocate & initialize adapter structure and call other
 *	support routines to do per adapter initialization
 */
struct bnx2i_hba *bnx2i_alloc_hba(struct cnic_dev *cnic)
{
	struct bnx2i_hba *hba;
	struct scsi_host_template *scsi_template;
	struct iscsi_transport *iscsi_transport;

#ifdef __VMKLNX__
	struct Scsi_Host *shost;
	shost = bnx2i_alloc_shost(hostdata_privsize(sizeof(*hba)));
	if (!shost)
		return NULL;
	hba = shost_priv(shost);
	hba->shost = shost;
#else
	hba = kmalloc(sizeof(struct bnx2i_hba), GFP_KERNEL);
	if (!hba)
		return NULL;

	memset(hba, 0, sizeof(struct bnx2i_hba));
#endif
	/* Get PCI related information and update hba struct members */
	hba->cnic = cnic;
	hba->netdev = cnic->netdev;

	INIT_LIST_HEAD(&hba->active_sess);
	INIT_LIST_HEAD(&hba->ep_ofld_list);
	INIT_LIST_HEAD(&hba->ep_destroy_list);
#ifndef __VMKLNX__
	rwlock_init(&hba->ep_rdwr_lock);
#endif

	hba->mtu_supported = BNX2I_MAX_MTU_SUPPORTED;

	hba->max_active_conns = ISCSI_MAX_CONNS_PER_HBA;

	/* Get device type required to determine default SQ size */
	if (cnic->pcidev) {
		hba->pci_did = cnic->pcidev->device;
		bnx2i_identify_device(hba);
	}

	/* SQ/RQ/CQ size can be changed via sysfs interface */
	if (test_bit(BNX2I_NX2_DEV_57710, &hba->cnic_dev_type)) {
        	hba->setup_pgtbl = bnx2i_setup_5771x_pgtbl;
		if (sq_size && sq_size <= BNX2I_5770X_SQ_WQES_MAX)
			hba->max_sqes = sq_size;
		else
			hba->max_sqes = BNX2I_5770X_SQ_WQES_DEFAULT;

#ifndef CONFIG_X86_64
		if (hba->max_sqes > BNX2I_5770X_SQ_WQES_DEFAULT_X86)
			hba->max_sqes = BNX2I_5770X_SQ_WQES_DEFAULT_X86;
#endif
	} else {	/* 5706/5708/5709 */
        	hba->setup_pgtbl = bnx2i_setup_570x_pgtbl;
		if (sq_size && sq_size <= BNX2I_570X_SQ_WQES_MAX)
			hba->max_sqes = sq_size;
		else {
#ifdef __VMKLNX__
			if (test_bit(BNX2I_NX2_DEV_5709, &hba->cnic_dev_type))
				hba->max_sqes = BNX2I_5709_SQ_WQES_DEFAULT;
			else
				hba->max_sqes = BNX2I_570X_SQ_WQES_DEFAULT;
#else
			hba->max_sqes = BNX2I_570X_SQ_WQES_DEFAULT;
#endif
		}
	}

	hba->max_rqes = rq_size;
	hba->max_cqes = hba->max_sqes + rq_size;
	hba->num_ccell = hba->max_sqes / 2;

	scsi_template = bnx2i_alloc_scsi_host_template(hba, cnic);
	if (!scsi_template)
		return NULL;

	iscsi_transport = bnx2i_alloc_iscsi_transport(hba, cnic, scsi_template);
	if (!iscsi_transport)
		goto iscsi_transport_err;

	/* Get PCI related information and update hba struct members */
	hba->cnic = cnic;
	hba->netdev = cnic->netdev;


	if (bnx2i_setup_free_cid_que(hba))
		goto cid_que_err;

	hba->scsi_template = scsi_template;
	hba->iscsi_transport = iscsi_transport;

	spin_lock_init(&hba->lock);
	mutex_init(&hba->net_dev_lock);

	/* initialize timer and wait queue used for resource cleanup when
	 * interface is brought down */
	init_timer(&hba->hba_timer);
	init_waitqueue_head(&hba->eh_wait);

#ifdef __VMKLNX__
	init_timer(&hba->hba_poll_timer);
	hba->hba_poll_timer.expires = jiffies + 2 * HZ;
	hba->hba_poll_timer.function = bnx2i_hba_poll_timer;
	hba->hba_poll_timer.data = (unsigned long) hba;
	add_timer(&hba->hba_poll_timer);
#endif


#if defined(INIT_DELAYED_WORK_DEFERRABLE) || defined(INIT_WORK_NAR)
	INIT_WORK(&hba->err_rec_task, conn_err_recovery_task);
#else
	INIT_WORK(&hba->err_rec_task, conn_err_recovery_task, hba);
#endif
	hba->sess_recov_prod_idx = 0;
	hba->sess_recov_cons_idx = 0;
	hba->sess_recov_max_idx = 0;
	hba->sess_recov_list = kmalloc(PAGE_SIZE, GFP_KERNEL);
	if (!hba->sess_recov_list)
		goto rec_que_err;
	hba->sess_recov_max_idx = PAGE_SIZE / sizeof (struct bnx2i_sess *) - 1;
#ifdef __VMKLNX__
	if (bnx2i_bind_adapter_devices(hba))
		goto pcidev_bind_err;
#endif

	return hba;

#ifdef __VMKLNX__
pcidev_bind_err:
#endif
rec_que_err:
	bnx2i_release_free_cid_que(hba);
cid_que_err:
	bnx2i_free_iscsi_transport(iscsi_transport);
iscsi_transport_err:
	bnx2i_free_scsi_host_template(scsi_template);
#ifdef __VMKLNX__
	scsi_host_put(shost);
#else
	bnx2i_free_hba(hba);
#endif

	return NULL;
}


/**
 * bnx2i_free_hba- releases hba structure and resources held by the adapter
 *
 * @hba: 		pointer to adapter instance
 *
 * free adapter structure and call various cleanup routines.
 */
void bnx2i_free_hba(struct bnx2i_hba *hba)
{
	bnx2i_release_free_cid_que(hba);
	INIT_LIST_HEAD(&hba->ep_ofld_list);
	INIT_LIST_HEAD(&hba->ep_destroy_list);

#ifdef __VMKLNX__
	del_timer_sync(&hba->hba_poll_timer);
#endif

	INIT_LIST_HEAD(&hba->active_sess);
#ifdef __VMKLNX__
	bnx2i_unbind_adapter_devices(hba);
	scsi_host_put(hba->shost);
#else
	kfree(hba);
#endif
}


static int bnx2i_flush_pend_queue(struct bnx2i_sess *sess,
				   struct scsi_cmnd *sc, int reason)
{
	int num_pend_cmds_returned = 0;
	struct list_head *list;
	struct list_head *tmp;
	struct bnx2i_scsi_task *scsi_task;

	spin_lock_bh(&sess->lock);
	list_for_each_safe(list, tmp, &sess->pend_cmd_list) {
		scsi_task = (struct bnx2i_scsi_task *) list;

		/* cmd queue flush request could be due to LUN RESET or
		 * the session recovery. In former case just fail only the
		 * command belonging that particular LUN.
		 */
		if (sc) {
			if (sc == scsi_task->scsi_cmd) {
				list_del_init(&scsi_task->link);
				scsi_task->scsi_cmd = NULL;
				list_add_tail(&scsi_task->link,
					      &sess->scsi_task_list);
			} else if (scsi_task->scsi_cmd->device->lun
				   != sc->device->lun)
				continue;
		}

		num_pend_cmds_returned++;
		list_del_init(&scsi_task->link);
		bnx2i_return_failed_command(sess, scsi_task->scsi_cmd,
					    scsi_bufflen(scsi_task->scsi_cmd),
					    reason);
		scsi_task->scsi_cmd = NULL;
		list_add_tail(&scsi_task->link, &sess->scsi_task_list);
	}
	sess->pend_cmd_count -= num_pend_cmds_returned;
	spin_unlock_bh(&sess->lock);
	return num_pend_cmds_returned;
}

/**
 * bnx2i_flush_cmd_queue - flush active command queue
 *
 * @sess:		iscsi session pointer
 * @reason: 		SCSI ML error code, DID_BUS_BUSY
 *
 * return all commands in active queue which should already have been
 * 	cleaned up by the cnic device.
 */
static int bnx2i_flush_cmd_queue(struct bnx2i_sess *sess,
				  struct scsi_cmnd *scsi_cmd,
				  int reason, int clear_ctx)
{
	struct list_head *list;
	struct list_head *tmp;
	struct bnx2i_cmd *cmd;
	unsigned long flags;
	int cmd_diff_lun = 0;
	struct Scsi_Host *shost;
	struct list_head failed_cmds;
	int total_sess_active_cmds = 0;
	int cmd_cnt = 0;

	shost = bnx2i_sess_get_shost(sess);

	INIT_LIST_HEAD(&failed_cmds);
	spin_lock_irqsave(&sess->lock, flags);
	list_for_each_safe(list, tmp, &sess->active_cmd_list) {
		cmd = (struct bnx2i_cmd *) list;
		total_sess_active_cmds++;

		if (!cmd->scsi_cmd) {
			printk(KERN_ALERT "bnx2i: WaTcH - cid %d, flush que,"
					  " cmd %p is not associated with any"
					  " scsi cmd\n",
					  sess->lead_conn->ep->ep_iscsi_cid,
					  cmd);
			continue;
		}
		/* cmd queue flush request could be due to LUN RESET or
		 * the session recovery. In former case just fail only the
		 * command belonging that particular LUN.
		 */
		if (scsi_cmd) {
			if (cmd->scsi_cmd->device->lun !=
				   scsi_cmd->device->lun) {
				cmd_diff_lun++;
				continue;
			}
		}
		if (atomic_read(&cmd->cmd_state) == ISCSI_CMD_STATE_CMPL_RCVD){
			/* completion pdu is being processed and we will let
			 * it run to completion, fail the request here
			 */
			printk(KERN_ALERT "bnx2i: WaTcH - cid %d, completion & "
					  "TMF cleanup are running in parallel,"
					  " cmd %p\n",
					  sess->lead_conn->ep->ep_iscsi_cid, cmd);
			continue;
		}
	    	cmd->scsi_cmd->result = (reason << 16);
		/* Now that bnx2i_cleanup_task_context() does not sleep waiting
		 * for completion it is safe to hold sess lock and this will
		 * avoid race between LUN/TARGET RESET TMF completion followed
		 * by command completion with check condition
		 */

		if (clear_ctx) {
			atomic_set(&cmd->cmd_state, ISCSI_CMD_STATE_CLEANUP_START);
			bnx2i_cleanup_task_context(sess, cmd, reason);
		} else {
			list_del_init(&cmd->link);
			list_add_tail(&cmd->link, &failed_cmds);
		}
		cmd_cnt++;
	}
	spin_unlock_irqrestore(&sess->lock, flags);

	list_for_each_safe(list, tmp, &failed_cmds) {
		cmd = (struct bnx2i_cmd *) list;
		cmd->failed_reason = reason;
		bnx2i_fail_cmd(sess, cmd);
	}
	return cmd_cnt;
}


/**
 * bnx2i_session_recovery_start - start recovery process on given session
 *
 * @sess:		iscsi session pointer
 * @reason: 		SCSI ML error code, DID_BUS_BUSY
 *
 * initiate cleanup of outstanding commands for sess recovery
 */
static int bnx2i_session_recovery_start(struct bnx2i_sess *sess, int reason)
{
	if (sess->state == BNX2I_SESS_IN_LOGOUT ||
	    sess->state == BNX2I_SESS_INITIAL)
		return 0;

	if (!is_sess_active(sess) &&
	    !sess->state & BNX2I_SESS_INITIAL) {
		if (sess->recovery_state)
			return -EPERM;
		wait_event_interruptible_timeout(sess->er_wait,
						 (sess->state ==
						  BNX2I_SESS_IN_FFP), 20 * HZ);
		if (signal_pending(current))
			flush_signals(current);
		if (!is_sess_active(sess) &&
		    !sess->state & BNX2I_SESS_INITIAL) {
			printk(KERN_ALERT "sess_reco: sess still not active\n");
			sess->lead_conn->state = CONN_STATE_XPORT_FREEZE;
			return -EPERM;
		}
	}

	return 0;
}


/**
 * bnx2i_do_iscsi_sess_recovery - implements session recovery code
 *
 * @sess:		iscsi session pointer
 * @reason: 		SCSI ML error code, DID_BUS_BUSY, DID_NO_CONNECT,
 *			DID_RESET
 *
 * SCSI host reset handler, which is translates to iSCSI session
 *	recovery. This routine starts internal driver session recovery,
 *	indicates connection error to 'iscsid' which does session reinstatement
 *	This is an synchronous call which waits for completion and returns
 *	the ultimate result of session recovery process to caller
 */
int bnx2i_do_iscsi_sess_recovery(struct bnx2i_sess *sess, int reason)
{
	struct bnx2i_hba *hba;
	struct bnx2i_conn *conn = sess->lead_conn;

	if (!conn)
		return FAILED;

	/* block scsi host to avoid any further command queuing */
#ifdef __VMKLNX__
	iscsi_block_session(sess->cls_sess);
#else
#ifdef __RHEL54_DUAL_ISCSI_STACK__
printk("bnx2i:%s - block - sess %p, cls_sess %p\n", __FUNCTION__, sess, sess->cls_sess);
	iscsi_block_session(sess->cls_sess);
#else
	iscsi_block_session(session_to_cls(sess));
#endif	/* __RHEL54_DUAL_ISCSI_STACK__ */
#endif	/* __VMKLNX__ */

	if (bnx2i_session_recovery_start(sess, reason)) {
		printk(KERN_INFO "bnx2i: sess rec start returned error\n");
		return FAILED;
	}
	hba = sess->hba;

	sess->recovery_state = ISCSI_SESS_RECOVERY_OPEN_ISCSI;
	iscsi_conn_error(conn->cls_conn, ISCSI_ERR_CONN_FAILED);

	/* if session teardown is because of net interface down,
	 * no need to wait for complete recovery */
	if (reason == DID_NO_CONNECT ||
	    test_bit(ADAPTER_STATE_LINK_DOWN, &sess->hba->adapter_state))
		wait_event_interruptible_timeout(sess->er_wait,
						 !conn->ep,
						 msecs_to_jiffies(3000));
	else
		wait_event_interruptible(sess->er_wait,
					 ((sess->recovery_state &
					   ISCSI_SESS_RECOVERY_COMPLETE) ||
					  (sess->recovery_state &
					   ISCSI_SESS_RECOVERY_FAILED) ||
					  sess->recovery_state == 0));

	if (signal_pending(current))
		flush_signals(current);

	if (reason == DID_NO_CONNECT)
		goto ret_success;

	if (sess->recovery_state & ISCSI_SESS_RECOVERY_COMPLETE) {
		printk(KERN_INFO "bnx2i: sess recovery %p complete\n", sess);
		sess->state = BNX2I_SESS_IN_FFP;
	} else
		return FAILED;

ret_success:
	sess->recovery_state = 0;
	return SUCCESS;
}


/**
 * bnx2i_iscsi_sess_release - cleanup iscsi session & reclaim all resources
 *
 * @hba: 		pointer to adapter instance
 * @sess:		iscsi session pointer
 *
 * free up resources held by this session including ITT queue, cmd struct pool,
 *	BD table pool. HBA lock is held while manipulating active session list
 */
void bnx2i_iscsi_sess_release(struct bnx2i_hba *hba, struct bnx2i_sess *sess)
{
	unsigned long flags;
	
	if (sess->login_nopout_cmd) {
		/* set cmd state so that free_cmd() accepts it */
		atomic_set(&sess->login_nopout_cmd->cmd_state,
			   ISCSI_CMD_STATE_COMPLETED);
		bnx2i_free_cmd(sess, sess->login_nopout_cmd);
	}
	if (sess->scsi_tmf_cmd) {
		atomic_set(&sess->scsi_tmf_cmd->cmd_state,
			   ISCSI_CMD_STATE_COMPLETED);
		bnx2i_free_cmd(sess, sess->scsi_tmf_cmd);
	}
	if (sess->nopout_resp_cmd) {
		atomic_set(&sess->nopout_resp_cmd->cmd_state,
			   ISCSI_CMD_STATE_COMPLETED);
		bnx2i_free_cmd(sess, sess->nopout_resp_cmd);
	}

	sess->login_nopout_cmd = NULL;
	sess->scsi_tmf_cmd = NULL;
	sess->nopout_resp_cmd = NULL;

	bnx2i_free_bd_table_pool(sess);
	bnx2i_free_all_bdt_resc_pages(sess);
	bnx2i_free_cmd_pool(sess);
	bnx2i_free_scsi_task_pool(sess);

	spin_lock_irqsave(&hba->lock, flags);
	list_del_init(&sess->link);
	hba->num_active_sess--;
	spin_unlock_irqrestore(&hba->lock, flags);
}


/**
 * bnx2i_iscsi_sess_new - initialize newly allocated session structure
 *
 * @hba: 		pointer to adapter instance
 * @sess:		iscsi session pointer
 *
 * initialize session structure elements and allocate per sess resources.
 *	Some of the per session resources allocated are command struct pool,
 *	BD table pool and ITT queue region
 */
int bnx2i_iscsi_sess_new(struct bnx2i_hba *hba, struct bnx2i_sess *sess)
{
	unsigned long flags;

	spin_lock_irqsave(&hba->lock, flags);
	list_add_tail(&sess->link, &hba->active_sess);
	hba->num_active_sess++;
	spin_unlock_irqrestore(&hba->lock, flags);

	sess->sq_size = hba->max_sqes;
	sess->tsih = 0;
	sess->lead_conn = NULL;
	sess->worker_time_slice = 2;

	spin_lock_init(&sess->lock);
	mutex_init(&sess->tmf_mutex);

	/* initialize active connection list */
	INIT_LIST_HEAD(&sess->conn_list);
	INIT_LIST_HEAD(&sess->free_cmds);

	INIT_LIST_HEAD(&sess->pend_cmd_list);
	sess->pend_cmd_count = 0;
	INIT_LIST_HEAD(&sess->active_cmd_list);
	sess->active_cmd_count = 0;

	atomic_set(&sess->login_noop_pending, 0);
	atomic_set(&sess->logout_pending, 0);
	atomic_set(&sess->tmf_pending, 0);

	sess->login_nopout_cmd = NULL;
	sess->scsi_tmf_cmd = NULL;
	sess->nopout_resp_cmd = NULL;

	sess->num_active_conn = 0;
	sess->max_conns = 1;
	sess->target_name = NULL;

	sess->state = BNX2I_SESS_INITIAL;
	sess->recovery_state = 0;
	atomic_set(&sess->tmf_active, 0);

	if (bnx2i_alloc_bd_table_pool(sess) != 0) {
		printk(KERN_ERR "sess_new: unable to alloc bd table pool\n");
		goto err_bd_pool;
	}

	if (bnx2i_alloc_cmd_pool(sess) != 0) {
		printk(KERN_ERR "sess_new: alloc cmd pool failed\n");
		goto err_cmd_pool;
	}

	if (bnx2i_alloc_scsi_task_pool(sess) != 0) {
		printk(KERN_ERR "sess_new: alloc scsi_task pool failed\n");
		goto err_sc_pool;
	}
	init_timer(&sess->abort_timer);
	init_waitqueue_head(&sess->er_wait);

	return 0;

err_sc_pool:
	bnx2i_free_cmd_pool(sess);
err_cmd_pool:
	bnx2i_free_bd_table_pool(sess);
err_bd_pool:
	return -ENOMEM;
}

/**
 * bnx2i_conn_free_login_resources - free DMA resources used for login process
 *
 * @hba: 		pointer to adapter instance
 * @conn: 		iscsi connection pointer
 *
 * Login related resources, mostly BDT & payload DMA memory is freed
 */
void bnx2i_conn_free_login_resources(struct bnx2i_hba *hba,
				     struct bnx2i_conn *conn)
{
	bnx2i_free_dma(hba, &conn->gen_pdu.login_req);
	bnx2i_free_dma(hba, &conn->gen_pdu.login_resp);
}

/**
 * bnx2i_conn_alloc_login_resources - alloc DMA resources used for
 *			login / nopout pdus
 *
 * @hba: 		pointer to adapter instance
 * @conn: 		iscsi connection pointer
 *
 * Login & nop-in related resources is allocated in this routine.
 */
static int bnx2i_conn_alloc_login_resources(struct bnx2i_hba *hba,
					    struct bnx2i_conn *conn)
{
	/* Allocate memory for login request/response buffers */
	if (bnx2i_alloc_dma(hba, &conn->gen_pdu.login_req,
			    ISCSI_CONN_LOGIN_BUF_SIZE, BNX2I_TBL_TYPE_BD, 0))
		goto error;

	conn->gen_pdu.req_buf_size = 0;
	conn->gen_pdu.req_wr_ptr = conn->gen_pdu.login_req.mem;

	if (bnx2i_alloc_dma(hba, &conn->gen_pdu.login_resp,
			    ISCSI_CONN_LOGIN_BUF_SIZE, BNX2I_TBL_TYPE_BD, 0))
		goto error;

	conn->gen_pdu.resp_buf_size = ISCSI_CONN_LOGIN_BUF_SIZE;
	conn->gen_pdu.resp_wr_ptr = conn->gen_pdu.login_resp.mem;
	
	return 0;

error:
	printk(KERN_ERR "bnx2i:a conn login resource alloc failed!!\n");
	bnx2i_conn_free_login_resources(hba, conn);
	return -ENOMEM;

}


/**
 * bnx2i_iscsi_conn_new - initialize newly created connection structure
 *
 * @sess:		iscsi session pointer
 * @conn: 		iscsi connection pointer
 *
 * connection structure is initialized which mainly includes allocation of
 *	login resources and lock/time initialization
 */
int bnx2i_iscsi_conn_new(struct bnx2i_sess *sess, struct bnx2i_conn *conn)
{
	struct bnx2i_hba *hba = sess->hba;

	conn->sess = sess;
	conn->header_digest_en = 0;
	conn->data_digest_en = 0;

	INIT_LIST_HEAD(&conn->link);

	/* 'ep' ptr will be assigned in bind() call */
	conn->ep = NULL;

	if (test_bit(BNX2I_NX2_DEV_57710, &hba->cnic_dev_type))
		conn->ring_doorbell = bnx2i_ring_sq_dbell_bnx2x;
	else
		conn->ring_doorbell = bnx2i_ring_sq_dbell_bnx2;

	if (bnx2i_conn_alloc_login_resources(hba, conn)) {
		printk(KERN_ALERT "conn_new: login resc alloc failed!!\n");
		return -ENOMEM;
	}


	atomic_set(&conn->stop_state, 0);
	atomic_set(&conn->worker_running, 0);
#ifdef __VMKLNX__
	tasklet_init(&conn->conn_tasklet, &bnx2i_conn_main_worker,
		     (unsigned long) conn);
	atomic_set(&conn->worker_enabled, 0);
#else
#if defined(INIT_DELAYED_WORK_DEFERRABLE) || defined(INIT_WORK_NAR)
	INIT_WORK(&conn->conn_worker, bnx2i_conn_main_worker);
#else
	INIT_WORK(&conn->conn_worker, bnx2i_conn_main_worker, conn); 
#endif
	atomic_set(&conn->worker_enabled, 1);
#endif 		/* __VMKLNX__ */

	init_timer(&conn->poll_timer);
	conn->poll_timer.expires = HZ + jiffies;	/* 200 msec */
	conn->poll_timer.function = bnx2i_conn_poll;
	conn->poll_timer.data = (unsigned long) conn;
	conn->poll_timer_enabled = 0;

	return 0;
}


/**
 * bnx2i_login_resp_update_cmdsn - extracts SN & MAX_SN from login response header &
 *			updates driver 'cmdsn' with 
 *
 * @conn: 		iscsi connection pointer
 *
 * extract & update SN counters from login response
 */
static int bnx2i_login_resp_update_cmdsn(struct bnx2i_conn *conn)
{
	u32 max_cmdsn;
	u32 exp_cmdsn;
	u32 stat_sn;
	struct bnx2i_sess *sess = conn->sess;
	struct iscsi_nopin *hdr;

	hdr = (struct iscsi_nopin *) &conn->gen_pdu.resp_hdr;

	max_cmdsn = ntohl(hdr->max_cmdsn);
	exp_cmdsn = ntohl(hdr->exp_cmdsn);
	stat_sn = ntohl(hdr->statsn);
#define SN_DELTA_ISLAND		0xffff
	if (max_cmdsn < exp_cmdsn -1 &&
	    max_cmdsn > exp_cmdsn - SN_DELTA_ISLAND)
		return -EINVAL;

	if (max_cmdsn > sess->max_cmdsn ||
	    max_cmdsn < sess->max_cmdsn - SN_DELTA_ISLAND)
		sess->max_cmdsn = max_cmdsn;

	if (exp_cmdsn > sess->exp_cmdsn ||
	    exp_cmdsn < sess->exp_cmdsn - SN_DELTA_ISLAND)
		sess->exp_cmdsn = exp_cmdsn;

	if (stat_sn == conn->exp_statsn)
		conn->exp_statsn++;

	return 0;
}


/**
 * bnx2i_update_cmd_sequence - update session sequencing parameter
 *
 * @sess:		iscsi session pointer
 * @exp_sn: 		iscsi expected command seq num
 * @max_sn: 		iscsi max command seq num
 *
 * update iSCSI SN counters for the given session
 */
void bnx2i_update_cmd_sequence(struct bnx2i_sess *sess,
			       u32 exp_sn, u32 max_sn)
{
	u32 exp_cmdsn = exp_sn;
	u32 max_cmdsn = max_sn;

	if (max_cmdsn < exp_cmdsn -1 &&
	    max_cmdsn > exp_cmdsn - SN_DELTA_ISLAND) {
		printk(KERN_ALERT "cmd_sequence: error, exp 0x%x, max 0x%x\n",
				   exp_cmdsn, max_cmdsn);
		BUG_ON(1);
	}
	if (max_cmdsn > sess->max_cmdsn ||
	    max_cmdsn < sess->max_cmdsn - SN_DELTA_ISLAND)
		sess->max_cmdsn = max_cmdsn;
	if (exp_cmdsn > sess->exp_cmdsn ||
	    exp_cmdsn < sess->exp_cmdsn - SN_DELTA_ISLAND)
		sess->exp_cmdsn = exp_cmdsn;
}


/**
 * bnx2i_process_scsi_resp - complete SCSI command processing by calling
 *			'scsi_done', free iscsi cmd structure to free list
 *
 * @cmd:		iscsi cmd pointer
 * @resp_cqe:		scsi response cqe pointer
 *
 * validates scsi response indication for normal completion, sense data if any
 *	underflow/overflow condition and propogates SCSI response to SCSI-ML by
 *	calling scsi_done() and also returns command struct back to free pool
 */
void bnx2i_process_scsi_resp(struct bnx2i_cmd *cmd,
			    struct iscsi_cmd_response *resp_cqe)
{
	struct scsi_cmnd *sc = cmd->scsi_cmd;
	u16 sense_data[128];
	int data_len;
	u16 sense_len;
	int res_count;
	u8 flags;

	sc->result = (DID_OK << 16) | resp_cqe->status;

	if (resp_cqe->response != ISCSI_STATUS_CMD_COMPLETED) {
		sc->result = (DID_ERROR << 16);
		goto out;
	}

	if (resp_cqe->status == SAM_STAT_CHECK_CONDITION) {
		data_len = resp_cqe->data_length;
		if (data_len < 2) {
invalid_len:
			printk(KERN_ERR "bnx2i: CHK_CONDITION - invalid "
					 "data length %d\n", data_len);
			sc->result = (DID_BAD_TARGET << 16);
			goto out;
		}

		if (data_len > BNX2I_RQ_WQE_SIZE) {
			printk(KERN_ALERT "bnx2i: sense data len %d > RQ sz\n",
					  data_len);
			data_len = BNX2I_RQ_WQE_SIZE;
		}
		if (data_len) {
			memset(sc->sense_buffer, 0, sizeof(sc->sense_buffer));
			bnx2i_get_rq_buf(cmd->conn, (char *)sense_data, data_len);
			bnx2i_put_rq_buf(cmd->conn, 1);
			cmd->conn->total_data_octets_rcvd += data_len;
			sense_len = be16_to_cpu(*((__be16 *) sense_data));

			if (data_len < sense_len)
				goto invalid_len;

			if (sense_len > SCSI_SENSE_BUFFERSIZE)
				sense_len = SCSI_SENSE_BUFFERSIZE;

			memcpy(sc->sense_buffer, &sense_data[1],
			       (int) sense_len);
		}
	}

	flags = resp_cqe->response_flags;
	if (flags & (ISCSI_CMD_RESPONSE_RESIDUAL_UNDERFLOW |
		     ISCSI_CMD_RESPONSE_RESIDUAL_OVERFLOW)) {
		res_count = resp_cqe->residual_count;

		if (res_count > 0 && (flags &
				      ISCSI_CMD_RESPONSE_RESIDUAL_OVERFLOW ||
		    		      res_count <= scsi_bufflen(sc))) {
			scsi_set_resid(sc, res_count);
			cmd->conn->total_data_octets_rcvd -= res_count;
		} else
			sc->result = (DID_BAD_TARGET << 16) | resp_cqe->status;
	}
out:
	return;

}

/**
 * bnx2i_indicate_login_resp - process iscsi login response
 *
 * @conn: 		iscsi connection pointer
 *
 * pushes login response PDU to application daemon, 'iscsid' by
 *		calling iscsi_recv_pdu()
 */
int bnx2i_indicate_login_resp(struct bnx2i_conn *conn)
{
	int data_len;
	struct iscsi_login_rsp *login_resp =
		(struct iscsi_login_rsp *) &conn->gen_pdu.resp_hdr;

	/* check if this is the first login response for this connection.
	 * If yes, we need to copy initial StatSN to connection structure.
	 */
	if (conn->exp_statsn == STATSN_UPDATE_SIGNATURE) {
		conn->exp_statsn = ntohl(login_resp->statsn) + 1;
	}

	if (bnx2i_login_resp_update_cmdsn(conn))
		return -EINVAL;

	data_len = conn->gen_pdu.resp_wr_ptr - conn->gen_pdu.resp_buf;
	iscsi_recv_pdu(conn->cls_conn, (struct iscsi_hdr *) login_resp,
		       (char *) conn->gen_pdu.resp_buf, data_len);

	return 0;
}


/**
 * bnx2i_indicate_logout_resp - process iscsi logout response
 *
 * @conn: 		iscsi connection pointer
 *
 * pushes logout response PDU to application daemon, 'iscsid' by
 *		calling iscsi_recv_pdu()
 */
int bnx2i_indicate_logout_resp(struct bnx2i_conn *conn)
{
	struct iscsi_logout_rsp *logout_resp =
		(struct iscsi_logout_rsp *) &conn->gen_pdu.resp_hdr;

	iscsi_recv_pdu(conn->cls_conn, (struct iscsi_hdr *) logout_resp,
		       (char *) NULL, 0);
	return 0;
}


/**
 * bnx2i_indicate_async_mesg - process iscsi ASYNC message indication
 *
 * @conn: 		iscsi connection pointer
 *
 * pushes iSCSI async PDU to application daemon, 'iscsid' by calling
 *	iscsi_recv_pdu()
 */
int bnx2i_indicate_async_mesg(struct bnx2i_conn *conn)
{
	struct iscsi_async *async_msg =
		(struct iscsi_async *) &conn->gen_pdu.async_hdr;

	printk("%s: indicating async message on cid %d\n", __FUNCTION__, conn->ep->ep_iscsi_cid);

	iscsi_recv_pdu(conn->cls_conn, (struct iscsi_hdr *) async_msg,
		       (char *) NULL, 0);
	return 0;
}



/**
 * bnx2i_process_nopin - process iscsi nopin pdu
 *
 * @conn: 		iscsi connection pointer
 * @cmd:		iscsi cmd pointer
 * @data_buf:		payload buffer pointer
 * @data_len:		payload length
 *
 * pushes nopin pdu to application daemon, 'iscsid' by calling iscsi_recv_pdu
 */
int bnx2i_process_nopin(struct bnx2i_conn *conn, struct bnx2i_cmd *cmd,
			char *data_buf, int data_len)
{
	struct iscsi_nopin *nopin_msg =
		(struct iscsi_nopin *) &conn->gen_pdu.nopin_hdr;

	iscsi_recv_pdu(conn->cls_conn, (struct iscsi_hdr *) nopin_msg,
		       (char *) data_buf, data_len);

	conn->sess->last_noopin_indicated = jiffies;
	conn->sess->noopin_indicated_count++;

	cmd->iscsi_opcode = 0;
	return 0;
}



/**
 * bnx2i_iscsi_prep_generic_pdu_bd - prepares BD table to be used with
 *			generic iscsi pdus
 *
 * @conn: 		iscsi connection pointer
 *
 * Allocates buffers and BD tables before shipping requests to cnic
 *	for PDUs prepared by 'iscsid' daemon
 */
static void bnx2i_iscsi_prep_generic_pdu_bd(struct bnx2i_conn *conn)
{
	struct iscsi_bd *bd_tbl;

	bd_tbl = (struct iscsi_bd *) conn->gen_pdu.login_req.pgtbl;

	bd_tbl->buffer_addr_hi =
		(u32) ((u64) conn->gen_pdu.login_req.mapping >> 32);
	bd_tbl->buffer_addr_lo = (u32) conn->gen_pdu.login_req.mapping;
	bd_tbl->buffer_length = conn->gen_pdu.req_wr_ptr -
				conn->gen_pdu.req_buf;
	bd_tbl->reserved0 = 0;
	bd_tbl->flags = ISCSI_BD_LAST_IN_BD_CHAIN |
			ISCSI_BD_FIRST_IN_BD_CHAIN;

	bd_tbl = (struct iscsi_bd  *) conn->gen_pdu.login_resp.pgtbl;
	bd_tbl->buffer_addr_hi = (u64) conn->gen_pdu.login_resp.mapping >> 32;
	bd_tbl->buffer_addr_lo = (u32) conn->gen_pdu.login_resp.mapping;
	bd_tbl->buffer_length = ISCSI_CONN_LOGIN_BUF_SIZE;
	bd_tbl->reserved0 = 0;
	bd_tbl->flags = ISCSI_BD_LAST_IN_BD_CHAIN |
			ISCSI_BD_FIRST_IN_BD_CHAIN;
}


/**
 * bnx2i_nopout_check_active_cmds - checks if iscsi link is idle
 *
 * @hba: 		pointer to adapter instance
 *
 * called to check if iscsi connection is idle or not. Pro-active nopout
 *	 is sent only if the link is idle
 */
static int bnx2i_nopout_check_active_cmds(struct bnx2i_conn *conn,
					  struct bnx2i_cmd *cmnd)
{
	struct iscsi_nopin *nopin_msg =
		(struct iscsi_nopin *) &conn->gen_pdu.resp_hdr;

	if ((conn->nopout_num_scsi_cmds == conn->num_scsi_cmd_pdus) &&
	    !conn->sess->active_cmd_count) {
		return -1;
	}

	memset(nopin_msg, 0x00, sizeof(struct iscsi_nopin));
        nopin_msg->opcode = ISCSI_OP_NOOP_IN;
        nopin_msg->flags = ISCSI_FLAG_CMD_FINAL;
        memcpy(nopin_msg->lun, conn->gen_pdu.nopout_hdr.lun, 8);
        nopin_msg->itt = conn->gen_pdu.nopout_hdr.itt;
        nopin_msg->ttt = ISCSI_RESERVED_TAG;
        nopin_msg->statsn = conn->gen_pdu.nopout_hdr.exp_statsn;
        nopin_msg->exp_cmdsn = htonl(conn->sess->exp_cmdsn);
        nopin_msg->max_cmdsn = htonl(conn->sess->max_cmdsn);

	iscsi_recv_pdu(conn->cls_conn, (struct iscsi_hdr *) nopin_msg,
		       (char *) NULL, 0);

	conn->nopout_num_scsi_cmds = conn->num_scsi_cmd_pdus;
	return 0;
}


/**
 * bnx2i_iscsi_send_generic_request - called to send iscsi login/nopout/logout
 *			pdus
 *
 * @hba: 		pointer to adapter instance
 *
 * called to transmit PDUs prepared by the 'iscsid' daemon. iSCSI login,
 *	Nop-out and Logout requests flow through this path.
 */
static int bnx2i_iscsi_send_generic_request(struct bnx2i_cmd *cmnd)
{
	int rc = 0;
	struct bnx2i_conn *conn = cmnd->conn;

	bnx2i_iscsi_prep_generic_pdu_bd(conn);
	switch (cmnd->iscsi_opcode & ISCSI_OPCODE_MASK) {
	case ISCSI_OP_LOGIN:
		bnx2i_send_iscsi_login(conn, cmnd);
		break;

	case ISCSI_OP_NOOP_OUT:
		if (!bnx2i_nopout_when_cmds_active)
			if (!bnx2i_nopout_check_active_cmds(conn, cmnd)) {
				return 0;
			}

		conn->nopout_num_scsi_cmds = conn->num_scsi_cmd_pdus;
		rc = bnx2i_send_iscsi_nopout(conn, cmnd, NULL, 0);
		break;

	case ISCSI_OP_LOGOUT:
		rc = bnx2i_send_iscsi_logout(conn, cmnd);
		break;

	default:
		printk(KERN_ALERT "send_gen: unsupported op 0x%x\n",
				   cmnd->iscsi_opcode);
	}
	return rc;
}


/**********************************************************************
 *		SCSI-ML Interface
 **********************************************************************/

/**
 * bnx2i_cpy_scsi_cdb - copies LUN & CDB fields in required format to sq wqe
 *
 * @sc: 		SCSI-ML command pointer
 * @cmd:		iscsi cmd pointer
 *
 */
static void bnx2i_cpy_scsi_cdb(struct scsi_cmnd *sc,
				      struct bnx2i_cmd *cmd)
{
	u32 dword;
	int lpcnt;
	u8 *srcp;
	u32 *dstp;
	u32 scsi_lun[2];

	int_to_scsilun(sc->device->lun, (struct scsi_lun *) scsi_lun);
	cmd->req.lun[0] = ntohl(scsi_lun[0]);
	cmd->req.lun[1] = ntohl(scsi_lun[1]);

	lpcnt = cmd->scsi_cmd->cmd_len / sizeof(dword);
	srcp = (u8 *) sc->cmnd;
	dstp = (u32 *) cmd->req.cdb;
	while (lpcnt--) {
		memcpy(&dword, (const void *) srcp, 4);
		*dstp = cpu_to_be32(dword);
		srcp += 4;
		dstp++;
	}
	if (sc->cmd_len & 0x3) {
		dword = (u32) srcp[0] | ((u32) srcp[1] << 8);
		*dstp = cpu_to_be32(dword);
	}
}


#ifdef __VMKLNX__
static int bnx2i_slave_configure(struct scsi_device *sdev)
{
	return 0;
}

static int bnx2i_slave_alloc(struct scsi_device *sdev)
{
	struct iscsi_cls_session *cls_sess;

	cls_sess = vmk_iscsi_getSessionFromTarget(sdev->host->host_no,
						     sdev->channel, sdev->id);
	if (!cls_sess)
		return FAILED;

	sdev->hostdata = cls_sess->dd_data;
	return 0;
}

static int bnx2i_target_alloc(struct scsi_target *starget)
{
	struct iscsi_cls_session *cls_sess;
	struct Scsi_Host *shost = dev_to_shost(starget->dev.parent);

	cls_sess = vmk_iscsi_getSessionFromTarget(shost->host_no,
						  starget->channel, starget->id);
	if (!cls_sess)
		return FAILED;

	starget->hostdata = cls_sess->dd_data;
	return 0;
}

static void bnx2i_target_destroy(struct scsi_target *starget)
{
	struct bnx2i_sess *sess = starget->hostdata;

	if (!sess)
		return;

	if (sess->state == BNX2I_SESS_DESTROYED)
		bnx2i_release_session_resc(sess->cls_sess);
	else
		sess->state = BNX2I_SESS_TARGET_DESTROYED;
}
#endif


#define BNX2I_SERIAL_32 2147483648UL

static int iscsi_cmd_win_closed(struct bnx2i_sess *sess)
{
	u32 cmdsn = sess->cmdsn;
	u32 maxsn = sess->max_cmdsn;

	return ((cmdsn < maxsn && (maxsn - cmdsn > BNX2I_SERIAL_32)) ||
		 (cmdsn > maxsn && (cmdsn - maxsn < BNX2I_SERIAL_32)));
		
}


/**
 * bnx2i_queuecommand - SCSI ML - bnx2i interface function to issue new commands
*			to be shipped to iscsi target
 *
 * @sc: 		SCSI-ML command pointer
 * @done: 		callback function pointer to complete the task
 *
 * handles SCSI command queued by SCSI-ML, allocates a command structure,
 *	assigning CMDSN, mapping SG buffers and delivers it to CNIC for further
 *	processing. This routine also takes care of iSCSI command window full
 *	condition, if session is in recovery process and other error conditions
 */
int bnx2i_queuecommand(struct scsi_cmnd *sc,
		       void (*done) (struct scsi_cmnd *))
{
	struct bnx2i_scsi_task *scsi_task;
	unsigned long flags;
	struct bnx2i_sess *sess;
	struct bnx2i_conn *conn;
#if !defined(__VMKLNX__)
	struct Scsi_Host *shost;
#endif

#ifdef __VMKLNX__
	if (sc->device && sc->device->hostdata)
		sess = (struct bnx2i_sess *)sc->device->hostdata;
	else
		goto dev_not_found;
#else
	sess = bnx2i_get_sess_from_shost(sc->device->host);
#endif
	sc->scsi_done = done;
	sc->result = 0;

	if (!sess)
		goto dev_not_found;

#ifdef __VMKLNX__
	if (sess->state == BNX2I_SESS_DESTROYED)
		goto dev_offline;
#endif
	if (sess->state == BNX2I_SESS_IN_SHUTDOWN ||
	    sess->state == BNX2I_SESS_IN_LOGOUT || !sess->lead_conn)
		/* delay offline indication till session is destroyed */
		goto cmd_not_accepted;

	if (sess->recovery_state) {
		if (sess->recovery_state & ISCSI_SESS_RECOVERY_START)
			goto cmd_not_accepted;
		else if (sess->recovery_state & ISCSI_SESS_RECOVERY_COMPLETE)
			sess->recovery_state = 0;
		else
			goto dev_not_found;
	}

	conn = sess->lead_conn;
	/* Is connection stopped because of nopout timeout?. Don't accept scsi_cmds
	 * if connection is in stopped state because we don't know if it's going
	 * come online or taken offline after session recovery timeout */
        if (!atomic_read(&conn->worker_enabled))
		goto cmd_not_accepted;

	spin_lock_irqsave(&sess->lock, flags);
	scsi_task = bnx2i_alloc_scsi_task(sess);
	if (!scsi_task) {
		spin_unlock_irqrestore(&sess->lock, flags);
		goto cmd_not_accepted;
	}

	scsi_task->scsi_cmd = sc;
	list_add_tail(&scsi_task->link, &sess->pend_cmd_list);
	sess->pend_cmd_count++;
	spin_unlock_irqrestore(&sess->lock, flags);

        if (atomic_read(&conn->worker_enabled)) {
#ifdef __VMKLNX__
		tasklet_schedule(&conn->conn_tasklet);
#else
		shost = bnx2i_conn_get_shost(conn);
		scsi_queue_work(shost, &conn->conn_worker);
#endif		/* __VMKLNX__ */
	}
	return 0;

cmd_not_accepted:
	return SCSI_MLQUEUE_HOST_BUSY;

#ifdef __VMKLNX__
dev_offline:
#endif
dev_not_found:
	sc->result = (DID_NO_CONNECT << 16);
	scsi_set_resid(sc, scsi_bufflen(sc));
	sc->scsi_done(sc);
	return 0;
}

static void bnx2i_conn_poll(unsigned long data)
{
	struct bnx2i_conn *conn = (struct bnx2i_conn *) data;
#if !defined(__VMKLNX__)
	struct Scsi_Host *shost;
#endif

	if (!atomic_read(&conn->worker_enabled))
		goto exit;
	if (bnx2i_cqe_work_pending(conn) ||
	    !list_empty(&conn->sess->pend_cmd_list)) {
#ifdef __VMKLNX__
		tasklet_schedule(&conn->conn_tasklet);
#else
	shost = bnx2i_conn_get_shost(conn);
	scsi_queue_work(shost, &conn->conn_worker);
#endif
	}
exit:
	conn->poll_timer.expires = HZ / 2 + jiffies;	/* 500 msec */
	add_timer(&conn->poll_timer);
}


/**
 * bnx2i_fail_cmd - fail the command back to SCSI-ML
 *
 * @sess: 		iscsi sess pointer
 * @cmd: 		command pointer
 *
 * 	Return failed command to SCSI-ML.
 */
void bnx2i_fail_cmd(struct bnx2i_sess *sess, struct bnx2i_cmd *cmd)
{
	struct scsi_cmnd *sc;
	int reason;

	bnx2i_iscsi_unmap_sg_list(sess->hba, cmd);

	spin_lock_bh(&sess->lock);
	sc = cmd->scsi_cmd;
	reason = cmd->failed_reason;
	cmd->req.itt &= ISCSI_CMD_RESPONSE_INDEX;
	atomic_set(&cmd->cmd_state, ISCSI_CMD_STATE_COMPLETED);
	sess->active_cmd_count--;
	cmd->scsi_cmd = NULL;
	bnx2i_free_cmd(sess, cmd);
	spin_unlock_bh(&sess->lock);

	bnx2i_return_failed_command(sess, sc, scsi_bufflen(sc), reason);
}

struct bnx2i_scsi_task *bnx2i_scsi_cmd_in_pend_list(struct bnx2i_sess *sess,
						    struct scsi_cmnd *sc)
{
	struct bnx2i_scsi_task *scsi_task;
	struct list_head *list;
	struct list_head *tmp;

	list_for_each_safe(list, tmp, &sess->pend_cmd_list) {
		scsi_task = (struct bnx2i_scsi_task *) list;
		if (scsi_task->scsi_cmd == sc)
			return scsi_task;
	}
	return NULL;
}

/**
 * bnx2i_send_tmf_wait_cmpl - executes scsi command abort process
 *
 * @sc: 		SCSI-ML command pointer
 *
 * initiate command abort process by requesting CNIC to send
 *	an iSCSI TMF request to target
 */
static int bnx2i_send_tmf_wait_cmpl(struct bnx2i_sess *sess)
{
	int rc = 0;
	struct bnx2i_cmd *tmf_cmd = sess->scsi_tmf_cmd;
	struct bnx2i_conn *conn = sess->lead_conn;
#ifndef __VMKLNX__
	struct Scsi_Host *shost = bnx2i_conn_get_shost(conn);
#endif

	tmf_cmd->tmf_response = ISCSI_TMF_RSP_REJECTED;

	/* Schedule the tasklet to send out the TMF pdu */
	atomic_set(&sess->tmf_pending, 1);
        if (atomic_read(&conn->worker_enabled)) {
#ifdef __VMKLNX__
		printk("bnx2i: scheduling TMF for cid %d\n", conn->ep->ep_iscsi_cid);
		tasklet_schedule(&conn->conn_tasklet);
#else
		scsi_queue_work(shost, &conn->conn_worker);
#endif
	}

#define BNX2I_TMF_TIMEOUT	10 * HZ
	/* Now we wait here */
	rc = wait_event_timeout(sess->er_wait,
				((sess->recovery_state != 0) ||
				 (atomic_read(&tmf_cmd->cmd_state) != 
				  ISCSI_CMD_STATE_INITIATED)),
				BNX2I_TMF_TIMEOUT);

	if (signal_pending(current))
		flush_signals(current);

	if (!rc) {
		atomic_set(&tmf_cmd->cmd_state, ISCSI_CMD_STATE_TMF_TIMEOUT);
		sess->recovery_state = ISCSI_SESS_RECOVERY_OPEN_ISCSI;
		iscsi_conn_error(conn->cls_conn, ISCSI_ERR_CONN_FAILED);
		/* set conn->stop_state to non-zero so that further TMF will not
		 *  be allowed to seek in, this halt is only required untill 
		 *  'vmkiscsid' issues conn_stop()
		 */
		atomic_set(&conn->stop_state, 0xFF);
		atomic_set(&sess->tmf_pending, 0);
		atomic_set(&sess->tmf_active, 0);
		return -1;
	}



	if (atomic_read(&sess->tmf_pending))
		printk("%s:: WaTcH: is tmf still pending \n", __FUNCTION__);

	if (tmf_cmd->tmf_response == ISCSI_TMF_RSP_COMPLETE) {
	/* normal successs case */
		return 0;
	} else if (tmf_cmd->tmf_response == ISCSI_TMF_RSP_NO_TASK) {
		if (tmf_cmd->tmf_ref_cmd->scsi_cmd == tmf_cmd->tmf_ref_sc) {
			if (atomic_read(&tmf_cmd->tmf_ref_cmd->cmd_state) == ISCSI_CMD_STATE_COMPLETED) {
				/* task completed while tmf request is pending, driver is
				 * holding on to the completion 
				 */
				return 0;
			} else {
				/* missing command, do session recovery */
				goto do_recovery;
			}
		} else {
			return 0; /* command already completed */
		}
	}

do_recovery:
	printk(KERN_ALERT "%s: tmf failed, cmd 0x%p\n", __FUNCTION__, tmf_cmd);
#ifdef __VMKLNX__
	bnx2i_do_iscsi_sess_recovery(sess, DID_RESET);
#endif
	return -1;
}

static void bnx2i_cleanup_task_context(struct bnx2i_sess *sess,
					struct bnx2i_cmd *cmd, int reason)
{
	if (!cmd->scsi_cmd)
		return;

	/* cleanup on chip task context for command affected by
	 * ABORT_TASK/LUN_RESET
	 */
	cmd->failed_reason = reason;
	atomic_set(&cmd->cmd_state, ISCSI_CMD_STATE_CLEANUP_PEND);
	sess->cmd_cleanup_req++;
	bnx2i_send_cmd_cleanup_req(sess->hba, cmd);
}

/**
 * bnx2i_initiate_target_reset- executes scsi command target reset
 *
 * @sc: 		SCSI-ML command pointer
 *
 * initiate command abort process by requesting CNIC to send
 *	an iSCSI TMF request to target
 */
static int bnx2i_initiate_target_reset(struct bnx2i_sess *sess)
{
	struct bnx2i_cmd *tmf_cmd;
	struct bnx2i_hba *hba;

	hba = sess->hba;
	tmf_cmd = sess->scsi_tmf_cmd;
	atomic_set(&sess->tmf_active, 1);
	tmf_cmd->conn = sess->lead_conn;
	tmf_cmd->scsi_cmd = NULL;
	tmf_cmd->iscsi_opcode = ISCSI_OP_SCSI_TMFUNC | ISCSI_OP_IMMEDIATE;
	tmf_cmd->tmf_func = ISCSI_TM_FUNC_TARGET_WARM_RESET;
	tmf_cmd->tmf_lun = 0;
	tmf_cmd->tmf_ref_itt = ISCSI_RESERVED_TAG;
	tmf_cmd->tmf_ref_cmd = NULL;
	tmf_cmd->tmf_ref_sc = NULL;
	atomic_set(&tmf_cmd->cmd_state, ISCSI_CMD_STATE_INITIATED);

	printk("%s: sess %p, conn %p\n", __FUNCTION__, sess, sess->lead_conn);
	return 0;
}


/**
 * bnx2i_initiate_lun_reset- executes scsi command abort process
 *
 * @sc: 		SCSI-ML command pointer
 *
 * initiate command abort process by requesting CNIC to send
 *	an iSCSI TMF request to target
 */
static int bnx2i_initiate_lun_reset(struct bnx2i_sess *sess, struct scsi_cmnd *sc)
{
	struct bnx2i_cmd *tmf_cmd;
	struct bnx2i_conn *conn;
	struct bnx2i_hba *hba;

	hba = sess->hba;
	tmf_cmd = sess->scsi_tmf_cmd;
	atomic_set(&sess->tmf_active, 1);
	tmf_cmd->conn = conn = sess->lead_conn;
	tmf_cmd->scsi_cmd = NULL;
	tmf_cmd->iscsi_opcode = ISCSI_OP_SCSI_TMFUNC | ISCSI_OP_IMMEDIATE;
	tmf_cmd->tmf_func = ISCSI_TM_FUNC_LOGICAL_UNIT_RESET;
	tmf_cmd->tmf_lun = sc->device->lun;
	tmf_cmd->tmf_ref_itt = ISCSI_RESERVED_TAG;
	tmf_cmd->tmf_ref_cmd = NULL;
	tmf_cmd->tmf_ref_sc = NULL;
	atomic_set(&tmf_cmd->cmd_state, ISCSI_CMD_STATE_INITIATED);

	return 0;
}

/**
 * bnx2i_initiate_abort_cmd - executes scsi command abort process
 *
 * @sc: 		SCSI-ML command pointer
 *
 * initiate command abort process by requesting CNIC to send
 *	an iSCSI TMF request to target
 */
static int bnx2i_initiate_abort_cmd(struct bnx2i_sess *sess, struct scsi_cmnd *sc,
				    struct bnx2i_cmd **aborted_cmd)
{
	struct bnx2i_cmd *cmd;
	struct bnx2i_cmd *tmf_cmd;
	struct bnx2i_conn *conn;
	struct bnx2i_hba *hba;

	*aborted_cmd = NULL;
	hba = sess->hba;
	cmd = (struct bnx2i_cmd *) sc->SCp.ptr;

	if (!cmd || !cmd->scsi_cmd || cmd->scsi_cmd != sc) {
		/* command already completed to scsi mid-layer */
		printk("%s: WaTcH: sc %p on lun %x, already completed\n",
			__FUNCTION__, sc, sc->device->lun);
		return -ENOENT;
	}

	*aborted_cmd = cmd;
	tmf_cmd = sess->scsi_tmf_cmd;
	atomic_set(&sess->tmf_active, 1);
	atomic_set(&cmd->cmd_state, ISCSI_CMD_STATE_ABORT_PEND);
	atomic_set(&tmf_cmd->cmd_state, ISCSI_CMD_STATE_INITIATED);
	tmf_cmd->conn = conn = sess->lead_conn;
	tmf_cmd->scsi_cmd = NULL;
	tmf_cmd->iscsi_opcode = ISCSI_OP_SCSI_TMFUNC | ISCSI_OP_IMMEDIATE;
	tmf_cmd->tmf_func = ISCSI_TM_FUNC_ABORT_TASK;
	tmf_cmd->tmf_lun = sc->device->lun;
	tmf_cmd->tmf_ref_itt = cmd->req.itt;
	tmf_cmd->tmf_ref_cmd = cmd;
	tmf_cmd->tmf_ref_sc = cmd->scsi_cmd;
	printk("%s [ %lx ] : aborting active cmd sc %p, lun %x"
		" ref_cmd %p, ref_scsi_cmd %p \n", __FUNCTION__,
		jiffies, sc, sc->device->lun, tmf_cmd->tmf_ref_cmd,
		tmf_cmd->tmf_ref_sc);

	return -EINPROGRESS;
}


static void bnx2i_tmf_wait_dev_offlined(struct bnx2i_sess *sess)
{
	/* Still some clarification on this subject is going on with Vmware team
	 * Code will be added later
	 */
}


/**
 * bnx2i_execute_tmf_cmd - executes scsi tmf
 *
 * @sc: 		SCSI-ML command pointer
 *
 * initiate scsi tmf, support ABORT_TASK and LUN_RESET
 */
static int bnx2i_execute_tmf_cmd(struct scsi_cmnd *sc, int tmf_func)
{
	int active_cmds_failed = 0;
	int pend_cmds_failed = 0;
	struct bnx2i_cmd *cmd = NULL;
#ifndef __VMKLNX__
	struct Scsi_Host *shost;
#endif
	struct bnx2i_sess *sess = NULL;
	int rc = FAILED;
	int wait_rc;

#ifdef __VMKLNX__
	if (sc->device && sc->device->hostdata)
		sess = (struct bnx2i_sess *)sc->device->hostdata;
#else
	shost = sc->device->host;
	sess = bnx2i_get_sess_from_shost(shost);
	BUG_ON(shost != sess->shost);
#endif
	if (sess == NULL) {
		printk("%s: TMF session=NULL\n", __FUNCTION__);
		return FAILED;
	}

	mutex_lock(&sess->tmf_mutex);

	if (test_bit(ADAPTER_STATE_GOING_DOWN, &sess->hba->adapter_state) ||
	    test_bit(ADAPTER_STATE_LINK_DOWN, &sess->hba->adapter_state)) {
		printk("%s: TMF session LINK\n", __FUNCTION__);
		mutex_unlock(&sess->tmf_mutex);
		return FAILED;
	}

	spin_lock_bh(&sess->lock);
	if (!sess || atomic_read(&sess->lead_conn->stop_state) ||
	    !is_sess_active(sess)) {
		printk("%s: TMF session stoped\n", __FUNCTION__);
		/* better to wait till device is offlined to avoid ABORT storm
		 */
		spin_unlock_bh(&sess->lock);
		bnx2i_tmf_wait_dev_offlined(sess);
		mutex_unlock(&sess->tmf_mutex);
		return FAILED;
	}

	atomic_set(&sess->tmf_active, 1);
	if (tmf_func == ISCSI_TM_FUNC_ABORT_TASK) {
		rc = bnx2i_initiate_abort_cmd(sess, sc, &cmd);
		if (rc == -ENOENT) {
			/* cmd not active */
			rc = FAILED;
			spin_unlock_bh(&sess->lock);
			goto done;
		}
		rc = SUCCESS;
	} else if (tmf_func == ISCSI_TM_FUNC_LOGICAL_UNIT_RESET) {
		bnx2i_initiate_lun_reset(sess, sc);
	} else if (tmf_func == ISCSI_TM_FUNC_TARGET_WARM_RESET) {
		printk("%s: tmf TGT_RESET, sess %p\n", __FUNCTION__, sess);
		bnx2i_initiate_target_reset(sess);
	} else {
		printk(KERN_ALERT "bnx2i: unknown Task Mgmt Command %x\n",
		       tmf_func);
		rc = FAILED;
		spin_unlock_bh(&sess->lock);
		goto done;
	}
	spin_unlock_bh(&sess->lock);

	printk("%s: tmf wait......., sess %p\n", __FUNCTION__, sess);
	if (bnx2i_send_tmf_wait_cmpl(sess)) {
		/* TMF request timeout */
		rc = FAILED;
		goto done;
	}

	sess->cmd_cleanup_req = 0;
	sess->cmd_cleanup_cmpl = 0;

	if (sess->scsi_tmf_cmd->tmf_response == ISCSI_TMF_RSP_COMPLETE) {
		if (tmf_func == ISCSI_TM_FUNC_ABORT_TASK) {
			if (cmd->scsi_status_rcvd) {
				/* cmd completed while TMF was active.
				 * Now it's safe to complete command
				 * to SCSI-ML
				 */
				bnx2i_complete_cmd(sess, cmd);
			} else {
				bnx2i_cleanup_task_context(sess, cmd, DID_ABORT);
			}
			active_cmds_failed = 1;
		} else if (tmf_func == ISCSI_TM_FUNC_LOGICAL_UNIT_RESET) {
			/* Pend queue is already flushed before issuing send TMF
			 * request on wire. This is just a redundant flush which
			 * should do allow us to detect any command queued while
			 * TMF is active
			 */
			pend_cmds_failed = bnx2i_flush_pend_queue(sess, sc, DID_RESET);
			active_cmds_failed = bnx2i_flush_cmd_queue(sess, sc, DID_RESET, 1);
		} else if (tmf_func == ISCSI_TM_FUNC_TARGET_WARM_RESET) {
			/* pend queue- Same comments as LUN RESET holds good here */
			pend_cmds_failed = bnx2i_flush_pend_queue(sess, NULL, DID_RESET);
			active_cmds_failed = bnx2i_flush_cmd_queue(sess, NULL, DID_RESET, 1);
		}
		rc = SUCCESS;
	} else if ((sess->scsi_tmf_cmd->tmf_response == ISCSI_TMF_RSP_NO_TASK) &&
		   (tmf_func == ISCSI_TM_FUNC_ABORT_TASK)) {
		if (!cmd->scsi_cmd ||
		    (cmd->scsi_cmd != sess->scsi_tmf_cmd->tmf_ref_sc)) {
			/* command already completed, later case cmd is being
			 * reused for a different I/O
			 */
			rc = FAILED;
		} else if (cmd->scsi_status_rcvd) {
			/* cmd completed while TMF was active. Now it's safe
			 * to complete the command back to SCSI-ML
			 */
			bnx2i_complete_cmd(sess, cmd);
			rc = FAILED;
		} else {
			/* we should never step into this code path as missing command
			 * will trigger session recovery in  bnx2i_send_tmf_wait_cmpl()
			 */
			BUG_ON(1);
		}
	} else
		rc = FAILED;

	wait_rc = wait_event_interruptible_timeout(sess->er_wait,
			!is_sess_active(sess) ||
			(sess->cmd_cleanup_req == sess->cmd_cleanup_cmpl),
			30 * HZ);

	if (!is_sess_active(sess)) {
		/* session went into recovery due to protocol error, there won't
		 * be any CQ completions, active command cleanup will continue
		 * in ep_disconnect()
		 */
		printk("%s: session in recovery\n", __FUNCTION__);
		rc = FAILED;
	} else if (!wait_rc) {
		printk("%s: WaTcH - cleanup did not complete in 30 seconds\n",
			__FUNCTION__);
		/* If TCP layer is working fine, CMD_CLEANUP should complete
		 * 'Cuz all CMD before TMF REQ would have been TCP ACK'ed.
		 * If there is a problem with the TCP layer, TMF request should
		 * have timed out triggering session recovery
		 */
		BUG_ON(1);
	}

	if (signal_pending(current))
		flush_signals(current);
	printk("%s: WaTcH - async cmd cleanup - requested %d, completed %d\n",
		__FUNCTION__, sess->cmd_cleanup_req, sess->cmd_cleanup_cmpl);

done:
	barrier();
	atomic_set(&sess->tmf_active, 0);
	mutex_unlock(&sess->tmf_mutex);

	return rc;
}

static void bnx2i_wait_for_tmf_completion(struct bnx2i_sess *sess)
{
	int lpcnt = 200;

	while (lpcnt-- && atomic_read(&sess->tmf_active))
		msleep(100);
}

/**
 * bnx2i_abort - 'eh_abort_handler' api function to abort an oustanding
 *			scsi command
 *
 * @sc: 		SCSI-ML command pointer
 *
 * SCSI abort request handler.
 */
int bnx2i_abort(struct scsi_cmnd *sc)
{
	int reason;
	struct bnx2i_hba *hba;
	struct bnx2i_cmd *cmd = (struct bnx2i_cmd *) sc->SCp.ptr;
	struct bnx2i_sess *sess;

#ifdef __VMKLNX__
	if (sc->device && sc->device->hostdata)
		sess = (struct bnx2i_sess *)sc->device->hostdata;
#else
	struct Scsi_Host *shost = sc->device->host;
	sess = bnx2i_get_sess_from_shost(shost);
#endif


	/**
	 * we can ALWAYS abort from the pending queue
	 * since it has not made it to the chip yet
	 * NOTE: the queue has to be protected via spin lock
	 */
	spin_lock_bh(&sess->lock);
	if (sc->device && sc->device->hostdata) {
		struct bnx2i_scsi_task *scsi_task;
		hba = sess->hba;
		scsi_task = bnx2i_scsi_cmd_in_pend_list(sess, sc);
		if (scsi_task) {
			sc->result = (DID_ABORT << 16);
			list_del_init(&scsi_task->link);
			bnx2i_free_scsi_task(sess, scsi_task);
			spin_unlock_bh(&sess->lock);
			bnx2i_return_failed_command(sess, sc,
						    scsi_bufflen(sc), DID_ABORT);
			printk(KERN_INFO "%s: aborted from pending queue\n",
					 __FUNCTION__);
			return SUCCESS;
      		}
	}

	/** It wasn't in the pending queue... and it still has no cmd object
	 * it must have completed out.
	 */
	if (unlikely(!cmd) || cmd->scsi_cmd != sc) {
		/* command already completed to scsi mid-layer */
		printk(KERN_INFO "bnx2i_abort: sc 0x%p, lun %d is not active\n",
				 sc, sc->device->lun);
		spin_unlock_bh(&sess->lock);
		return FAILED;
	}

	if ((atomic_read(&cmd->cmd_state) != ISCSI_CMD_STATE_INITIATED) ||
	    !cmd->conn->ep) {
		/* Command completion is being processed, fail the abort request
		 * Second condition should never be true unless SCSI layer is
		 * out of sync
		 */
		spin_unlock_bh(&sess->lock);
		return FAILED;
	}
	/* Set cmd_state so that command will not be completed to SCSI-ML
	 * if SCSI_RESP is rcvd for this command
	 */
	atomic_set(&cmd->cmd_state, ISCSI_CMD_STATE_ABORT_REQ);
	spin_unlock_bh(&sess->lock);

	reason = bnx2i_execute_tmf_cmd(sc, ISCSI_TM_FUNC_ABORT_TASK);
	return reason;
}



/**
 * bnx2i_return_failed_command - return failed command back to SCSI-ML
 *
 * @sess:		iscsi session pointer
 * @cmd:		iscsi cmd pointer
 * @reason: 		SCSI-ML error code, DID_ABORT, DID_BUS_BUSY
 *
 * completes scsi command with appropriate error code to SCSI-ML
 */
void bnx2i_return_failed_command(struct bnx2i_sess *sess, struct scsi_cmnd *sc,
				 int resid, int reason)
{
	sc->result = reason << 16;
	scsi_set_resid(sc, resid);
	sc->SCp.ptr = NULL;
	sc->scsi_done(sc);
}


#ifdef __VMKLNX__
/**
 * bnx2i_host_reset - 'eh_host_reset_handler' entry point
 *
 * @sc: 		SCSI-ML command pointer
 *
 * SCSI host reset handler - Do iSCSI session recovery on all active sessions
 */
int bnx2i_host_reset(struct scsi_cmnd *sc)
{
	struct Scsi_Host *shost;
	struct bnx2i_sess *sess;
	struct bnx2i_conn *conn;
	struct bnx2i_hba *hba;
        int i = 0;

	shost = sc->device->host;
	sess = (struct bnx2i_sess *)sc->device->hostdata;
	hba = sess->hba;

	printk(KERN_INFO "bnx2i: reseting host %d\n", shost->host_no);

        for (i = 0; i < hba->max_active_conns; i++) {
                conn = bnx2i_get_conn_from_id(hba, i);
                if (!conn) continue;

		printk(KERN_INFO "bnx2i: reseting sess %d\n", conn->ep->ep_iscsi_cid);
		bnx2i_do_iscsi_sess_recovery(conn->sess, DID_RESET);
        }
	return 0;
}


/**
 * bnx2i_device_reset - 'eh_device_reset_handler' entry point
 *
 * @sc: 		SCSI-ML command pointer
 *
 * SCSI host reset handler - iSCSI session recovery
 */
int bnx2i_device_reset (struct scsi_cmnd *sc)
{
	struct bnx2i_sess *sess;
	int rc = 0;

	sess = (struct bnx2i_sess *)sc->device->hostdata;
	if (!sess || !sess->lead_conn || !sess->lead_conn->ep ||
	    atomic_read(&sess->lead_conn->stop_state))
		return FAILED;

	printk(KERN_INFO "bnx2i: device reset, iscsi cid %d, lun %x\n",
			 sess->lead_conn->ep->ep_iscsi_cid, sc->device->lun);

	if (sc->vmkflags & VMK_FLAGS_USE_LUNRESET) {
		/* LUN reset */
		printk("%s : LUN RESET request, sc %p\n", __FUNCTION__, sc);
		rc = bnx2i_execute_tmf_cmd(sc, ISCSI_TM_FUNC_LOGICAL_UNIT_RESET);
	} else {
		/* TARGET reset */
		printk("%s : Target Reset Request, sc %p, lun %x, sess %p\n",
			__FUNCTION__, sc, sc->device->lun, sess);
		rc = bnx2i_execute_tmf_cmd(sc, ISCSI_TM_FUNC_TARGET_WARM_RESET);
	}
	return rc;
}

#else
/**
 * bnx2i_host_reset - 'eh_host_reset_handler' entry point
 *
 * @sc: 		SCSI-ML command pointer
 *
 * SCSI host reset handler - iSCSI session recovery
 */
int bnx2i_host_reset(struct scsi_cmnd *sc)
{
	struct Scsi_Host *shost;
	struct bnx2i_sess *sess;
	int rc = 0;

	shost = sc->device->host;
	sess = bnx2i_get_sess_from_shost(shost);
	printk(KERN_INFO "bnx2i: attempting to reset host, #%d\n",
			  sess->shost->host_no);

	BUG_ON(shost != sess->shost);
	rc = bnx2i_do_iscsi_sess_recovery(sess, DID_RESET);


	return rc;
}
#endif

int bnx2i_cqe_work_pending(struct bnx2i_conn *conn)
{
	struct qp_info *qp;
	volatile struct iscsi_nop_in_msg *nopin;
	int exp_seq_no;

	if (conn->ep)
		qp = &conn->ep->qp;
	else
		return 0;
	nopin = (struct iscsi_nop_in_msg *)qp->cq_cons_qe;

	exp_seq_no = conn->ep->qp.cqe_exp_seq_sn;
	if (exp_seq_no > qp->cqe_size * 2)
		exp_seq_no -= qp->cqe_size * 2;

	if (nopin->cq_req_sn ==  exp_seq_no) {
		return 1;
	} else
		return 0;
}



static void bnx2i_process_control_pdu(struct bnx2i_sess *sess)
{
	unsigned long flags;

	spin_lock_irqsave(&sess->lock, flags);
        if (atomic_read(&sess->tmf_pending)) {
		bnx2i_send_iscsi_tmf(sess->lead_conn, sess->scsi_tmf_cmd);
		atomic_set(&sess->tmf_pending, 0);
	}
        if (atomic_read(&sess->nop_resp_pending)) {
		bnx2i_iscsi_send_generic_request(sess->nopout_resp_cmd);
		atomic_set(&sess->nop_resp_pending, 0);
	}
        if (atomic_read(&sess->login_noop_pending)) {
		bnx2i_iscsi_send_generic_request(sess->login_nopout_cmd);
		atomic_set(&sess->login_noop_pending, 0);
	}
	/* flush pending SCSI cmds before transmitting logout request */
        if (atomic_read(&sess->logout_pending) &&
	    list_empty(&sess->pend_cmd_list)) {
		bnx2i_iscsi_send_generic_request(sess->login_nopout_cmd);
		atomic_set(&sess->logout_pending, 0);
	}
	spin_unlock_irqrestore(&sess->lock, flags);
}

static int bnx2i_conn_transmits_pending(struct bnx2i_conn *conn)
{
	struct bnx2i_sess *sess = conn->sess;

	/* If TCP connection is not active or in FFP (connection parameters updated)
	 * then do not transmit anything
	 */
	if (conn->ep && !(conn->ep->state & (EP_STATE_ULP_UPDATE_COMPL |
	    EP_STATE_CONNECT_COMPL)))
		return 0;
		
	if ((sess->recovery_state &&
	    sess->recovery_state != ISCSI_SESS_RECOVERY_COMPLETE) ||
	    test_bit(ADAPTER_STATE_LINK_DOWN, &sess->hba->adapter_state) ||
	    list_empty(&sess->pend_cmd_list))
		return 0;

	return 8;
}

static int bnx2i_process_pend_queue(struct bnx2i_sess *sess)
{
	struct bnx2i_cmd *cmd;
	struct bnx2i_conn *conn;
	struct bnx2i_scsi_task *scsi_task;
	struct list_head *list;
	struct list_head *tmp;
	unsigned long flags;
	int xmits_per_work;
	int cmds_sent = 0;
	int rc = 0;

	xmits_per_work = bnx2i_conn_transmits_pending(sess->lead_conn);
	if (!xmits_per_work)
		return -EAGAIN;

	if (use_poll_timer)
		xmits_per_work = sess->sq_size;	/* flush all commands in pending Q */

	conn = sess->lead_conn;
	spin_lock_irqsave(&sess->lock, flags);
	list_for_each_safe(list, tmp, &sess->pend_cmd_list) {
		/* do not post any SCSI CMDS while TMF is active */
       		if (iscsi_cmd_win_closed(sess)) {
			rc = -EAGAIN;
			break;
		}

		if (conn->ep && ((conn->ep->state == EP_STATE_TCP_FIN_RCVD) ||
    		    (conn->ep->state == EP_STATE_TCP_RST_RCVD))) {
			rc = -EAGAIN;
			break;
		}

		scsi_task = (struct bnx2i_scsi_task *) list;
		cmd = bnx2i_alloc_cmd(sess);
		if (cmd == NULL) {
			rc = -EAGAIN;
			break;
		}

		cmd->scsi_cmd = scsi_task->scsi_cmd;
		sess->pend_cmd_count--;
		list_del_init(&scsi_task->link);
		list_add_tail(&scsi_task->link, &sess->scsi_task_list);

		cmd->conn = sess->lead_conn;
		bnx2i_xmit_work_send_cmd(sess->lead_conn, cmd);
		cmds_sent++;
		if (cmds_sent >= xmits_per_work)
			break;
	}
	spin_unlock_irqrestore(&sess->lock, flags);

	return rc;
}


#ifdef __VMKLNX__
static void bnx2i_conn_main_worker(unsigned long data)
#else
static void
#if defined(INIT_DELAYED_WORK_DEFERRABLE) || defined(INIT_WORK_NAR)
bnx2i_conn_main_worker(struct work_struct *work)
#else
bnx2i_conn_main_worker(void *data)
#endif	/* INIT_DELAYED_WORK_DEFERRABLE && INIT_WORK_NAR */
#endif	/* __VMKLNX__*/
{
	struct bnx2i_sess *sess;
	int cqe_pending;
	int defer_pendq;
#ifndef __VMKLNX__
	struct Scsi_Host *shost;
#if defined(INIT_DELAYED_WORK_DEFERRABLE) || defined(INIT_WORK_NAR)
	struct bnx2i_conn *conn =
		container_of(work, struct bnx2i_conn, conn_worker);
#else
	struct bnx2i_conn *conn = (struct bnx2i_conn *)data;
#endif
#else	/* __VMKLNX__ */
	struct bnx2i_conn *conn = (struct bnx2i_conn *)data;
#endif

	if (!atomic_read(&conn->worker_enabled)) {
		printk("WaTcH: working scheduled while disabled\n");
		return;
	}

	conn->tasklet_entry++;

	sess = conn->sess;


	sess->timestamp = jiffies;	
	conn->tasklet_loop = 0;
	do {

		bnx2i_process_control_pdu(sess);

		defer_pendq = bnx2i_process_pend_queue(sess);

		if (use_poll_timer) {
			if (conn->ep)
				cqe_pending = bnx2i_process_new_cqes(conn, 0,
						conn->ep->qp.cqe_size);
			else
				cqe_pending = 0;
		} else
			cqe_pending = bnx2i_process_new_cqes(conn, 0,
						cmd_cmpl_per_work);


		defer_pendq = bnx2i_process_pend_queue(sess);

		if (time_after(jiffies, sess->timestamp +
			       sess->worker_time_slice)) {
			conn->tasklet_timeslice_exit++;
			break;
		}
	} while (cqe_pending && !defer_pendq);

	
	if (defer_pendq  == -EAGAIN) {
		goto tasklet_exit;
	}

	if (bnx2i_cqe_work_pending(conn) ||
	      !list_empty(&sess->pend_cmd_list)) {
        	if (atomic_read(&conn->worker_enabled)) {
			conn->tasklet_reschedule++;
#ifdef __VMKLNX__
			tasklet_schedule(&conn->conn_tasklet);
#else
			shost = bnx2i_conn_get_shost(conn);
			scsi_queue_work(shost, &conn->conn_worker);
#endif
		}
	}
tasklet_exit:
	bnx2i_arm_cq_event_coalescing(conn->ep, CNIC_ARM_CQE);
}

static void bnx2i_xmit_work_send_cmd(struct bnx2i_conn *conn, struct bnx2i_cmd *cmd)
{
	struct scsi_cmnd *sc = cmd->scsi_cmd;
	struct bnx2i_hba *hba  = conn->ep->hba;
	struct bnx2i_sess *sess  = conn->sess;
	struct iscsi_cmd_request *req = &cmd->req;

	cmd->req.total_data_transfer_length = scsi_bufflen(sc);
	cmd->iscsi_opcode = cmd->req.op_code = ISCSI_OP_SCSI_CMD;
	cmd->req.cmd_sn = sess->cmdsn++;

	bnx2i_iscsi_map_sg_list(hba, cmd);
	bnx2i_cpy_scsi_cdb(sc, cmd);

	req->op_attr = ISCSI_ATTR_SIMPLE;
	if (sc->sc_data_direction == DMA_TO_DEVICE) {
		req->op_attr |= ISCSI_CMD_REQUEST_WRITE;
		req->itt |= (ISCSI_TASK_TYPE_WRITE <<
				 ISCSI_CMD_REQUEST_TYPE_SHIFT);
		bnx2i_setup_write_cmd_bd_info(cmd);
	} else {
		if (scsi_bufflen(sc))
			req->op_attr |= ISCSI_CMD_REQUEST_READ;
		req->itt |= (ISCSI_TASK_TYPE_READ <<
				 ISCSI_CMD_REQUEST_TYPE_SHIFT);
	}
	req->num_bds = cmd->bd_tbl->bd_valid;
	if (!cmd->bd_tbl->bd_valid) {
		req->bd_list_addr_lo =
			(u32) sess->hba->mp_dma_buf.pgtbl_map;
		req->bd_list_addr_hi =
			(u32) ((u64) sess->hba->mp_dma_buf.pgtbl_map >> 32);
		req->num_bds = 1;
	}

	atomic_set(&cmd->cmd_state, ISCSI_CMD_STATE_INITIATED);
	sc->SCp.ptr = (char *) cmd;

	if (req->itt != ITT_INVALID_SIGNATURE) {
		list_add_tail(&cmd->link, &sess->active_cmd_list);
		sess->active_cmd_count++;
		bnx2i_send_iscsi_scsicmd(conn, cmd);
	}
}

/**********************************************************************
 *		open-iscsi interface
 **********************************************************************/

/**
 * bnx2i_alloc_scsi_host_template - 
 *
 * allocates memory for SCSI host template, iSCSI template and registers
 *	this instance of NX2 device with iSCSI transport kernel module.
 */
static struct scsi_host_template *
bnx2i_alloc_scsi_host_template(struct bnx2i_hba *hba, struct cnic_dev *cnic)
{
	void *mem_ptr;
#ifndef __VMKLNX__
	u32 pci_bus_no;
	u32 pci_dev_no;
	u32 pci_func_no;
	u32 extra;
	struct ethtool_drvinfo drv_info;
#endif
	struct scsi_host_template *scsi_template;
	int mem_size;

	mem_size = sizeof(struct scsi_host_template);
	scsi_template = kmalloc(sizeof(struct scsi_host_template), GFP_KERNEL);
	if (!scsi_template) {
		printk(KERN_ALERT "bnx2i: failed to alloc memory for sht\n");
		return NULL;
	}

	mem_ptr = kmalloc(BRCM_ISCSI_XPORT_NAME_SIZE_MAX, GFP_KERNEL);
	if (mem_ptr == NULL) {
		printk(KERN_ALERT "failed to alloc memory for xport name\n");
		goto scsi_name_mem_err;
	}

	memcpy(scsi_template, (const void *) &bnx2i_host_template,
	       sizeof(struct scsi_host_template));
	scsi_template->name = mem_ptr;
	memcpy((void *) scsi_template->name,
	       (const void *) bnx2i_host_template.name,
	       strlen(bnx2i_host_template.name) + 1);

	mem_ptr = kmalloc(BRCM_ISCSI_XPORT_NAME_SIZE_MAX, GFP_KERNEL);
	if (mem_ptr == NULL) {
		printk(KERN_ALERT "failed to alloc proc name mem\n");
		goto scsi_proc_name_mem_err;
	}

	scsi_template->proc_name = mem_ptr;
	/* Can't determine device type, 5706/5708 has 40-bit dma addr limit */
	if (test_bit(BNX2I_NX2_DEV_5706, &hba->cnic_dev_type) ||
	    test_bit(BNX2I_NX2_DEV_5708, &hba->cnic_dev_type))
		scsi_template->dma_boundary = DMA_40BIT_MASK;
	else
		scsi_template->dma_boundary = DMA_64BIT_MASK;

	scsi_template->can_queue = hba->max_sqes;
	scsi_template->cmd_per_lun = scsi_template->can_queue / 2;

	if (cnic && cnic->netdev) {
#ifndef __VMKLNX__
		cnic->netdev->ethtool_ops->get_drvinfo(cnic->netdev,
							    &drv_info);
		sscanf(drv_info.bus_info, "%x:%x:%x.%d", &extra,
		       &pci_bus_no, &pci_dev_no, &pci_func_no);

		sprintf(mem_ptr, "%s-%.2x%.2x%.2x", BRCM_ISCSI_XPORT_NAME_PREFIX,
			 (u8)pci_bus_no, (u8)pci_dev_no, (u8)pci_func_no);
#else
		sprintf(mem_ptr, "%s-%s", BRCM_ISCSI_XPORT_NAME_PREFIX, cnic->netdev->name);
#endif
	}

	return scsi_template;

scsi_proc_name_mem_err:
	kfree(scsi_template->name);
scsi_name_mem_err:
	kfree(scsi_template);
	printk(KERN_ALERT "bnx2i: failed to allocate scsi host template\n");
	return NULL;
}



static void bnx2i_free_scsi_host_template(struct scsi_host_template *scsi_template)
{
	kfree(scsi_template->proc_name);
	kfree(scsi_template->name);
	kfree(scsi_template);
}


/**
 * bnx2i_alloc_iscsi_transport - 
 *
 * allocates memory for SCSI host template, iSCSI template and registers
 *	this instance of NX2 device with iSCSI transport kernel module.
 */
static struct iscsi_transport *
bnx2i_alloc_iscsi_transport(struct bnx2i_hba *hba, struct cnic_dev *cnic, 
			    struct scsi_host_template *scsi_template)
{
	void *mem_ptr;
	struct iscsi_transport *iscsi_transport;
	int mem_size;

	mem_size = sizeof(struct iscsi_transport);
	iscsi_transport = kmalloc(sizeof(struct iscsi_transport), GFP_KERNEL);
	if (!iscsi_transport) {
		printk(KERN_ALERT "mem error for iscsi_transport template\n");
		goto iscsi_xport_err;
	}

	memcpy((void *) iscsi_transport, (const void *) &bnx2i_iscsi_transport,
	       sizeof(struct iscsi_transport));

#ifndef __RHEL54_DUAL_ISCSI_STACK__
	iscsi_transport->host_template = scsi_template;
#endif

	mem_ptr = kmalloc(BRCM_ISCSI_XPORT_NAME_SIZE_MAX, GFP_KERNEL);
	if (mem_ptr == NULL) {
		printk(KERN_ALERT "mem alloc error, iscsi xport name\n");
		goto xport_name_mem_err;
	}

	iscsi_transport->name = mem_ptr;

	memcpy((void *) mem_ptr, (const void *) scsi_template->proc_name,
	       strlen(scsi_template->proc_name) + 1);

#ifdef __VMKLNX__
	if (test_bit(BNX2I_NX2_DEV_57710, &hba->cnic_dev_type))
		iscsi_transport->get_transport_limit    = bnx2i_get_5771x_limit;
	else
		iscsi_transport->get_transport_limit    = bnx2i_get_570x_limit;
#endif
	return iscsi_transport;

xport_name_mem_err:
	kfree(iscsi_transport);
iscsi_xport_err:
	printk(KERN_ALERT "bnx2i : unable to allocate iscsi transport\n");
	return NULL;
}



static void bnx2i_free_iscsi_transport(struct iscsi_transport *iscsi_transport)
{
	kfree(iscsi_transport->name);
	kfree(iscsi_transport);
}


/**
 * bnx2i_register_xport - register a bnx2i device transport name with
 *			the iscsi transport module
 *
 * @hba: 		pointer to adapter instance
 *
 * allocates memory for SCSI host template, iSCSI template and registers
 *	this instance of NX2 device with iSCSI transport kernel module.
 */
int bnx2i_register_xport(struct bnx2i_hba *hba)
{
#ifdef __VMKLNX__
	struct vmk_ScsiAdapter *vmk_adapter;
	struct vmklnx_ScsiAdapter *vmklnx_adapter;

	if (hba->shost_template)
		return -EEXIST;
#endif
	if (!test_bit(CNIC_F_IF_UP, &hba->cnic->flags) ||
	    !hba->cnic->max_iscsi_conn)
		return -EINVAL;

	hba->shost_template = iscsi_register_transport(hba->iscsi_transport);
	if (!hba->shost_template) {
		printk(KERN_ALERT "bnx2i: xport reg failed, hba 0x%p\n", hba);
		goto failed_registration;
	}
	printk(KERN_ALERT "bnx2i: netif=%s, iscsi=%s\n",
		hba->cnic->netdev->name, hba->scsi_template->proc_name);

#ifdef __VMKLNX__
	hba->shost->transportt = hba->shost_template;
	device_initialize(&hba->vm_pcidev);
	if (scsi_add_host(hba->shost, &hba->vm_pcidev))
		goto host_add_err;

	vmklnx_adapter = (struct vmklnx_ScsiAdapter *)hba->shost->adapter;
	vmk_adapter = (struct vmk_ScsiAdapter *)vmklnx_adapter->vmkAdapter;
	vmk_adapter->paeCapable = TRUE;

	iscsi_register_host(hba->shost, hba->iscsi_transport);
#endif

	return 0;

#ifdef __VMKLNX__
host_add_err:
#endif
	iscsi_unregister_transport(hba->iscsi_transport);
failed_registration:
	return -ENOMEM;
}

/**
 * bnx2i_deregister_xport - unregisters bnx2i adapter's iscsi transport name
 *
 * @hba: 		pointer to adapter instance
 * 
 * de-allocates memory for SCSI host template, iSCSI template and de-registers
 *	a NX2 device instance
 */
int bnx2i_deregister_xport(struct bnx2i_hba *hba)
{
	if (hba->shost_template) {
		iscsi_unregister_transport(hba->iscsi_transport);
		hba->shost_template = NULL;
	}
	return 0;
}


int bnx2i_free_iscsi_scsi_template(struct bnx2i_hba *hba)
{
	kfree(hba->scsi_template->proc_name);
	kfree(hba->scsi_template->name);
	hba->scsi_template->name = NULL;

	kfree(hba->scsi_template);
	hba->scsi_template = NULL;

	kfree(hba->iscsi_transport->name);
	hba->iscsi_transport->name = NULL;

	kfree(hba->iscsi_transport);
	hba->iscsi_transport = NULL;

	return 0;
}


/**
 * bnx2i_session_create - create a new iscsi session
 *
 * @it: 		iscsi transport pointer
 * @scsit: 		scsi transport template pointer
 * @cmds_max: 		max commands supported
 * @qdepth: 		scsi queue depth to support
 * @initial_cmdsn: 	initial iscsi CMDSN to be used for this session
 * @host_no: 		pointer to u32 to return host no
 *
 * Creates a new iSCSI session instance on given device.
 */
#if defined(__VMKLNX__) || defined(__RHEL54_DUAL_ISCSI_STACK__)
#define _CREATE_SESS_NEW_	1
#endif

struct iscsi_cls_session *
	bnx2i_session_create(
#ifdef __RHEL54_DUAL_ISCSI_STACK__
			     struct iscsi_endpoint *cls_ep,
#else
			     struct iscsi_transport *it,
			     struct scsi_transport_template *scsit,
#endif
#ifdef _CREATE_SESS_NEW_
			     uint16_t cmds_max, uint16_t qdepth,
#endif
			     uint32_t initial_cmdsn
#ifdef __VMKLNX__
			     , uint32_t target_id, uint32_t channel_id,
#endif
#ifndef __RHEL54_DUAL_ISCSI_STACK__
			     , uint32_t *host_no
#endif
			     )
{
	struct bnx2i_hba *hba;
	struct bnx2i_sess *sess;
	struct Scsi_Host *shost;
	struct iscsi_cls_session *cls_session;
	int ret_code;
#ifdef __RHEL54_DUAL_ISCSI_STACK__
	struct bnx2i_endpoint *ep;
#endif

#ifdef __VMKLNX__
	printk("%s: tgt id %d, ch id %d, cmds_max %d\n",
		__FUNCTION__, target_id, channel_id, cmds_max);
#endif

#ifdef __RHEL54_DUAL_ISCSI_STACK__
	ep = cls_ep->dd_data;
	hba = ep->hba;
#else
	hba = bnx2i_get_hba_from_template(scsit);
#endif
	if (bnx2i_adapter_ready(hba))
		return NULL;

#ifdef __VMKLNX__
	shost = hba->shost;
	if (!shost)
		return NULL;

	cls_session = iscsi_create_session(shost, it, target_id, channel_id);
	if (!cls_session)
		return NULL;

	sess = cls_session->dd_data;
#else
#ifdef __RHEL54_DUAL_ISCSI_STACK__
	shost = iscsi2_host_alloc(hba->scsi_template,
				  hostdata_privsize(sizeof(struct bnx2i_sess)),
				  1);
#else
	shost = scsi_host_alloc(hba->iscsi_transport->host_template,
				hostdata_privsize(sizeof(struct bnx2i_sess)));
#endif
	if (!shost)
		return NULL;

	shost->max_id = 1;
	shost->max_channel = 1;
#ifdef __RHEL54_DUAL_ISCSI_STACK__
	shost->max_lun = 512;
	shost->max_cmd_len = 16;
#else
	shost->max_lun = hba->iscsi_transport->max_lun;
	shost->max_cmd_len = hba->iscsi_transport->max_cmd_len;
#endif
#ifdef _NEW_CREATE_SESSION_
	if (cmds_max)
		shost->can_queue = cmds_max;
	if (qdepth)
		shost->cmd_per_lun = qdepth;
#endif	/* _NEW_CREATE_SESSION_ */

#ifdef __RHEL54_DUAL_ISCSI_STACK__
	shost->transportt = hba->shost_template;
#else
	shost->transportt = scsit;
#endif
	sess = bnx2i_get_sess_from_shost(shost);
	shost->transportt->create_work_queue = 1;

#endif	/* __VMKLNX__ */
#ifndef __RHEL54_DUAL_ISCSI_STACK__
	*host_no = shost->host_no;
#endif

	if (!sess)
		goto sess_resc_fail;

	memset(sess, 0, sizeof(struct bnx2i_sess));
	sess->hba = hba;
#ifdef __VMKLNX__
	sess->cls_sess = cls_session;
#else
	sess->shost = shost;
#endif

	/*
	 * For Open-iSCSI, only normal sessions go through bnx2i.
	 * Discovery session goes through host stack TCP/IP stack.
	 */
	ret_code = bnx2i_iscsi_sess_new(hba, sess);
	if (ret_code) {
		/* failed to allocate memory */
		printk(KERN_ALERT "bnx2i_sess_create: unable to alloc sess\n");
		goto sess_resc_fail;
	}

	/* Update CmdSN related parameters */
	sess->cmdsn = initial_cmdsn;
	sess->exp_cmdsn = initial_cmdsn + 1;
	sess->max_cmdsn = initial_cmdsn + 1;

#ifndef __VMKLNX__
	if (scsi_add_host(shost, NULL))
		goto add_sh_fail;

#ifdef __RHEL54_DUAL_ISCSI_STACK__
	cls_session = iscsi2_session_setup(hba->iscsi_transport, shost,
					   cmds_max, sizeof(struct bnx2i_cmd),
					   initial_cmdsn, 16);
#else
	if (!try_module_get(bnx2i_iscsi_transport.owner))
		goto cls_sess_falied;

	cls_session = iscsi_create_session(shost, it, 0);
#endif
	if (!cls_session)
		goto module_put;

	sess->cls_sess = cls_session;

#ifndef __RHEL54_DUAL_ISCSI_STACK__
	*(unsigned long *)shost->hostdata = (unsigned long)cls_session;
	return hostdata_session(shost->hostdata);
#else
	return cls_session;
#endif	/* __RHEL54_DUAL_ISCSI_STACK__ */
#else	/* __VMKLNX__ */
	sess->cls_sess = cls_session;
	return cls_session;
#endif	/* __VMKLNX__ */

#ifndef __VMKLNX__
module_put:
#ifndef __RHEL54_DUAL_ISCSI_STACK__
	module_put(bnx2i_iscsi_transport.owner);
cls_sess_falied:
#endif
	scsi_remove_host(shost);
add_sh_fail:
	bnx2i_iscsi_sess_release(hba, sess);
#endif
sess_resc_fail:
#ifndef __VMKLNX__
	scsi_host_put(shost);
#endif
	return NULL;
}


#ifdef __VMKLNX__
struct iscsi_cls_session *
bnx2i_session_create_vmp(struct iscsi_transport *it,
			 void *scsi_templ,
#ifdef _CREATE_SESS_NEW_
			 uint16_t cmds_max, uint16_t qdepth,
#endif
			 uint32_t initial_cmdsn,
			 uint32_t target_id, uint32_t channel_id,
			 uint32_t *host_no)
{
	struct scsi_transport_template *scsit = scsi_templ;

	return bnx2i_session_create(it, scsit,
#ifdef _CREATE_SESS_NEW_
				    cmds_max, qdepth,
#endif
				    initial_cmdsn, target_id, channel_id, host_no);
}


struct iscsi_cls_session *
	bnx2i_session_create_vm(struct iscsi_transport *it,
			     struct scsi_transport_template *scsit,
#ifdef _CREATE_SESS_NEW_
			     uint16_t cmds_max, uint16_t qdepth,
#endif
			     uint32_t initial_cmdsn,
			     uint32_t *host_no)
{
	struct bnx2i_hba *hba = bnx2i_get_hba_from_template(scsit);

	if (!hba)
		return NULL;
	return bnx2i_session_create(it, scsit,
#ifdef _CREATE_SESS_NEW_
			     cmds_max, qdepth,
#endif
			     initial_cmdsn, hba->target_id++, hba->channel_id, host_no);
}
#endif


static void bnx2i_release_session_resc(struct iscsi_cls_session *cls_session)
{
#ifdef __VMKLNX__
	struct bnx2i_sess *sess = cls_session->dd_data;
#else
	struct Scsi_Host *shost = iscsi_session_to_shost(cls_session);
	struct bnx2i_sess *sess = bnx2i_get_sess_from_shost(shost);
#ifndef __RHEL54_DUAL_ISCSI_STACK__
	struct module *owner = cls_session->transport->owner;
#endif
#endif

	bnx2i_iscsi_sess_release(sess->hba, sess);

	kfree(sess->target_name);
	sess->target_name = NULL;
#ifdef __VMKLNX__
        iscsi_free_session(cls_session);
	return;
#endif

#ifdef __RHEL54_DUAL_ISCSI_STACK__
	iscsi2_session_teardown(cls_session);
#else
        iscsi_free_session(cls_session);
        module_put(owner);
#endif
	scsi_host_put(shost);
}

/**
 * bnx2i_session_destroy - destroys iscsi session
 *
 * @cls_session: 	pointer to iscsi cls session
 *
 * Destroys previously created iSCSI session instance and releases
 *	all resources held by it
 */

void bnx2i_session_destroy(struct iscsi_cls_session *cls_session)
{
#ifdef __VMKLNX__
	struct bnx2i_sess *sess = cls_session->dd_data;
#else
	struct Scsi_Host *shost = iscsi_session_to_shost(cls_session);
	struct bnx2i_sess *sess = bnx2i_get_sess_from_shost(shost);
#endif

	bnx2i_withdraw_sess_recovery(sess);

#ifndef __RHEL54_DUAL_ISCSI_STACK__
	iscsi_remove_session(cls_session);
#endif
#ifndef __VMKLNX__
	scsi_remove_host(shost);
	bnx2i_release_session_resc(cls_session);
#else
	if (sess->state == BNX2I_SESS_TARGET_DESTROYED)
		bnx2i_release_session_resc(cls_session);
	else
		sess->state = BNX2I_SESS_DESTROYED;
#endif
}

/**
 * bnx2i_sess_recovery_timeo - session recovery timeout handler
 *
 * @cls_session: 	pointer to iscsi cls session
 *
 * session recovery timeout handling routine
 */
void bnx2i_sess_recovery_timeo(struct iscsi_cls_session *cls_session)
{
#ifdef __VMKLNX__
	struct bnx2i_sess *sess = cls_session->dd_data;
#else
	struct Scsi_Host *shost = iscsi_session_to_shost(cls_session);
	struct bnx2i_sess *sess = bnx2i_get_sess_from_shost(shost);
#endif

	printk("%s: sess %p recovery timed out\n", __FUNCTION__, sess);
#ifdef __VMKLNX__
	iscsi_offline_session(sess->cls_sess);
#else
	spin_lock_bh(&sess->lock);
	sess->recovery_state |= ISCSI_SESS_RECOVERY_FAILED;
	spin_unlock_bh(&sess->lock);
	wake_up(&sess->er_wait);
#endif
}


/**
 * bnx2i_conn_create - create iscsi connection instance
 *
 * @cls_session: 	pointer to iscsi cls session
 * @cid: 		iscsi cid as per rfc (not NX2's CID terminology)
 *
 * Creates a new iSCSI connection instance for a given session
 */
struct iscsi_cls_conn *bnx2i_conn_create(struct iscsi_cls_session *cls_session,
					 uint32_t cid)
{
#ifdef __VMKLNX__
	struct bnx2i_sess *sess = cls_session->dd_data;
#else
	struct Scsi_Host *shost = iscsi_session_to_shost(cls_session);
	struct bnx2i_sess *sess = bnx2i_get_sess_from_shost(shost);
#endif
	struct bnx2i_conn *conn;
	struct iscsi_cls_conn *cls_conn;

	cls_conn = iscsi_create_conn(cls_session, cid);
	if (!cls_conn)
		return NULL;

	conn = bnx2i_get_conn_from_cls_conn(cls_conn);
	memset(conn, 0, sizeof(struct bnx2i_conn));
	conn->cls_conn = cls_conn;
	conn->exp_statsn = STATSN_UPDATE_SIGNATURE;
	conn->state = CONN_STATE_IDLE;
	/* Initialize the connection structure */
	if (bnx2i_iscsi_conn_new(sess, conn))
		goto mem_err;

	conn->conn_cid = cid;
	return cls_conn;

mem_err:
	iscsi_destroy_conn(cls_conn);
	return NULL;
}


/**
 * bnx2i_conn_bind - binds iscsi sess, conn and ep objects together
 *
 * @cls_session: 	pointer to iscsi cls session
 * @cls_conn: 		pointer to iscsi cls conn
 * @transport_fd: 	64-bit EP handle
 * @is_leading: 	leading connection on this session?
 *
 * Binds together iSCSI session instance, iSCSI connection instance
 *	and the TCP connection. This routine returns error code if
 *	TCP connection does not belong on the device iSCSI sess/conn
 *	is bound
 */
#ifdef __VMKLNX__
vmk_int32 bnx2i_conn_bind(struct iscsi_cls_session *cls_session,
			  struct iscsi_cls_conn *cls_conn,
			  vmk_uint64 transport_fd, vmk_int32 is_leading)
#else
int bnx2i_conn_bind(struct iscsi_cls_session *cls_session,
		    struct iscsi_cls_conn *cls_conn,
		    uint64_t transport_fd, int is_leading)
#endif
{
#ifdef __VMKLNX__
	struct bnx2i_sess *sess;
	struct Scsi_Host *shost;
	unsigned long flags;
#else
	struct Scsi_Host *shost = iscsi_session_to_shost(cls_session);
	struct bnx2i_sess *sess = bnx2i_get_sess_from_shost(shost);
#endif
	struct bnx2i_conn *tmp;
	struct bnx2i_conn *conn;
	int ret_code;
	struct bnx2i_endpoint *ep;
#ifdef __RHEL54_DUAL_ISCSI_STACK__
        struct iscsi_endpoint *cls_ep;
#endif

#ifdef __VMKLNX__
	sess = cls_session->dd_data;
	shost = bnx2i_sess_get_shost(sess);
#endif
	conn = bnx2i_get_conn_from_cls_conn(cls_conn);

#ifdef __RHEL54_DUAL_ISCSI_STACK__
        cls_ep = iscsi2_lookup_endpoint(transport_fd);
        if (!cls_ep)
                return -EINVAL;

	ep = cls_ep->dd_data;
#else
	ep = (struct bnx2i_endpoint *) (unsigned long) transport_fd;
#endif

	if ((ep->state == EP_STATE_TCP_FIN_RCVD) ||
	    (ep->state == EP_STATE_TCP_RST_RCVD))
		/* Peer disconnect via' FIN or RST */
		return -EINVAL;

	if (ep->hba != sess->hba) {
		/* Error - TCP connection does not belong to this device
		 */
		printk(KERN_ALERT "bnx2i: conn bind, ep=0x%p (%s) does not",
				  ep, ep->hba->netdev->name);
		printk(KERN_ALERT "belong to hba (%s)\n",
				  sess->hba->netdev->name);
		return -EEXIST;
	}

#ifdef __VMKLNX__
	spin_lock_irqsave(ep->hba->shost->host_lock, flags);
#endif
	if (!sess->login_nopout_cmd)
		sess->login_nopout_cmd = bnx2i_alloc_cmd(sess);
	if (!sess->scsi_tmf_cmd)
		sess->scsi_tmf_cmd = bnx2i_alloc_cmd(sess);
	if (!sess->nopout_resp_cmd)
		sess->nopout_resp_cmd = bnx2i_alloc_cmd(sess);
#ifdef __VMKLNX__
	spin_unlock_irqrestore(ep->hba->shost->host_lock, flags);
#endif

	/* adjust dma boundary limit which was set to lower bound of 40-bit
	 * address as required by 5706/5708. 5709/57710 does not have any
	 * address limitation requirements. 'dma_mask' parameter is set
	 * by bnx2 module based on device requirements, we just use whatever
	 * is set.
	 */
	shost->dma_boundary = ep->hba->pcidev->dma_mask;

	/* look-up for existing connection, MC/S is not currently supported */
	spin_lock_bh(&sess->lock);
	tmp = NULL;
	if (!list_empty(&sess->conn_list)) {
		list_for_each_entry(tmp, &sess->conn_list, link) {
			if (tmp == conn)
				break;
		}
	}
	if ((tmp != conn) && (conn->sess == sess)) {
		/* bind iSCSI connection to this session */
		list_add(&conn->link, &sess->conn_list);
		if (is_leading)
			sess->lead_conn = conn;
	}

	if (conn->ep) {
		/* This happens when 'iscsid' is killed and restarted. Daemon
		 * has no clue of tranport handle, but knows active conn/sess
		 * and tried to rebind a new tranport (EP) to already active
		 * iSCSI session/connection
		 */
		spin_unlock_bh(&sess->lock);
#ifdef __RHEL54_DUAL_ISCSI_STACK__
		bnx2i_ep_disconnect(conn->ep->cls_ep);
#else
		bnx2i_ep_disconnect((uint64_t) (unsigned long) conn->ep);
#endif
		spin_lock_bh(&sess->lock);
	}

	conn->ep = ep;
	conn->ep->conn = conn;
	conn->ep->sess = sess;
	conn->state = CONN_STATE_XPORT_READY;
	conn->iscsi_conn_cid = conn->ep->ep_iscsi_cid;
	conn->fw_cid = conn->ep->ep_cid;

	ret_code = bnx2i_bind_conn_to_iscsi_cid(conn, ep->ep_iscsi_cid);
	spin_unlock_bh(&sess->lock);

	/* 5706/5708/5709 FW takes RQ as full when initiated, but for 57710
	 * driver needs to explicitly replenish RQ index during setup.
  	 */
	if (test_bit(BNX2I_NX2_DEV_57710, &ep->hba->cnic_dev_type))
		bnx2i_put_rq_buf(conn, 0);

	atomic_set(&conn->worker_enabled, 1);
	bnx2i_arm_cq_event_coalescing(conn->ep, CNIC_ARM_CQE);
	return ret_code;
}


/**
 * bnx2i_conn_destroy - destroy iscsi connection instance & release resources
 *
 * @cls_conn: 		pointer to iscsi cls conn
 *
 * Destroy an iSCSI connection instance and release memory resources held by
 *	this connection
 */
void bnx2i_conn_destroy(struct iscsi_cls_conn *cls_conn)
{
	struct bnx2i_conn *conn = bnx2i_get_conn_from_cls_conn(cls_conn);
	struct bnx2i_sess *sess = conn->sess;
	struct Scsi_Host *shost;
	shost = bnx2i_conn_get_shost(conn);

	bnx2i_conn_free_login_resources(conn->sess->hba, conn);

#ifdef __VMKLNX__
	tasklet_disable(&conn->conn_tasklet);
#else
	scsi_flush_work(shost);
#endif		/* __VMKLNX__ */
	atomic_set(&conn->worker_enabled, 0);

	spin_lock_bh(&sess->lock);
	list_del_init(&conn->link);
	if (sess->lead_conn == conn)
		sess->lead_conn = NULL;

	if (conn->ep) {
		printk("bnx2i: conn_destroy - conn %p, ep %p\n", conn, conn->ep);
		conn->ep->conn = NULL;
		conn->ep = NULL;
	}
	spin_unlock_bh(&sess->lock);

	kfree(conn->persist_address);
	conn->persist_address = NULL;
	iscsi_destroy_conn(cls_conn);
}


/**
 * bnx2i_conn_set_param - set iscsi connection parameter
 *
 * @cls_conn: 		pointer to iscsi cls conn
 * @param: 		parameter type identifier
 * @buf: 		buffer pointer
 * @buflen: 		buffer length
 *
 * During FFP migration, user daemon will issue this call to
 *	update negotiated iSCSI parameters to driver.
 */
#ifdef __VMKLNX__
vmk_int32 bnx2i_conn_set_param(struct iscsi_cls_conn *cls_conn,
				enum iscsi_param param, vmk_int8 *buf,
				vmk_int32 buflen)
#else
int bnx2i_conn_set_param(struct iscsi_cls_conn *cls_conn,
			 enum iscsi_param param, char *buf, int buflen)
#endif
{
	struct bnx2i_conn *conn = bnx2i_get_conn_from_cls_conn(cls_conn);
	struct bnx2i_sess *sess = conn->sess;
	int ret_val = 0;

	spin_lock_bh(&sess->lock);
	if (conn->state != CONN_STATE_IN_LOGIN) {
		printk(KERN_ERR "bnx2i: can't change param [%d]\n", param);
		spin_unlock_bh(&sess->lock);
		return -1;
	}
	spin_unlock_bh(&sess->lock);
	switch (param) {
	case ISCSI_PARAM_MAX_RECV_DLENGTH:
		sscanf(buf, "%d", &conn->max_data_seg_len_recv);
		break;
	case ISCSI_PARAM_MAX_XMIT_DLENGTH:
		sscanf(buf, "%d", &conn->max_data_seg_len_xmit);
		break;
	case ISCSI_PARAM_HDRDGST_EN:
		sscanf(buf, "%d", &conn->header_digest_en);
		break;
	case ISCSI_PARAM_DATADGST_EN:
		sscanf(buf, "%d", &conn->data_digest_en);
		break;
	case ISCSI_PARAM_INITIAL_R2T_EN:
		if (conn == sess->lead_conn)
			sscanf(buf, "%d", &sess->initial_r2t);
		break;
	case ISCSI_PARAM_MAX_R2T:
		if (conn == sess->lead_conn)
			sscanf(buf, "%d", &sess->max_r2t);
		break;
	case ISCSI_PARAM_IMM_DATA_EN:
		if (conn == sess->lead_conn)
			sscanf(buf, "%d", &sess->imm_data);
		break;
	case ISCSI_PARAM_FIRST_BURST:
		if (conn == sess->lead_conn)
			sscanf(buf, "%d", &sess->first_burst_len);
		break;
	case ISCSI_PARAM_MAX_BURST:
		if (conn == sess->lead_conn)
			sscanf(buf, "%d", &sess->max_burst_len);
		break;
	case ISCSI_PARAM_PDU_INORDER_EN:
		if (conn == sess->lead_conn)
			sscanf(buf, "%d", &sess->pdu_inorder);
		break;
	case ISCSI_PARAM_DATASEQ_INORDER_EN:
		if (conn == sess->lead_conn)
			sscanf(buf, "%d", &sess->dataseq_inorder);
		break;
	case ISCSI_PARAM_ERL:
		if (conn == sess->lead_conn)
			sscanf(buf, "%d", &sess->erl);
		break;
	case ISCSI_PARAM_IFMARKER_EN:
		sscanf(buf, "%d", &conn->ifmarker_enable);
		BUG_ON(conn->ifmarker_enable);
		break;
	case ISCSI_PARAM_OFMARKER_EN:
		sscanf(buf, "%d", &conn->ofmarker_enable);
		BUG_ON(conn->ofmarker_enable);
		break;
	case ISCSI_PARAM_EXP_STATSN:
		sscanf(buf, "%u", &conn->exp_statsn);
		break;
	case ISCSI_PARAM_TARGET_NAME:
		if (sess->target_name)
			break;
		sess->target_name = kstrdup(buf, GFP_KERNEL);
		if (!sess->target_name)
			ret_val = -ENOMEM;
		break;
	case ISCSI_PARAM_TPGT:
		sscanf(buf, "%d", &sess->tgt_prtl_grp);
		break;
	case ISCSI_PARAM_PERSISTENT_PORT:
		sscanf(buf, "%d", &conn->persist_port);
		break;
	case ISCSI_PARAM_PERSISTENT_ADDRESS:
		if (conn->persist_address)
			break;
		conn->persist_address = kstrdup(buf, GFP_KERNEL);
		if (!conn->persist_address)
			ret_val = -ENOMEM;
		break;
#ifdef __VMKLNX__
	case ISCSI_PARAM_ISID:
		snprintf(sess->isid, sizeof(sess->isid), "%s", buf);
		break;
#endif
	default:
		printk(KERN_ALERT "PARAM_UNKNOWN: 0x%x\n", param);
		ret_val = -ENOSYS;
		break;
	}

	return ret_val;
}


/**
 * bnx2i_conn_get_param - return iscsi connection parameter to caller
 *
 * @cls_conn: 		pointer to iscsi cls conn
 * @param: 		parameter type identifier
 * @buf: 		buffer pointer
 *
 * returns iSCSI connection parameters
 */
#ifdef __VMKLNX__
vmk_int32 bnx2i_conn_get_param(struct iscsi_cls_conn *cls_conn,
			 enum iscsi_param param, vmk_int8 *buf)
#else
int bnx2i_conn_get_param(struct iscsi_cls_conn *cls_conn,
			 enum iscsi_param param, char *buf)
#endif
{
	struct bnx2i_conn *conn;
	int len;

	conn = bnx2i_get_conn_from_cls_conn(cls_conn);
	if (!conn)
		return -EINVAL;
#ifndef __VMKLNX__
	if (!conn->ep || (conn->ep->state != EP_STATE_ULP_UPDATE_COMPL))
		return -EINVAL;
#endif

	len = 0;
	switch (param) {
	case ISCSI_PARAM_MAX_RECV_DLENGTH:
		len = sprintf(buf, "%u\n", conn->max_data_seg_len_recv);
		break;
	case ISCSI_PARAM_MAX_XMIT_DLENGTH:
		len = sprintf(buf, "%u\n", conn->max_data_seg_len_xmit);
		break;
	case ISCSI_PARAM_HDRDGST_EN:
		len = sprintf(buf, "%d\n", conn->header_digest_en);
		break;
	case ISCSI_PARAM_DATADGST_EN:
		len = sprintf(buf, "%d\n", conn->data_digest_en);
		break;
	case ISCSI_PARAM_IFMARKER_EN:
		len = sprintf(buf, "%u\n", conn->ifmarker_enable);
		break;
	case ISCSI_PARAM_OFMARKER_EN:
		len = sprintf(buf, "%u\n", conn->ofmarker_enable);
		break;
	case ISCSI_PARAM_EXP_STATSN:
		len = sprintf(buf, "%u\n", conn->exp_statsn);
		break;
	case ISCSI_PARAM_PERSISTENT_PORT:
		len = sprintf(buf, "%d\n", conn->persist_port);
		break;
	case ISCSI_PARAM_PERSISTENT_ADDRESS:
		if (conn->persist_address)
			len = sprintf(buf, "%s\n", conn->persist_address);
		break;
	case ISCSI_PARAM_CONN_PORT:
		if (conn->ep)
			len = sprintf(buf, "%u\n",
				      (uint32_t)(be16_to_cpu((__be32)conn->ep->cm_sk->dst_port)));
		else
			len = sprintf(buf, "0\n");
		break;
	case ISCSI_PARAM_CONN_ADDRESS:
		if (conn->ep)
			len = sprintf(buf, NIPQUAD_FMT "\n",
				      NIPQUAD(conn->ep->cm_sk->dst_ip));
		else
			len = sprintf(buf, "0.0.0.0\n");
		break;
	default:
		printk(KERN_ALERT "get_param: conn 0x%p param %d not found\n",
				  conn, (u32)param);
		len = -ENOSYS;
	}
#ifdef __VMKLNX__
	if (len > 0)
		buf[len - 1] = '\0';
#endif

	return len;
}


/**
 * bnx2i_session_get_param - returns iscsi session parameter
 *
 * @cls_session: 	pointer to iscsi cls session
 * @param: 		parameter type identifier
 * @buf: 		buffer pointer
 *
 * returns iSCSI session parameters
 */
#ifdef __VMKLNX__
vmk_int32 bnx2i_session_get_param(struct iscsi_cls_session *cls_session,
			    enum iscsi_param param, vmk_int8 *buf)
#else
int bnx2i_session_get_param(struct iscsi_cls_session *cls_session,
			    enum iscsi_param param, char *buf)
#endif
{
#ifdef __VMKLNX__
	struct bnx2i_sess *sess = cls_session->dd_data;
#else
	struct Scsi_Host *shost = iscsi_session_to_shost(cls_session);
	struct bnx2i_sess *sess = bnx2i_get_sess_from_shost(shost);
#endif
	int len = 0;

	switch (param) {
	case ISCSI_PARAM_INITIAL_R2T_EN:
		len = sprintf(buf, "%d\n", sess->initial_r2t);
		break;
	case ISCSI_PARAM_MAX_R2T:
		len = sprintf(buf, "%hu\n", sess->max_r2t);
		break;
	case ISCSI_PARAM_IMM_DATA_EN:
		len = sprintf(buf, "%d\n", sess->imm_data);
		break;
	case ISCSI_PARAM_FIRST_BURST:
		len = sprintf(buf, "%u\n", sess->first_burst_len);
		break;
	case ISCSI_PARAM_MAX_BURST:
		len = sprintf(buf, "%u\n", sess->max_burst_len);
		break;
	case ISCSI_PARAM_PDU_INORDER_EN:
		len = sprintf(buf, "%d\n", sess->pdu_inorder);
		break;
	case ISCSI_PARAM_DATASEQ_INORDER_EN:
		len = sprintf(buf, "%d\n", sess->dataseq_inorder);
		break;
	case ISCSI_PARAM_ERL:
		len = sprintf(buf, "%d\n", sess->erl);
		break;
	case ISCSI_PARAM_TARGET_NAME:
		if (sess->target_name)
			len = sprintf(buf, "%s\n", sess->target_name);
		break;
	case ISCSI_PARAM_TPGT:
		len = sprintf(buf, "%d\n", sess->tgt_prtl_grp);
		break;
#ifdef __VMKLNX__
	case ISCSI_PARAM_ISID:
		len = sprintf(buf,"%s\n", sess->isid);
		break;
#endif
	default:
		printk(KERN_ALERT "sess_get_param: sess 0x%p", sess);
		printk(KERN_ALERT  "param (0x%x) not found\n", (u32) param);
		return -ENOSYS;
	}

#ifdef __VMKLNX__
	if (len > 0)
		buf[len - 1] = '\0';
#endif

	return len;
}


/**
 * bnx2i_conn_start - completes iscsi connection migration to FFP
 *
 * @cls_conn: 		pointer to iscsi cls conn
 *
 * last call in FFP migration to handover iscsi conn to the driver
 */
#ifdef __VMKLNX__
vmk_int32 bnx2i_conn_start(struct iscsi_cls_conn *cls_conn)
#else
int bnx2i_conn_start(struct iscsi_cls_conn *cls_conn)
#endif
{
	struct bnx2i_conn *conn = bnx2i_get_conn_from_cls_conn(cls_conn);
	struct bnx2i_sess *sess;

	if (conn->state != CONN_STATE_IN_LOGIN) {
		printk(KERN_ALERT "conn_start: conn 0x%p state 0x%x err!!\n",
				  conn, conn->state);
		return -EINVAL;
	}
	sess = conn->sess;

	if ((sess->imm_data || !sess->initial_r2t) &&
		sess->first_burst_len > sess->max_burst_len) {
		printk(KERN_ALERT "bnx2i: invalid params, FBL > MBL\n");
			return -EINVAL;
	}

	conn->state = CONN_STATE_FFP_STATE;
	if (sess->lead_conn == conn)
		sess->state = BNX2I_SESS_IN_FFP;

	conn->ep->state = EP_STATE_ULP_UPDATE_START;

	if (bnx2i_update_iscsi_conn(conn)) {
		printk(KERN_ERR "bnx2i: unable to send conn update kwqe\n");
		return -ENOSPC;
	}

	conn->ep->ofld_timer.expires = 10*HZ + jiffies;
	conn->ep->ofld_timer.function = bnx2i_ep_ofld_timer;
	conn->ep->ofld_timer.data = (unsigned long) conn->ep;
	add_timer(&conn->ep->ofld_timer);
	/* update iSCSI context for this conn, wait for CNIC to complete */
	wait_event_interruptible(conn->ep->ofld_wait,
				 conn->ep->state != EP_STATE_ULP_UPDATE_START);

	if (signal_pending(current))
		flush_signals(current);
	del_timer_sync(&conn->ep->ofld_timer);

	switch (atomic_read(&conn->stop_state)) {
	case STOP_CONN_RECOVER:
		sess->recovery_state = ISCSI_SESS_RECOVERY_COMPLETE;
		sess->state = BNX2I_SESS_IN_FFP;
		atomic_set(&conn->stop_state, 0);
#ifdef __VMKLNX__
		iscsi_unblock_session(cls_conn->session);
#else
#ifdef __RHEL54_DUAL_ISCSI_STACK__
		iscsi_unblock_session(sess->cls_sess);
#else
		iscsi_unblock_session(session_to_cls(sess));
#endif	/* __RHEL54_DUAL_ISCSI_STACK__ */
#endif	/* __VMKLNX__ */
		wake_up(&sess->er_wait);
		break;
	case STOP_CONN_TERM:
		break;
	default:
		;
	}

	if (use_poll_timer) {
		add_timer(&conn->poll_timer);
		conn->poll_timer_enabled = 1;
	}
#ifdef __RHEL54_DUAL_ISCSI_STACK__
	iscsi2_conn_start(cls_conn);
#endif

	return 0;
}

/* TOOD - debug only */
extern void bnx2i_print_cqe(struct bnx2i_conn *conn);
extern void bnx2i_print_sqe(struct bnx2i_conn *conn);
/* TOOD - debug only */

/**
 * bnx2i_conn_stop - stop any further processing on this connection
 *
 * @cls_conn: 		pointer to iscsi cls conn
 * @flags: 		reason for freezing this connection
 *
 * call to take control of iscsi conn from the driver. Could be called
 *	when login failed, when recovery is to be attempted or during
 *	connection teardown
 */
#ifdef __VMKLNX__
vmk_int32 bnx2i_conn_stop(struct iscsi_cls_conn *cls_conn, vmk_int32 flag)
#else
void bnx2i_conn_stop(struct iscsi_cls_conn *cls_conn, int flag)
#endif
{
	struct bnx2i_conn *conn = bnx2i_get_conn_from_cls_conn(cls_conn);
	struct Scsi_Host *shost = bnx2i_conn_get_shost(conn);
	unsigned long flags;

	atomic_set(&conn->stop_state, flag);
	conn->state = CONN_STATE_XPORT_FREEZE;
#ifdef __VMKLNX__
	iscsi_block_session(cls_conn->session);
#else
// AnIl
	if (conn->sess) {
#ifdef __RHEL54_DUAL_ISCSI_STACK__
		iscsi_block_session(conn->sess->cls_sess);
#else
		iscsi_block_session(session_to_cls(conn->sess));
#endif
	}
#endif

	
#ifndef __VMKLNX__
	atomic_set(&conn->worker_enabled, 0);  
	if (shost)
		scsi_flush_work(shost);
#endif

	switch (flag) {
	case STOP_CONN_RECOVER:
		conn->sess->state = BNX2I_SESS_IN_RECOVERY;
		if (!conn->sess->recovery_state) {	/* nopout timeout */

			spin_lock_irqsave(shost->host_lock, flags);
			conn->sess->recovery_state =
				ISCSI_SESS_RECOVERY_OPEN_ISCSI;
			spin_unlock_irqrestore(shost->host_lock, flags);
		}
		break;
	case STOP_CONN_TERM:
		if (conn->sess && (conn->sess->state & BNX2I_SESS_IN_FFP)) {
			conn->sess->state = BNX2I_SESS_IN_SHUTDOWN;
		}
		break;
	default:
		printk(KERN_ERR "bnx2i: invalid conn stop req %d\n", flag);
	}

	if (use_poll_timer && conn->poll_timer_enabled) {
		del_timer_sync(&conn->poll_timer);
		conn->poll_timer_enabled = 0;
	}

	/* Wait for TMF code to exit before returning to daemon */
	bnx2i_wait_for_tmf_completion(conn->sess);

#ifdef __VMKLNX__
	return 0;
#else
	return;
#endif
}


/**
 * bnx2i_conn_send_pdu - iscsi transport callback entry point to send
 *			iscsi slow path pdus, such as LOGIN/LOGOUT/NOPOUT, etc
 *
 * @hba: 		pointer to adapter instance
 *
 * sends iSCSI PDUs prepared by user daemon, only login, logout, nop-out pdu
 *	will flow this path.
 */
#ifdef __VMKLNX__
vmk_int32 bnx2i_conn_send_pdu(struct iscsi_cls_conn *cls_conn,
			struct iscsi_hdr *hdr, vmk_int8 *data,
			vmk_uint32 data_size)
#else
int bnx2i_conn_send_pdu(struct iscsi_cls_conn *cls_conn,
			struct iscsi_hdr *hdr, char *data,
			uint32_t data_size)
#endif
{
	struct bnx2i_conn *conn;
	struct bnx2i_cmd *cmnd;
	uint32_t payload_size;
	int count;
#ifndef __VMKLNX__
	struct Scsi_Host *shost;
#endif

	if (!cls_conn) {
		printk(KERN_ALERT "bnx2i_conn_send_pdu: NULL conn ptr. \n");
		return -EIO;
	}
	conn = bnx2i_get_conn_from_cls_conn(cls_conn);
	if (!conn->gen_pdu.req_buf) {
		printk(KERN_ALERT "send_pdu: login buf not allocated\n");
		/* ERR - buffer not allocated, should not happen */
		goto error;
	}

	if (conn->state != CONN_STATE_XPORT_READY &&
	    conn->state != CONN_STATE_IN_LOGIN && 
	    (hdr->opcode & ISCSI_OPCODE_MASK) == ISCSI_OP_LOGIN) {
		/* login pdu request is valid in transport ready state */
		printk(KERN_ALERT "send_pdu: %d != XPORT_READY\n",
				  conn->state);
		goto error;
	}

	if (conn->sess->login_nopout_cmd) {
		cmnd = conn->sess->login_nopout_cmd;
	} else 		/* should not happen ever... */
		goto error;

		memset(conn->gen_pdu.req_buf, 0, ISCSI_CONN_LOGIN_BUF_SIZE);
		conn->gen_pdu.req_buf_size = data_size;

		cmnd->conn = conn;
		cmnd->scsi_cmd = NULL;

		switch (hdr->opcode & ISCSI_OPCODE_MASK) {
		case ISCSI_OP_LOGIN:
			/* Login request, copy hdr & data to buffer in conn struct */
			memcpy(&conn->gen_pdu.pdu_hdr, (const void *) hdr,
				sizeof(struct iscsi_hdr));
			if (conn->state == CONN_STATE_XPORT_READY)
				conn->state = CONN_STATE_IN_LOGIN;
			payload_size = (hdr->dlength[0] << 16) | (hdr->dlength[1] << 8) |
					hdr->dlength[2];

			if (data_size) {
				memcpy(conn->gen_pdu.login_req.mem, (const void *)data,	
				       data_size);
				conn->gen_pdu.req_wr_ptr =
					conn->gen_pdu.req_buf + payload_size;
			}
			cmnd->iscsi_opcode = hdr->opcode;
			smp_mb();
			atomic_set(&conn->sess->login_noop_pending, 1);
			break;
		case ISCSI_OP_LOGOUT:
			/* Logout request, copy header only */
			memcpy(&conn->gen_pdu.pdu_hdr, (const void *) hdr,
				sizeof(struct iscsi_hdr));
			conn->gen_pdu.req_wr_ptr = conn->gen_pdu.req_buf;
			conn->state = CONN_STATE_IN_LOGOUT;
			conn->sess->state = BNX2I_SESS_IN_LOGOUT;
			if (atomic_read(&conn->sess->tmf_active))
				bnx2i_wait_for_tmf_completion(conn->sess);

			/* Wait for any outstanding iscsi nopout to complete */
			count = 10;
			while (count-- && cmnd->iscsi_opcode)
				msleep(100);
			if (cmnd->iscsi_opcode)
				goto error;

			cmnd->iscsi_opcode = hdr->opcode;
			smp_mb();
			atomic_set(&conn->sess->logout_pending, 1);
			break;
		case ISCSI_OP_NOOP_OUT:
			conn->sess->last_nooput_requested = jiffies;
			conn->sess->noopout_requested_count++;
			/* connection is being logged out, do not allow NOOP */
			if (conn->state == CONN_STATE_IN_LOGOUT)
				goto error;

			/* unsolicited iSCSI NOOP copy hdr into conn struct */
			memcpy(&conn->gen_pdu.nopout_hdr, (const void *) hdr,
				sizeof(struct iscsi_hdr));
			cmnd->iscsi_opcode = hdr->opcode;
			cmnd->ttt = ISCSI_RESERVED_TAG;
			smp_mb();
			atomic_set(&conn->sess->login_noop_pending, 1);
			break;
		default:
			;
		}

	if (atomic_read(&conn->worker_enabled)) {
#ifdef __VMKLNX__
		tasklet_schedule(&conn->conn_tasklet);
#else
		shost = bnx2i_conn_get_shost(conn);
		scsi_queue_work(shost, &conn->conn_worker);
#endif
	}
	return 0;
error:
	return -EIO;
}


/**
 * bnx2i_conn_get_stats - returns iSCSI stats
 *
 * @cls_conn: 		pointer to iscsi cls conn
 * @stats: 		pointer to iscsi statistic struct
 */
void bnx2i_conn_get_stats(struct iscsi_cls_conn *cls_conn,
			  struct iscsi_stats *stats)
{
	struct bnx2i_conn *conn = bnx2i_get_conn_from_cls_conn(cls_conn);

	stats->txdata_octets = conn->total_data_octets_sent;
	stats->rxdata_octets = conn->total_data_octets_rcvd;

	stats->noptx_pdus = conn->num_nopin_pdus;
	stats->scsicmd_pdus = conn->num_scsi_cmd_pdus;
	stats->tmfcmd_pdus = conn->num_tmf_req_pdus;
	stats->login_pdus = conn->num_login_req_pdus;
	stats->text_pdus = 0;
	stats->dataout_pdus = conn->num_dataout_pdus;
	stats->logout_pdus = conn->num_logout_req_pdus;
	stats->snack_pdus = 0;

	stats->noprx_pdus = conn->num_nopout_pdus;
	stats->scsirsp_pdus = conn->num_scsi_resp_pdus;
	stats->tmfrsp_pdus = conn->num_tmf_resp_pdus;
	stats->textrsp_pdus = 0;
	stats->datain_pdus = conn->num_datain_pdus;
	stats->logoutrsp_pdus = conn->num_logout_resp_pdus;
	stats->r2t_pdus = conn->num_r2t_pdus;
	stats->async_pdus = conn->num_async_pdus;
	stats->rjt_pdus = conn->num_reject_pdus;

	stats->digest_err = 0;
	stats->timeout_err = 0;
	stats->custom_length = 0;
}

#ifdef __VMKLNX__
vmk_int32 bnx2i_get_570x_limit(enum iscsi_param param,
			       TransportParamLimit *limit, vmk_int32 maxListLen)
{
	limit->param = param;
	switch(param) {
	case  ISCSI_PARAM_MAX_SESSIONS:
		limit->type = TRANPORT_LIMIT_TYPE_LIST;
		limit->hasPreferred = VMK_TRUE;
		limit->preferred = 64;
		limit->limit.list.count = 1;
		limit->limit.list.value[0] = 64;
		break;
	default:
		limit->type = TRANPORT_LIMIT_TYPE_UNSUPPORTED;
		break;
	}
	return 0;
}

vmk_int32 bnx2i_get_5771x_limit(enum iscsi_param param,
			        TransportParamLimit *limit,
			        vmk_int32 maxListLen)
{
	limit->param = param;
	switch(param) {
	case  ISCSI_PARAM_MAX_SESSIONS:
		limit->type = TRANPORT_LIMIT_TYPE_LIST;
		limit->hasPreferred = VMK_TRUE;
		limit->preferred = 64;
		limit->limit.list.count = 1;
		limit->limit.list.value[0] = 128;
		break;
	default:
		limit->type = TRANPORT_LIMIT_TYPE_UNSUPPORTED;
		break;
	}
	return 0;
}
#endif



/**
 * bnx2i_check_nx2_dev_busy - this routine unregister devices if
 *			there are no active conns
 */
void bnx2i_check_nx2_dev_busy(void)
{
	bnx2i_unreg_dev_all();
}


/**
 * bnx2i_check_route - checks if target IP route belongs to one of
 *			NX2 devices
 *
 * @dst_addr: 		target IP address
 *
 * check if route resolves to BNX2 device
 */
#ifdef __VMKLNX__
static struct bnx2i_hba *bnx2i_check_route(struct sockaddr *dst_addr,
					vmk_IscsiNetHandle iscsiNetHandle)
#else
static struct bnx2i_hba *bnx2i_check_route(struct sockaddr *dst_addr)
#endif
{
	struct sockaddr_in *desti = (struct sockaddr_in *) dst_addr;
	struct bnx2i_hba *hba;
	struct cnic_dev *cnic = NULL;

	bnx2i_reg_dev_all();

	hba = get_adapter_list_head();
	if (hba && hba->cnic)
#ifdef __VMKLNX__
		cnic = hba->cnic->cm_select_dev(iscsiNetHandle, desti, CNIC_ULP_ISCSI);
#else
		cnic = hba->cnic->cm_select_dev(desti, CNIC_ULP_ISCSI);
#endif

	if (!cnic) {
		printk(KERN_ALERT "bnx2i: check route, can't connect using cnic\n");
		goto no_nx2_route;
	}
	hba = bnx2i_find_hba_for_cnic(cnic);
	if (!hba) {
		goto no_nx2_route;
	}

	if (bnx2i_adapter_ready(hba)) {
		printk(KERN_ALERT "bnx2i: check route, hba not found\n");
		goto no_nx2_route;
	}
	if (hba->netdev->mtu > hba->mtu_supported) {
		printk(KERN_ALERT "bnx2i: %s network i/f mtu is set to %d\n",
				  hba->netdev->name, hba->netdev->mtu);
		printk(KERN_ALERT "bnx2i: iSCSI HBA can support mtu of %d\n",
				  hba->mtu_supported);
		goto no_nx2_route;
	}
	return hba;
no_nx2_route:
	return NULL;
}


/**
 * bnx2i_tear_down_conn - tear down iscsi/tcp connection and free resources
 *
 * @hba: 		pointer to adapter instance
 * @ep: 		endpoint (transport indentifier) structure
 *
 * destroys cm_sock structure and on chip iscsi context
 */
static int bnx2i_tear_down_conn(struct bnx2i_hba *hba,
				 struct bnx2i_endpoint *ep)
{
	if (test_bit(BNX2I_CNIC_REGISTERED, &hba->reg_with_cnic))
		hba->cnic->cm_destroy(ep->cm_sk);

	if (test_bit(ADAPTER_STATE_GOING_DOWN, &ep->hba->adapter_state))
		ep->state = EP_STATE_DISCONN_COMPL;

	if (test_bit(BNX2I_NX2_DEV_57710, &hba->cnic_dev_type) &&
	    ep->state == EP_STATE_DISCONN_TIMEDOUT) {
		printk(KERN_ALERT "bnx2i - WaTcH - please submit GRC Dump,"
				  " NW/PCIe trace, driver msgs to developers"
				  " for analysis\n");
		return 1;
	}

	ep->state = EP_STATE_CLEANUP_START;
	init_timer(&ep->ofld_timer);
	ep->ofld_timer.expires = hba->conn_ctx_destroy_tmo + jiffies;
	ep->ofld_timer.function = bnx2i_ep_ofld_timer;
	ep->ofld_timer.data = (unsigned long) ep;
	add_timer(&ep->ofld_timer);

	bnx2i_ep_destroy_list_add(hba, ep);

	/* destroy iSCSI context, wait for it to complete */
	bnx2i_send_conn_destroy(hba, ep);
	wait_event_interruptible(ep->ofld_wait,
				 (ep->state != EP_STATE_CLEANUP_START));

	if (signal_pending(current))
		flush_signals(current);
	del_timer_sync(&ep->ofld_timer);
	bnx2i_ep_destroy_list_del(hba, ep);

	if (ep->state != EP_STATE_CLEANUP_CMPL)
		/* should never happen */
		printk(KERN_ALERT "bnx2i - WaTcH: conn destroy failed\n");
	return 0;
}


/**
 * bnx2i_ep_connect - establish TCP connection to target portal
 *
 * @dst_addr: 		target IP address
 * @non_blocking: 	blocking or non-blocking call
 * @ep_handle: 		placeholder to return new created  endpoint handle
 *
 * this routine initiates the TCP/IP connection by invoking Option-2 i/f
 *	with l5_core and the CNIC. This is a multi-step process of resolving
 *	route to target, create a iscsi connection context, handshaking with
 *	CNIC module to create/initialize the socket struct and finally
 *	sending down option-2 request to complete TCP 3-way handshake
 */
#ifdef __VMKLNX__
vmk_int32 bnx2i_ep_connect(struct sockaddr *dst_addr, vmk_int32 non_blocking,
		     vmk_uint64 *ep_handle, vmk_IscsiNetHandle iscsiNetHandle)
#else
#ifdef __RHEL54_DUAL_ISCSI_STACK__
struct iscsi_endpoint *bnx2i_ep_connect(struct Scsi_Host *shost,
					struct sockaddr *dst_addr,
					int non_blocking)
#else
static int bnx2i_ep_connect(struct sockaddr *dst_addr, int non_blocking,
			    uint64_t *ep_handle)
#endif	/* __RHEL54_DUAL_ISCSI_STACK__ */
#endif	/* __VMKLNX__ */
{
	u32 iscsi_cid = BNX2I_CID_RESERVED;
	struct sockaddr_in *desti;
	struct sockaddr_in6 *desti6;
#ifdef __RHEL54_DUAL_ISCSI_STACK__
	struct iscsi_endpoint *cls_ep;
#endif
	struct bnx2i_endpoint *endpoint = NULL;
	struct bnx2i_hba *hba;
	struct cnic_dev *cnic;
	struct cnic_sockaddr saddr;
	int rc = 0;

	/* check if the given destination can be reached through NX2 device */
#ifdef __VMKLNX__
	hba = bnx2i_check_route(dst_addr, iscsiNetHandle);
#else
	hba = bnx2i_check_route(dst_addr);
#endif
	if (!hba) {
		rc = -ENOMEM;
		goto check_busy;
	}

	cnic = hba->cnic;
#ifdef __RHEL54_DUAL_ISCSI_STACK__
	cls_ep = bnx2i_alloc_ep(hba);
	if (cls_ep)
		endpoint = cls_ep->dd_data;
#else
	endpoint = bnx2i_alloc_ep(hba);
#endif
	if (!endpoint) {
#ifndef __RHEL54_DUAL_ISCSI_STACK__
		*ep_handle = (uint64_t) 0;
#endif
		rc = -ENOMEM;
		goto check_busy;
	}

	mutex_lock(&hba->net_dev_lock);

	if (bnx2i_adapter_ready(hba)) {
		rc = -EPERM;
		goto net_if_down;
	}

	endpoint->state = EP_STATE_IDLE;
	endpoint->teardown_mode = BNX2I_ABORTIVE_SHUTDOWN;
	endpoint->ep_iscsi_cid = (u16)ISCSI_RESERVED_TAG;
	iscsi_cid = bnx2i_alloc_iscsi_cid(hba);
	if (iscsi_cid == ISCSI_RESERVED_TAG) {
		printk(KERN_ALERT "alloc_ep: unable to allocate iscsi cid\n");
		rc = -ENOMEM;
		goto iscsi_cid_err;
	}
	endpoint->hba_age = hba->age;

	rc = bnx2i_alloc_qp_resc(hba, endpoint);
	if (rc != 0) {
		printk(KERN_ALERT "bnx2i: ep_conn, alloc QP resc error\n");
		rc = -ENOMEM;
		goto qp_resc_err;
	}

	endpoint->ep_iscsi_cid = iscsi_cid & 0xFFFF;
	endpoint->state = EP_STATE_OFLD_START;
	bnx2i_ep_ofld_list_add(hba, endpoint);

	init_timer(&endpoint->ofld_timer);
	endpoint->ofld_timer.expires = 2 * HZ + jiffies;
	endpoint->ofld_timer.function = bnx2i_ep_ofld_timer;
	endpoint->ofld_timer.data = (unsigned long) endpoint;
	add_timer(&endpoint->ofld_timer);

	if (bnx2i_send_conn_ofld_req(hba, endpoint)) {
		printk(KERN_ERR "bnx2i: unable to send conn offld kwqe\n");
		rc = -ENOSPC;
		goto conn_failed;
	}

	/* Wait for CNIC hardware to setup conn context and return 'cid' */
	wait_event_interruptible(endpoint->ofld_wait,
				 endpoint->state != EP_STATE_OFLD_START);

	if (signal_pending(current))
		flush_signals(current);
	del_timer_sync(&endpoint->ofld_timer);
	bnx2i_ep_ofld_list_del(hba, endpoint);
	
	if (endpoint->state != EP_STATE_OFLD_COMPL) {
		rc = -ENOSPC;
		goto conn_failed;
	}

	if (!test_bit(BNX2I_CNIC_REGISTERED, &hba->reg_with_cnic)) {
		rc = -EINVAL;
		goto conn_failed;
	} else
		rc = cnic->cm_create(cnic, CNIC_ULP_ISCSI, endpoint->ep_cid,
				     iscsi_cid, &endpoint->cm_sk, endpoint);
	if (rc) {
		rc = -EINVAL;
		goto conn_failed;
	}

	endpoint->cm_sk->rcv_buf = tcp_buf_size * 1024;
	endpoint->cm_sk->snd_buf = tcp_buf_size * 1024;
	if (!en_tcp_dack)
		endpoint->cm_sk->tcp_flags |= SK_TCP_NO_DELAY_ACK;
	if (time_stamps)
		endpoint->cm_sk->tcp_flags |= SK_TCP_TIMESTAMP;

	memset(&saddr, 0, sizeof(saddr));

	if (dst_addr->sa_family == AF_INET) {
		desti = (struct sockaddr_in *) dst_addr;
		saddr.remote.v4 = *desti;
		saddr.local.v4.sin_port = htons(endpoint->tcp_port);
		saddr.local.v4.sin_family = desti->sin_family;
	} else if (dst_addr->sa_family == AF_INET6) {
		desti6 = (struct sockaddr_in6 *) dst_addr;
		saddr.remote.v6 = *desti6;
		saddr.local.v6.sin6_port = htons(endpoint->tcp_port);
		saddr.local.v6.sin6_family = desti6->sin6_family;
	}

	endpoint->timestamp = jiffies;
	endpoint->state = EP_STATE_CONNECT_START;
	if (!test_bit(BNX2I_CNIC_REGISTERED, &hba->reg_with_cnic)) {
		rc = -EINVAL;
		goto conn_failed;
	} else
		rc = cnic->cm_connect(endpoint->cm_sk, &saddr);

	if (rc)
		goto release_ep;

	rc = bnx2i_map_ep_dbell_regs(endpoint);
	if (rc)
		goto release_ep;

#ifndef __RHEL54_DUAL_ISCSI_STACK__
	*ep_handle = (uint64_t) (unsigned long) endpoint;
#endif
	mutex_unlock(&hba->net_dev_lock);

	/*
	 * unregister idle devices, without this user can't uninstall
	 * unused bnx2/bnx2x driver because registration will increment
	 * the usage count
	 */
	bnx2i_check_nx2_dev_busy();

#ifdef __RHEL54_DUAL_ISCSI_STACK__
	return cls_ep;
#else
	return 0;
#endif

release_ep:
	bnx2i_tear_down_conn(hba, endpoint);
conn_failed:
net_if_down:
iscsi_cid_err:
	bnx2i_free_qp_resc(hba, endpoint);
qp_resc_err:
#ifdef __RHEL54_DUAL_ISCSI_STACK__
	bnx2i_free_ep(cls_ep);
#else
	bnx2i_free_ep(endpoint);
#endif
	mutex_unlock(&hba->net_dev_lock);
check_busy:
#ifndef __RHEL54_DUAL_ISCSI_STACK__
	*ep_handle = (uint64_t) 0;
#endif
	bnx2i_check_nx2_dev_busy();
#ifdef __RHEL54_DUAL_ISCSI_STACK__
	return ERR_PTR(rc);
#else
	return rc;
#endif
}


/**
 * bnx2i_ep_poll - polls for TCP connection establishement
 *
 * @ep_handle: 		TCP connection (endpoint) handle
 * @timeout_ms: 	timeout value in milli secs
 *
 * polls for TCP connect request to complete
 */
#ifdef __VMKLNX__
vmk_int32 bnx2i_ep_poll(vmk_uint64 ep_handle, vmk_int32 timeout_ms)
#else
#ifdef __RHEL54_DUAL_ISCSI_STACK__
static int bnx2i_ep_poll(struct iscsi_endpoint *cls_ep, int timeout_ms)
#else
static int bnx2i_ep_poll(uint64_t ep_handle, int timeout_ms)
#endif	/* __RHEL54_DUAL_ISCSI_STACK__ */
#endif	/* __VMKLNX__ */
{
	struct bnx2i_endpoint *ep;
	int rc = 0;

#ifdef __RHEL54_DUAL_ISCSI_STACK__
	ep = cls_ep->dd_data;
#else
	if (ep_handle == -1)
		return -EINVAL;
	ep = (struct bnx2i_endpoint *) (unsigned long) ep_handle;
#endif

	if (!ep)
		return -EINVAL;

	if ((ep->state == EP_STATE_IDLE) ||
	    (ep->state == EP_STATE_CONNECT_FAILED) ||
	    (ep->state == EP_STATE_OFLD_FAILED))
		return -1;

	if (ep->state == EP_STATE_CONNECT_COMPL)
		return 1;

	rc = wait_event_interruptible_timeout(ep->ofld_wait,
					      ((ep->state ==
					        EP_STATE_OFLD_FAILED) ||
					       (ep->state ==
					         EP_STATE_CONNECT_FAILED) ||
					       (ep->state ==
					        EP_STATE_CONNECT_COMPL)),
					       msecs_to_jiffies(timeout_ms));
	if (ep->state == EP_STATE_OFLD_FAILED)
		rc = -1;

	if (rc > 0)
		return 1;
	else if (!rc)
		return 0;	/* timeout */
	else
		return rc;
}

/**
 * bnx2i_ep_tcp_conn_active - check EP state transition to check
 *		if underlying TCP connection is active
 *
 * @ep: 		endpoint pointer
 *
 */
static int bnx2i_ep_tcp_conn_active(struct bnx2i_endpoint *ep)
{
	int ret;

	switch (ep->state) {
	case EP_STATE_CLEANUP_FAILED:
	case EP_STATE_OFLD_FAILED:
	case EP_STATE_DISCONN_TIMEDOUT:
		ret = 0;
		break;
	case EP_STATE_CONNECT_COMPL:
	case EP_STATE_ULP_UPDATE_START:
	case EP_STATE_ULP_UPDATE_COMPL:
	case EP_STATE_TCP_FIN_RCVD:
	case EP_STATE_ULP_UPDATE_FAILED:
	case EP_STATE_CONNECT_FAILED:
		/* cnic need to upload PG for 570x chipsets and there is
		 * an understanding it is safe to call cm_abort() even if
		 * cm_connect() failed for all chip types
		 */
		ret = 1;
		break;
	case EP_STATE_TCP_RST_RCVD:
	case EP_STATE_CONNECT_START:
		/* bnx2i will not know whether PG needs to be uploaded or not.
		 * bnx2i will call cm_abort() and let cnic decide the clean-up
		 * action that needs to be taken
		 */
		if (test_bit(BNX2I_NX2_DEV_57710, &ep->hba->cnic_dev_type))
			ret = 0;
		else
			ret = 1;
		break;
	default:
		ret = 0;
	}

	return ret;
}

/**
 * bnx2i_ep_disconnect - executes TCP connection teardown process
 *
 * @ep_handle: 		TCP connection (endpoint) handle
 *
 * executes  TCP connection teardown process
 */
#ifdef __VMKLNX__
void bnx2i_ep_disconnect(vmk_int64 ep_handle)
#else
#ifdef __RHEL54_DUAL_ISCSI_STACK__
void bnx2i_ep_disconnect(struct iscsi_endpoint *cls_ep)
#else
void bnx2i_ep_disconnect(uint64_t ep_handle)
#endif
#endif
{
	struct bnx2i_endpoint *ep;
	struct cnic_dev *cnic;
	struct bnx2i_hba *hba;
	struct bnx2i_sess *sess;

#ifdef __RHEL54_DUAL_ISCSI_STACK__
	ep = cls_ep->dd_data;
#else
	if (ep_handle == -1)
		return;
	ep = (struct bnx2i_endpoint *) (unsigned long) ep_handle;
#endif
	if (!ep)
		return;

        while ((ep->state == EP_STATE_CONNECT_START) &&
		!time_after(jiffies, ep->timestamp + (12 * HZ)))
                msleep(250);

#ifdef __VMKLNX__
	/** This could be a bug, we always disable here, but we enable in BIND
	 *  so we should ONLY ever disable if the ep was assigned a conn ( AKA BIND was run )
	 *  Another case is that conn_destroy got called, which sets the ep->conn to NULL 
	 *  which is ok since destroy stops the tasklet
	 */
	if (ep->conn) {
		atomic_set(&ep->conn->worker_enabled, 0);
		tasklet_kill(&ep->conn->conn_tasklet);
	}
#else
	/* During MPIO testing in RHEL5.4, open-iscsi daemon sometimes
	 * does not issue conn_stop() before tearing down 'ep'. So in
	 * that case driver needs to flush scsi workqueue
	 */
	if (ep->conn) {
		struct bnx2i_conn *conn = ep->conn;
		struct Scsi_Host *shost = bnx2i_conn_get_shost(conn);

		if (atomic_read(&conn->worker_enabled)) {
			atomic_set(&conn->worker_enabled, 0);  
			scsi_flush_work(shost);
		}
	}
#endif

	hba = ep->hba;
	if (ep->state == EP_STATE_IDLE)
		goto return_ep;
	cnic = hba->cnic;

	printk("%s: disconnecting ep %p, cid %d, hba %p\n", __FUNCTION__, ep, ep->ep_iscsi_cid, hba);

	mutex_lock(&hba->net_dev_lock);
	if (!test_bit(ADAPTER_STATE_UP, &hba->adapter_state))
		goto free_resc;
	if (ep->hba_age != hba->age)
		goto dev_reset;

	if (!bnx2i_ep_tcp_conn_active(ep))
		goto destory_conn;

	ep->state = EP_STATE_DISCONN_START;

	init_timer(&ep->ofld_timer);
	ep->ofld_timer.expires = hba->conn_teardown_tmo + jiffies;
	ep->ofld_timer.function = bnx2i_ep_ofld_timer;
	ep->ofld_timer.data = (unsigned long) ep;
	add_timer(&ep->ofld_timer);

	if (test_bit(BNX2I_CNIC_REGISTERED, &hba->reg_with_cnic)) {
		if (ep->teardown_mode == BNX2I_GRACEFUL_SHUTDOWN)
			cnic->cm_close(ep->cm_sk);
		else
			cnic->cm_abort(ep->cm_sk);
	} else
		goto free_resc;

	/* wait for option-2 conn teardown */
	wait_event_interruptible(ep->ofld_wait,
				 ep->state != EP_STATE_DISCONN_START);

	if (signal_pending(current))
		flush_signals(current);
	del_timer_sync(&ep->ofld_timer);

destory_conn:
	if (bnx2i_tear_down_conn(hba, ep)) {
		mutex_unlock(&hba->net_dev_lock);
		return;
	}

dev_reset:
free_resc:
	/* in case of 3-way handshake failure, there won't be any binding
	 * between EP and SESS
	 */
	if (ep->sess) {
		int cmds_a = 0, cmds_p = 0;
		cmds_p = bnx2i_flush_pend_queue(ep->sess, NULL, DID_RESET);
		cmds_a = bnx2i_flush_cmd_queue(ep->sess, NULL, DID_RESET, 0);
		//printk(KERN_ALERT "%s: CMDS FLUSHED, pend=%d, active=%d\n", __FUNCTION__, cmds_p, cmds_a);
	}

	mutex_unlock(&hba->net_dev_lock);
	bnx2i_free_qp_resc(hba, ep);
return_ep:
	/* check if session recovery in progress */
	sess = ep->sess;

#ifdef __RHEL54_DUAL_ISCSI_STACK__
	bnx2i_free_ep(cls_ep);
#else
	bnx2i_free_ep(ep);
#endif
	if (sess) {
		sess->state = BNX2I_SESS_INITIAL;
		wake_up(&sess->er_wait);
	}
	wake_up_interruptible(&hba->eh_wait);

	if (!hba->ofld_conns_active)
		bnx2i_check_nx2_dev_busy();

	return;
}


int bnx2i_check_ioctl_signature(struct bnx2i_ioctl_header *ioc_hdr)
{
	if (strcmp(ioc_hdr->signature, BNX2I_MGMT_SIGNATURE))
		return -EPERM;
	return 0;
}

static int bnx2i_tcp_port_count_ioctl(struct file *file, unsigned long arg)
{
	struct bnx2i_get_port_count __user *user_ioc =
		(struct bnx2i_get_port_count __user *)arg;
	struct bnx2i_get_port_count ioc_req;
	int error = 0;
	unsigned int count = 0;

	if (copy_from_user(&ioc_req, user_ioc, sizeof(ioc_req))) {
		error = -EFAULT;
		goto out;
	}

	error = bnx2i_check_ioctl_signature(&ioc_req.hdr);
	if (error)
		goto out;

	if (bnx2i_tcp_port_tbl.num_free_ports < 10 &&
	    bnx2i_tcp_port_tbl.num_required) {
		if (bnx2i_tcp_port_tbl.num_required < 32)
			count = bnx2i_tcp_port_tbl.num_required;
		else
			count = 32;
	}

	ioc_req.port_count = count;

	if (copy_to_user(&user_ioc->port_count, &ioc_req.port_count,
			 sizeof(ioc_req.port_count))) {
		error = -EFAULT;
		goto out;
	}

out:
	return error;
}


static int bnx2i_tcp_port_ioctl(struct file *file, unsigned long arg)
{
	struct bnx2i_set_port_num __user *user_ioc =
		(struct bnx2i_set_port_num __user *)arg;
	struct bnx2i_set_port_num ioc_req;
	struct bnx2i_set_port_num *ioc_req_mp = NULL;
	int ioc_msg_size = sizeof(ioc_req);
	int error;
	int i;

	if (copy_from_user(&ioc_req, user_ioc, ioc_msg_size)) {
		error = -EFAULT;
		goto out;
	}

	error = bnx2i_check_ioctl_signature(&ioc_req.hdr);
	if (error)
		goto out;

	if (ioc_req.num_ports > 1) {
		ioc_msg_size += (ioc_req.num_ports - 1) *
				sizeof(ioc_req.tcp_port[0]);

		ioc_req_mp = kmalloc(ioc_msg_size, GFP_KERNEL);
		if (!ioc_req_mp)
			goto out;

		if (copy_from_user(ioc_req_mp, user_ioc, ioc_msg_size)) {
			error = -EFAULT;
			goto out_kfree;
		}
	}

	if (ioc_req.num_ports)
		bnx2i_tcp_port_new_entry(ioc_req.tcp_port[0]);

	i = 1;
	while (i < ioc_req_mp->num_ports)
		bnx2i_tcp_port_new_entry(ioc_req_mp->tcp_port[i++]);

	return 0;

out_kfree:
	kfree(ioc_req_mp);
out:
	return error;
}


/*
 * bnx2i_ioctl_init: initialization routine, registers char driver
 */
int bnx2i_ioctl_init(void)
{
	int ret;

        /* Register char device node */
        ret = register_chrdev(0, "bnx2i", &bnx2i_mgmt_fops);

        if (ret < 0) {
                printk(KERN_ERR "bnx2i: failed to register device node\n");
                return ret;
        }

        bnx2i_major_no = ret;

	return 0;
}

void bnx2i_ioctl_cleanup(void)
{
	if (bnx2i_major_no) {
		unregister_chrdev(bnx2i_major_no, "bnx2i");
	}
}

/*
 * bnx2i_mgmt_open -  "open" entry point
 */
static int bnx2i_mgmt_open(struct inode *inode, struct file *filep)
{
        /* only allow access to admin user */
        if (!capable(CAP_SYS_ADMIN)) {
                return -EACCES;
	}

        return 0;
}

/*
 * bnx2i_mgmt_release- "release" entry point
 */
static int bnx2i_mgmt_release(struct inode *inode, struct file *filep)
{
        return 0;
}



/*
 * bnx2i_mgmt_ioctl - char driver ioctl entry point
 */
static int bnx2i_mgmt_ioctl(struct inode *node, struct file *file,
			    unsigned int cmd, unsigned long arg)
{
	long rc = 0;
	switch (cmd) {
		case BNX2I_IOCTL_GET_PORT_REQ:
			rc = bnx2i_tcp_port_count_ioctl(file, arg);
			break;
		case BNX2I_IOCTL_SET_TCP_PORT:
			rc = bnx2i_tcp_port_ioctl(file, arg);
			break;
		default:
			printk(KERN_ERR "bnx2i: unknown ioctl cmd %x\n", cmd);
			return -ENOTTY;
	}

	return rc;
}


#ifdef CONFIG_COMPAT

static int bnx2i_tcp_port_count_compat_ioctl(struct file *file, unsigned long arg)
{
	struct bnx2i_get_port_count __user *user_ioc =
		(struct bnx2i_get_port_count __user *)arg;
	struct bnx2i_get_port_count *ioc_req =
		compat_alloc_user_space(sizeof(struct bnx2i_get_port_count));
	int error;
	unsigned int count = 0;

	if (clear_user(ioc_req, sizeof(*ioc_req)))
		return -EFAULT;

	if (copy_in_user(ioc_req, user_ioc, sizeof(*ioc_req))) {
		error = -EFAULT;
		goto out;
	}

	error = bnx2i_check_ioctl_signature(&ioc_req->hdr);
	if (error)
		goto out;

	if (bnx2i_tcp_port_tbl.num_free_ports < 10 &&
	    bnx2i_tcp_port_tbl.num_required) {
		if (bnx2i_tcp_port_tbl.num_required < 32)
			count = bnx2i_tcp_port_tbl.num_required;
		else
			count = 32;
	}

	if (copy_to_user(&ioc_req->port_count, &count,
			 sizeof(ioc_req->port_count))) {
		error = -EFAULT;
		goto out;
	}

	if (copy_in_user(&user_ioc->port_count, &ioc_req->port_count,
			 sizeof(u32))) {
		error = -EFAULT;
		goto out;
	}
	return 0;

out:
	return error;
}

static int bnx2i_tcp_port_compat_ioctl(struct file *file, unsigned long arg)
{
	struct bnx2i_set_port_num __user *user_ioc =
		(struct bnx2i_set_port_num __user *)arg;
	struct bnx2i_set_port_num *ioc_req =
		compat_alloc_user_space(sizeof(struct bnx2i_set_port_num));
	struct bnx2i_set_port_num *ioc_req_mp = NULL;
	int ioc_msg_size = sizeof(*ioc_req);
	int error;
	int i;

	if (clear_user(ioc_req, sizeof(*ioc_req)))
		return -EFAULT;

	if (copy_in_user(ioc_req, user_ioc, ioc_msg_size)) {
		error = -EFAULT;
		goto out;
	}

	error = bnx2i_check_ioctl_signature(&ioc_req->hdr);
	if (error)
		goto out;

	if (ioc_req->num_ports > 1) {
		ioc_msg_size += (ioc_req->num_ports - 1) *
				sizeof(ioc_req->tcp_port[0]);

		ioc_req_mp = compat_alloc_user_space(ioc_msg_size);
		if (!ioc_req_mp)
			goto out;

		if (copy_in_user(ioc_req_mp, user_ioc, ioc_msg_size)) {
			error = -EFAULT;
			goto out;
		}

		i = 0;
		while ((i < ioc_req_mp->num_ports) && ioc_req_mp)
			bnx2i_tcp_port_new_entry(ioc_req_mp->tcp_port[i++]);

	} else if (ioc_req->num_ports == 1)
		bnx2i_tcp_port_new_entry(ioc_req->tcp_port[0]);

out:
	return error;


}


/*
 * bnx2i_mgmt_compat_ioctl - char node ioctl entry point
 */
static long bnx2i_mgmt_compat_ioctl(struct file *file,
				    unsigned int cmd, unsigned long arg)
{
	int rc = -ENOTTY;

	switch (cmd) {
		case BNX2I_IOCTL_GET_PORT_REQ:
			rc = bnx2i_tcp_port_count_compat_ioctl(file, arg);
			break;
		case BNX2I_IOCTL_SET_TCP_PORT:
			rc = bnx2i_tcp_port_compat_ioctl(file, arg);
			break;
	}

        return rc;
}

#endif

/*
 * File operations structure - management interface
 */
struct file_operations bnx2i_mgmt_fops = {
        .owner = THIS_MODULE,
        .open = bnx2i_mgmt_open,
        .release = bnx2i_mgmt_release,
        .ioctl = bnx2i_mgmt_ioctl,
#ifdef CONFIG_COMPAT
        .compat_ioctl = bnx2i_mgmt_compat_ioctl,
#endif
};


/*
 * 'Scsi_Host_Template' structure and 'iscsi_tranport' structure template
 * used while registering with the iSCSI trnaport module.
 */
struct scsi_host_template bnx2i_host_template = {
	.module				= THIS_MODULE,
	.name				= "Broadcom Offload iSCSI Initiator",
	.queuecommand			= bnx2i_queuecommand,
	.eh_abort_handler		= bnx2i_abort,
	.eh_host_reset_handler		= bnx2i_host_reset,
	.bios_param			= NULL,
#ifdef __VMKLNX__
	.eh_device_reset_handler	= bnx2i_device_reset,
	.slave_configure		= bnx2i_slave_configure,
	.slave_alloc			= bnx2i_slave_alloc,
   	.target_alloc			= bnx2i_target_alloc,
   	.target_destroy			= bnx2i_target_destroy,
	.can_queue			= 1024,
#else
	.can_queue			= 128,
#endif
	.max_sectors			= 127,
	.this_id			= -1,
	.cmd_per_lun			= 64,
	.use_clustering			= ENABLE_CLUSTERING,
	.sg_tablesize			= ISCSI_MAX_BDS_PER_CMD,
#ifdef __RHEL54_DUAL_ISCSI_STACK__
	.proc_name			= "bcm570x"
#else
	.proc_name			= NULL
#endif
	};



struct iscsi_transport bnx2i_iscsi_transport = {
	.owner			= THIS_MODULE,
	.name			= "bnx2i",
	.caps			= CAP_RECOVERY_L0 | CAP_HDRDGST | CAP_MULTI_R2T
#ifdef __VMKLNX__
				  | CAP_KERNEL_POLL | CAP_SESSION_PERSISTENT
#endif
				  | CAP_DATADGST,
	.param_mask		= ISCSI_MAX_RECV_DLENGTH |
				  ISCSI_MAX_XMIT_DLENGTH |
				  ISCSI_HDRDGST_EN |
				  ISCSI_DATADGST_EN |
				  ISCSI_INITIAL_R2T_EN |
				  ISCSI_MAX_R2T |
				  ISCSI_IMM_DATA_EN |
				  ISCSI_FIRST_BURST |
				  ISCSI_MAX_BURST |
				  ISCSI_PDU_INORDER_EN |
				  ISCSI_DATASEQ_INORDER_EN |
				  ISCSI_ERL |
				  ISCSI_CONN_PORT |
				  ISCSI_CONN_ADDRESS |
				  ISCSI_EXP_STATSN |
				  ISCSI_PERSISTENT_PORT |
				  ISCSI_PERSISTENT_ADDRESS |
				  ISCSI_TARGET_NAME |
				  ISCSI_TPGT,
#ifndef __RHEL54_DUAL_ISCSI_STACK__
	.host_template		= &bnx2i_host_template,
	.sessiondata_size	= sizeof(struct bnx2i_sess),
	.conndata_size		= sizeof(struct bnx2i_conn),
	.max_conn		= 1,
	.max_cmd_len		= 16,
	.max_lun		= 512,
#endif
#ifdef __VMKLNX__
	.create_session_persistent = bnx2i_session_create_vmp,
	.create_session		= bnx2i_session_create_vm,
#else
	.create_session		= bnx2i_session_create,
#endif
	.destroy_session	= bnx2i_session_destroy,
	.create_conn		= bnx2i_conn_create,
	.bind_conn		= bnx2i_conn_bind,
	.destroy_conn		= bnx2i_conn_destroy,
	.set_param		= bnx2i_conn_set_param,
	.get_conn_param		= bnx2i_conn_get_param,
	.get_session_param	= bnx2i_session_get_param,
	.start_conn		= bnx2i_conn_start,
	.stop_conn		= bnx2i_conn_stop,
	.send_pdu		= bnx2i_conn_send_pdu,
	.get_stats		= bnx2i_conn_get_stats,
#ifdef __VMKLNX__
	/* TCP connect - disconnect - option-2 interface calls */
	.ep_connect		= NULL,
	.ep_connect_extended	= bnx2i_ep_connect,
#else
	.ep_connect		= bnx2i_ep_connect,
#endif
	.ep_poll		= bnx2i_ep_poll,
	.ep_disconnect		= bnx2i_ep_disconnect,
	/* Error recovery timeout call */
	.session_recovery_timedout = bnx2i_sess_recovery_timeo
};
