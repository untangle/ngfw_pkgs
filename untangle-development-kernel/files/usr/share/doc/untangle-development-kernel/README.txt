A. Typical workflow:
====================

Let's define version="4.9.0-3-untangle-amd64".

1. build a UVM disk image
-------------------------

This only needs to be run once, when you start using the qemu
framework:

  ut-qemu-mkimage -u -f ~/images/stretch-uvm.qcow2 -a amd64 -r stretch

You can later create additional images of course, for instance to test a
new release.

Note that you can mount the resulting qcow2 image, to copy files or
chroot into:

  mount -t ext4 -o loop,offset=$((2048*512)) ~/images/stretch-untangle.qcow2 /mnt

Make sure you umount before running a qemu instance based on that disk
image, otherwise you're guaranteed to encounter data corruption.

2. build a kernel image and associated modules
----------------------------------------------

Simply build the kernel your usual way, and make sure you run
modules_install and remember where they are installed. This can
typically be forced via:

  # build and install modules
  INSTALL_MOD_PATH=/tmp/modules-$version make bzImage modules modules_install

  # create symbols files
  depmod -b $INSTALL_MOD_PATH -a $version

3. build an initrd suitable for qemu
------------------------------------

It will use those modules you just built, by using -p to point to the
directory they were installed in. Make extra sure the version you pass
to -v is indeed the one matching the kernel you built:

  ut-qemu-mkinitrd -f ~/images/dracut.initrd -p /tmp/modules-$version/lib/modules/$version -v $version

lsinitrd(1) can be used to inspect or unpack the created file if needed:

  lsinitrd ~/images/dracut.initrd
  lsinitrd --unpack ~/images/dracut.initrd

4. update the modules tree in the UVM disk image
------------------------------------------------

  ut-qemu-update-modules -f ~/images/stretch-uvm.qcow2 -p /tmp/modules-$version/lib/modules/$version -v $version -n eth0

5. boot a UVM instance
----------------------

You will be using the kernel and initrd produced earlier; you also need
to specify the LAN interface on your host via -n, and a local port to be
used as the QEMU socket (default is 12345):

  ut-qemu-run -u -f ~/images/stretch-uvm.qcow2 -k path/to/vmlinuz -i ~/images/dracut.initrd -n eth0 -p 12345

This will spawn an SDL (graphical) window with your qemu VM, and leave
you with the QEMU monitor in the calling shell.

The monitor is awesome, with a wide array of debugging and introspection
capabilities (type "help" to list all commands). Quick example:

 ,----
 | (qemu) info network
 | hub 0                                            
 |  \ hub0port1: bridge.0: index=0,type=tap,helper=/usr/lib/qemu/qemu-bridge-helper,br=qemubr-ext0
 |  \ hub0port0: e1000.0: index=0,type=nic,model=e1000,macaddr=52:54:00:12:34:56
 | (qemu) info block
 | hd0 (#block143): /home/seb/images/stretch-uvm.qcow2 (raw)
 |     Attached to:      /machine/peripheral/drive0/virtio-backend
 |     Cache mode:       writeback
 | [...]
 `----

At this point you can complete the setup wizard by accessing the
internal interface at https://192.168.2.1.

6. create a client disk image
-----------------------------

  ut-qemu-mkimage -f ~/images/stretch-client.qcow2

7. boot a client instance
-------------------------

No need to pass a kernel or initrd, this will automatically find grub
inside the disk image; you however want to specify the same local port
you used to start the uvm instance, so that your client ends up on the
local side of your uvm:

  ut-qemu-run -f ~/images/stretch-client.qcow2 -p 12345

If everything goes well, that client will grab a DHCP address from the
uvm, and then you're all set.



B. Network setup:
=================

   (internet)
       |
       |
_________________
      eth0
uvm-bridge0 bridge
      tap0
_________________
       |
       |
_________________
  eth0 - DHCP
  untangle VM 
  eth1 - 192.168.2.1/24
_________________
       |
       |
_________________
   QEMU socket
_________________
       |
       |
_________________
  eth0 - DHCP
  stretch client
_________________
