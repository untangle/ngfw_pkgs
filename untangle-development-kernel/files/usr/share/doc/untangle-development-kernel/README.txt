Typical workflow:
=================

Let's define version="4.9.0-3-untangle-amd64".

Let's also assume you added /usr/share/untangle-development-kernel to
your PATH (later on, all those tools will be moved to /usr/bin).

1. build a UVM disk image
-------------------------

This only needs to be run once, when you start using the qemu
framework:

  untangle-qemu-mkimage-uvm -f ~/images/stretch-uvm.qcow2 -a amd64 -r stretch

You can later create additional images of course, for instance to test a
new release.

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

  untangle-qemu-mkinitrd -f ~/images/dracut.initrd -p /tmp/modules-$version/lib/modules/$version -v $version

4. update the modules tree in the UVM disk image
------------------------------------------------

  untangle-qemu-udpate-modules -f ~/images/stretch-uvm.qcow2 -p /tmp/modules-$version/lib/modules/$version -v $version -n eth0

5. boot a UVM instance
----------------------

Using the kernel and initrd produced earlier:

  untangle-qemu-run-uvm -f ~/images/stretch-uvm.qcow2 -k path/to/vmlinuz -i ~/images/dracut.initrd

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

  untangle-qemu-mkimage-client -f ~/images/stretch-client.qcow2

7. boot a client instance
-------------------------

No need to pass a kernel or initrd, this will automatically find grub
inside the disk image:

  untangle-qemu-run-client -f ~/images/stretch-client.qcow2

If everything goes well, that client will grab a DHCP address from the
uvm, and then you're all set.



Network setup:

   (internet)
       |
       |
_________________
      eth0
qemubr-ext bridge
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
      tap1
qemubr-int bridge
      tap2
_________________
       |
       |
_________________
  eth0 - DHCP
  stretch client
_________________
