Typical workflow:
=================

Let's define version="4.9.0-3-untangle-amd64".

1. build a disk image to be used in qemu:

     /usr/share/untangle-development-kernel/untangle-qemu-mkimage -f ~/images/stretch-untangle.qcow2 -a amd64 -r stretch

2. build a kernel your usual way, make sure you run modules_install, and
   remember where they are installed. This can typically be forced via:

     INSTALL_MOD_PATH=/tmp/modules-$version make modules_install

3. build an initrd using those modules (make sure the version you pass
   to -v is indeed the one matching the kernel you built):

     /usr/share/untangle-development-kernel/untangle-qemu-mkinitrd -f ~/images/dracut.initrd -p /tmp/modules-$version -v $version

4. update the modules tree in the qemu image:

     /usr/share/untangle-development-kernel/untangle-qemu-udpate-modules -f ~/images/stretch-untangle.qcow2 -p /tmp/modules-$version -v $version

5. boot an instance, using the kernel and initrd produced earlier:

     /usr/share/untangle-development-kernel/untangle-qemu-run -f ~/images/stretch-untangle.qcow2 -k path/to/vmlinuz -i ~/images/dracut.initrd

   This will spawn an SDL (graphical window) with your qemu VM, and
   leave you with the QEMU monitor in the calling shell. The monitor is
   quite awesome in its own right, with a wide array of debugging and
   introspection capabilities (type "help" to list all commands). Quick
   example:

     (qemu) info network
     hub 0
      \ hub0port1: user.0: index=0,type=user,net=10.0.2.0,restrict=off
      \ hub0port0: e1000.0: index=0,type=nic,model=e1000,macaddr=52:54:00:12:34:56
     (qemu) info block
     hd0 (#block143): /home/seb/images/stretch-untangle.qcow2 (raw)
	 Attached to:      /machine/peripheral/drive0/virtio-backend
	 Cache mode:       writeback

     ide1-cd0: [not inserted]
	 Attached to:      /machine/unattached/device[24]
	 Removable device: not locked, tray closed

     floppy0: [not inserted]
	 Attached to:      /machine/unattached/device[21]
	 Removable device: not locked, tray closed

     sd0: [not inserted]
	 Removable device: not locked, tray closed
