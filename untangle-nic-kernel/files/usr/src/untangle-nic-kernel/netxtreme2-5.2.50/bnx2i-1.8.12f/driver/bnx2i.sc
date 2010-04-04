
'''
Driver definition for bnx2i driver.
'''

defineVmkDriver(
   name='bnx2i',
   version='1.8.4v',
   description='Broadcom NetXtreme II iSCSI HBA Driver',
   driverType='scsi',
   files=[('drivers/scsi/bnx2i',
           Split('''
                 bnx2i_init.c
                 bnx2i_iscsi.c
                 bnx2i_hwi.c
                 bnx2i_sysfs.c
                 '''))],
   appends=dict( CCFLAGS=['-Wno-error'],
               ),
   heapinfo=('2*1024*1024', '8*1024*1024'),
)

